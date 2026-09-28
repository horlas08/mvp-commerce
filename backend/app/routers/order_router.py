from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Form, UploadFile, File, BackgroundTasks, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
import os
import uuid
import json
from datetime import datetime, timezone

from app.database import get_db
from app.models.order import Order, OrderItem, OrderStatus, PaymentStatus
from app.models.cart import CartItem
from app.models.user import User
from app.models.coupon import Coupon
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/orders", tags=["Orders"])


def get_effective_pricing_policy(policy_data: dict, cart_type: str) -> dict:
    """
    Returns effective pricing policy for a given cart_type (site),
    falling back to the global default for any missing fields.
    """
    if not isinstance(policy_data, dict):
        policy_data = {}

    global_s_mode = policy_data.get("shipping_mode", "fixed")
    global_s_val = float(policy_data.get("shipping_value", 0.0) or 0.0)
    global_s_hidden = bool(policy_data.get("shipping_hidden", False))
    global_c_mode = policy_data.get("commission_mode", "fixed")
    global_c_val = float(policy_data.get("commission_value", 0.0) or 0.0)
    global_c_hidden = bool(policy_data.get("commission_hidden", False))
    global_tax = float(policy_data.get("tax_percentage", 0.0) or 0.0)

    sites = policy_data.get("sites") or {}
    site_key = cart_type.lower() if cart_type else ""
    site_policy = sites.get(site_key) or {}

    return {
        "shipping_mode": site_policy.get("shipping_mode") or global_s_mode,
        "shipping_value": float(site_policy.get("shipping_value") if site_policy.get("shipping_value") is not None else global_s_val),
        "shipping_hidden": bool(site_policy.get("shipping_hidden") if site_policy.get("shipping_hidden") is not None else global_s_hidden),
        "commission_mode": site_policy.get("commission_mode") or global_c_mode,
        "commission_value": float(site_policy.get("commission_value") if site_policy.get("commission_value") is not None else global_c_val),
        "commission_hidden": bool(site_policy.get("commission_hidden") if site_policy.get("commission_hidden") is not None else global_c_hidden),
        "tax_percentage": float(site_policy.get("tax_percentage") if site_policy.get("tax_percentage") is not None else global_tax),
    }


async def calculate_coupon_discount(
    db: AsyncSession,
    code: Optional[str],
    cart_items: list,
    subtotal: float,
) -> tuple[Optional[str], float, Optional[Coupon]]:
    """
    Validates a coupon code and calculates the discount amount.
    Returns (coupon_code, discount_amount, coupon_model_or_None).
    """
    if not code or not code.strip():
        return None, 0.0, None

    clean_code = code.strip().upper()
    result = await db.execute(select(Coupon).where(Coupon.code == clean_code))
    coupon = result.scalar_one_or_none()

    if not coupon:
        return None, 0.0, None
    if not coupon.is_active:
        return None, 0.0, None
    if coupon.expires_at and coupon.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
        return None, 0.0, None
    if coupon.usage_limit and coupon.used_count >= coupon.usage_limit:
        return None, 0.0, None
    if coupon.applicability in ["wallet", "funding"]:
        return None, 0.0, None
    if subtotal < coupon.min_order_amount:
        return None, 0.0, None

    eligible_total = 0.0
    for ci in cart_items:
        is_internal = ci.product is not None
        if ci.product:
            p = float(ci.product.discount_price or ci.product.price or 0)
        else:
            try:
                p = float("".join(c for c in (ci.price or "0") if c.isdigit() or c == "."))
            except ValueError:
                p = 0.0
        item_total = p * ci.quantity
        if coupon.applicability == "all":
            eligible_total += item_total
        elif coupon.applicability == "internal" and is_internal:
            eligible_total += item_total
        elif coupon.applicability == "external" and not is_internal:
            eligible_total += item_total

    if eligible_total <= 0:
        return None, 0.0, None

    if coupon.discount_type == "percentage":
        discount = eligible_total * (coupon.discount_value / 100.0)
        if coupon.max_discount:
            discount = min(discount, coupon.max_discount)
    else:
        discount = min(coupon.discount_value, eligible_total)

    return coupon.code, round(discount, 2), coupon


class CreateOrderRequest(BaseModel):
    shipping_address: Optional[dict] = None
    coupon_code: Optional[str] = None
    notes: Optional[str] = None
    cart_type: Optional[str] = None


@router.post("")
async def create_order(
    req: CreateOrderRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Get selected cart items
    query = select(CartItem).where(
        CartItem.user_id == user.id,
        CartItem.is_selected == True,
    ).options(selectinload(CartItem.product))

    if req.cart_type:
        from app.models.cart import CartType
        try:
            ct = CartType(req.cart_type)
            query = query.where(CartItem.cart_type == ct)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid cart type: {req.cart_type}")

    result = await db.execute(query)
    cart_items = result.scalars().all()

    if not cart_items:
        raise HTTPException(status_code=400, detail="No items selected for checkout")

    # Calculate total and create order items
    total = 0.0
    order_items = []
    for ci in cart_items:
        if ci.product:
            price = ci.product.discount_price or ci.product.price
            title = ci.product.title_en
            image = (ci.product.images or [None])[0] if ci.product.images else None
            ext_url = None
        else:
            try:
                price = float("".join(c for c in (ci.price or "0") if c.isdigit() or c == "."))
            except ValueError:
                price = 0.0
            title = ci.title or "External Product"
            image = ci.image_url
            ext_url = ci.external_url

        item_total = price * ci.quantity
        total += item_total
        variant_data = None
        if ci.selections_json:
            try:
                variant_data = json.loads(ci.selections_json)
            except Exception:
                variant_data = {"raw": ci.selections_json}
        order_items.append(OrderItem(
            product_id=ci.product_id,
            title=title,
            price=price,
            quantity=ci.quantity,
            image_url=image,
            source=ci.cart_type.value,
            external_url=ext_url,
            variant_info=variant_data,
        ))

    # Apply pricing policy, coupon discount, and tax
    import json
    result_policy = await db.execute(select(AppSetting).where(AppSetting.key == "pricing_policy"))
    policy_setting = result_policy.scalar_one_or_none()
    policy = {}
    if policy_setting:
        try:
            policy = json.loads(policy_setting.value_en)
        except Exception:
            policy = {}

    effective_policy = get_effective_pricing_policy(policy, req.cart_type or "internal")
    valid_code, discount_amount, coupon_obj = await calculate_coupon_discount(db, req.coupon_code, cart_items, total)
    if coupon_obj:
        coupon_obj.used_count += 1

    tax_percentage = effective_policy.get("tax_percentage", 0.0)
    taxable_subtotal = max(0.0, total - discount_amount)
    tax_amount = round(taxable_subtotal * (tax_percentage / 100.0), 2) if tax_percentage > 0 else 0.0
    final_total = round(taxable_subtotal + tax_amount, 2)

    order = Order(
        user_id=user.id,
        total=final_total,
        shipping_address=req.shipping_address,
        coupon_code=valid_code,
        discount_amount=discount_amount,
        tax_amount=tax_amount,
        notes=req.notes,
        items=order_items,
    )
    db.add(order)

    # Clear checked-out cart items
    for ci in cart_items:
        await db.delete(ci)

    await db.commit()

    result = await db.execute(
        select(Order).where(Order.id == order.id).options(selectinload(Order.items))
    )
    order = result.scalar_one()
    return order.to_dict()


@router.get("")
async def list_orders(
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Order).where(Order.user_id == user.id).options(selectinload(Order.items))

    if status:
        try:
            os = OrderStatus(status)
            query = query.where(Order.status == os)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid status: {status}")

    query = query.order_by(Order.created_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    orders = result.scalars().all()
    return [o.to_dict() for o in orders]


@router.get("/{order_id}")
async def get_order(
    order_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Order).where(Order.id == order_id, Order.user_id == user.id).options(selectinload(Order.items))
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order.to_dict()


# ── Place Order (multipart — Flutter checkout) ──────────────────────────────

@router.post("/place")
async def place_order(
    request: Request,
    background_tasks: BackgroundTasks,
    address_id: str = Form(...),
    cart_type: str = Form(...),
    shipping_type: str = Form("home"),
    pickup_station_id: Optional[str] = Form(None),
    additional_note: Optional[str] = Form(None),
    allow_team_review: bool = Form(False),
    payment_method_id: str = Form(...),
    payment_form_data: Optional[str] = Form(None),
    payment_proof: Optional[UploadFile] = File(None),
    coupon_code: Optional[str] = Form(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Multipart checkout endpoint called by the Flutter app.
    - Wallet payments: immediately deduct balance and confirm order.
    - Manual payments: set payment_status = pending_approval, order stays pending.
    """
    from app.models.cart import CartType as CT
    from app.models.wallet_transaction import WalletTransaction, WalletTransactionType

    try:
        ct = CT(cart_type)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid cart type: {cart_type}")

    # ── Load selected cart items ──────────────────────────────────────────
    result = await db.execute(
        select(CartItem)
        .where(
            CartItem.user_id == user.id,
            CartItem.cart_type == ct,
            CartItem.is_selected == True,
        )
        .options(selectinload(CartItem.product))
    )
    cart_items = result.scalars().all()

    if not cart_items:
        raise HTTPException(status_code=400, detail="No selected items in cart")

    # ── Save payment proof image ──────────────────────────────────────────
    proof_url: Optional[str] = None
    if payment_proof and payment_proof.filename:
        static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
        proofs_dir = os.path.join(static_dir, "uploads", "proofs")
        os.makedirs(proofs_dir, exist_ok=True)

        ext = os.path.splitext(payment_proof.filename)[-1].lower() or ".jpg"
        filename = f"{uuid.uuid4().hex}{ext}"
        file_path = os.path.join(proofs_dir, filename)

        content = await payment_proof.read()
        with open(file_path, "wb") as f:
            f.write(content)

        proof_url = f"/static/uploads/proofs/{filename}"

    # ── Parse dynamic payment form fields ─────────────────────────────────
    payment_fields_data = {}
    if payment_form_data:
        try:
            payment_fields_data = json.loads(payment_form_data)
        except Exception:
            payment_fields_data = {}

    try:
        form = await request.form()
    except Exception:
        form = {}

    from app.models.payment_method import PaymentMethod
    result_pm = await db.execute(
        select(PaymentMethod).where(PaymentMethod.id == payment_method_id)
    )
    pm = result_pm.scalar_one_or_none()
    if pm:
        try:
            fields_list = json.loads(pm.fields_json or "[]")
        except Exception:
            fields_list = []

        for field in fields_list:
            field_key = field.get("key")
            field_type = field.get("type", "text")
            if not field_key:
                continue

            if field_type == "file":
                file_val = form.get(field_key)
                if file_val and hasattr(file_val, "filename") and file_val.filename:
                    static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
                    proofs_dir = os.path.join(static_dir, "uploads", "proofs")
                    os.makedirs(proofs_dir, exist_ok=True)

                    ext = os.path.splitext(file_val.filename)[-1].lower() or ".jpg"
                    filename = f"{uuid.uuid4().hex}{ext}"
                    file_path = os.path.join(proofs_dir, filename)

                    content = await file_val.read()
                    with open(file_path, "wb") as f:
                        f.write(content)

                    payment_fields_data[field_key] = f"/static/uploads/proofs/{filename}"
            else:
                if field_key in form and field_key not in payment_fields_data:
                    payment_fields_data[field_key] = form[field_key]

    # ── Build order items & total ─────────────────────────────────────────
    total = 0.0
    order_items = []
    for ci in cart_items:
        if ci.product:
            price = float(ci.product.discount_price or ci.product.price or 0)
            title = ci.product.title_en
            image = (ci.product.images or [None])[0] if ci.product.images else None
            ext_url = None
        else:
            try:
                price = float("".join(c for c in (ci.price or "0") if c.isdigit() or c == "."))
            except ValueError:
                price = 0.0
            title = ci.title or "External Product"
            image = ci.image_url
            ext_url = ci.external_url

        item_total = price * ci.quantity
        total += item_total
        variant_data = None
        if ci.selections_json:
            try:
                variant_data = json.loads(ci.selections_json)
            except Exception:
                variant_data = {"raw": ci.selections_json}
        order_items.append(
            OrderItem(
                product_id=ci.product_id,
                title=title,
                price=price,
                quantity=ci.quantity,
                image_url=image,
                source=ci.cart_type.value,
                external_url=ext_url,
                variant_info=variant_data,
            )
        )

    # ── Calculate dynamic shipping and commission fees ───────────────────
    from app.models.address import Address
    from app.models.location import State, City
    from app.models.app_setting import AppSetting

    result_addr = await db.execute(select(Address).where(Address.id == address_id, Address.user_id == user.id))
    addr = result_addr.scalar_one_or_none()

    shipping_fee = 0.0
    commission = 0.0
    team_review_fee = 0.0

    if addr:
        state_db = None
        if addr.state:
            result_state = await db.execute(select(State).where((State.name_en == addr.state) | (State.name_ar == addr.state)))
            state_db = result_state.scalar_one_or_none()

        city_db = None
        if addr.city:
            result_city = await db.execute(select(City).where((City.name_en == addr.city) | (City.name_ar == addr.city)))
            city_db = result_city.scalar_one_or_none()

        if shipping_type == "home":
            if city_db and city_db.free_shipping:
                shipping_fee = 0.0
            elif state_db and state_db.free_shipping:
                shipping_fee = 0.0
            else:
                if city_db and city_db.shipping_fee > 0:
                    shipping_fee = float(city_db.shipping_fee)
                elif state_db and state_db.shipping_fee > 0:
                    shipping_fee = float(state_db.shipping_fee)
                else:
                    shipping_fee = 0.0

        # Total Commission from City / State
        if city_db and city_db.no_commission:
            commission = 0.0
        elif state_db and state_db.no_commission:
            commission = 0.0
        else:
            if city_db and city_db.commission > 0:
                commission = float(city_db.commission)
            elif state_db and state_db.commission > 0:
                commission = float(state_db.commission)
            else:
                commission = 0.0

    # ── Apply global / per-site pricing policy as fallback if no state/city rates ────────
    result_policy = await db.execute(select(AppSetting).where(AppSetting.key == "pricing_policy"))
    policy_setting = result_policy.scalar_one_or_none()
    policy = {}
    if policy_setting:
        try:
            policy = json.loads(policy_setting.value_en)
        except Exception:
            policy = {}

    effective_policy = get_effective_pricing_policy(policy, cart_type)

    if shipping_type == "home" and shipping_fee == 0.0 and effective_policy:
        mode = effective_policy.get("shipping_mode", "fixed")
        val = float(effective_policy.get("shipping_value", 0.0))
        if mode == "fixed":
            shipping_fee = val
        elif mode == "formula":
            # val is a multiplier applied to subtotal
            shipping_fee = round(total * val, 2)

    if commission == 0.0 and effective_policy:
        mode = effective_policy.get("commission_mode", "fixed")
        val = float(effective_policy.get("commission_value", 0.0))
        if mode == "fixed":
            commission = val
        elif mode == "formula":
            commission = round(total * val, 2)

    # Team Review Before Shipping Fee
    if allow_team_review:
        result_tr = await db.execute(select(AppSetting).where(AppSetting.key == "team_review_fee"))
        setting_tr = result_tr.scalar_one_or_none()
        try:
            team_review_fee = float(setting_tr.value_en) if setting_tr and setting_tr.value_en else 5.0
        except Exception:
            team_review_fee = 5.0

    # Calculate Coupon Discount
    valid_code, discount_amount, coupon_obj = await calculate_coupon_discount(db, coupon_code, cart_items, total)
    if coupon_obj:
        coupon_obj.used_count += 1

    # Calculate Tax
    tax_percentage = float(effective_policy.get("tax_percentage", 0.0))
    taxable_subtotal = max(0.0, total - discount_amount)
    tax_amount = round(taxable_subtotal * (tax_percentage / 100.0), 2) if tax_percentage > 0 else 0.0

    # Final Total
    final_total = round(taxable_subtotal + shipping_fee + commission + team_review_fee + tax_amount, 2)

    # ── Determine payment status based on method ──────────────────────────
    is_wallet = payment_method_id == "wallet"

    if is_wallet:
        if user.credit_balance < final_total:
            raise HTTPException(status_code=400, detail="Insufficient wallet balance")
        # Deduct wallet
        user.credit_balance = round(user.credit_balance - final_total, 2)
        p_status = PaymentStatus.NOT_REQUIRED  # Wallet is auto-approved
        order_status = OrderStatus.CONFIRMED
    else:
        p_status = PaymentStatus.PENDING_APPROVAL
        order_status = OrderStatus.PENDING

    shipping_address_data = addr.to_dict() if addr else ({"address_id": address_id} if address_id else None)

    # ── Create order ──────────────────────────────────────────────────────
    order = Order(
        user_id=user.id,
        total=final_total,
        status=order_status,
        cart_type=cart_type,
        shipping_address=shipping_address_data,
        shipping_type=shipping_type,
        pickup_station_id=pickup_station_id,
        coupon_code=valid_code,
        discount_amount=discount_amount,
        tax_amount=tax_amount,
        notes=additional_note,
        allow_team_review=allow_team_review,
        payment_method_id=payment_method_id,
        payment_status=p_status,
        payment_proof_url=proof_url,
        payment_fields=payment_fields_data if payment_fields_data else None,
        items=order_items,
    )

    db.add(order)

    # ── Log wallet transaction ────────────────────────────────────────────
    if is_wallet:
        tx = WalletTransaction(
            user_id=user.id,
            amount=final_total,
            type=WalletTransactionType.DEBIT,
            reason=f"Order payment",
            reference_type="order",
            balance_after=user.credit_balance,
        )
        db.add(tx)
        # Update reference_id after order is committed
        # We'll do it after commit

    # ── Clear purchased cart items ────────────────────────────────────────
    for ci in cart_items:
        await db.delete(ci)

    await db.commit()

    # ── Update wallet tx reference ────────────────────────────────────────
    if is_wallet:
        from sqlalchemy import update
        await db.execute(
            update(WalletTransaction)
            .where(
                WalletTransaction.user_id == user.id,
                WalletTransaction.reference_id == None,
                WalletTransaction.reference_type == "order",
            )
            .values(reference_id=order.id)
        )
        await db.commit()

    # ── Reload order with items ───────────────────────────────────────────
    result = await db.execute(
        select(Order).where(Order.id == order.id).options(selectinload(Order.items))
    )
    order = result.scalar_one()
    order_dict = order.to_dict()

    # ── Fire emails in background ─────────────────────────────────────────
    from app.email_service import send_order_confirmation, send_admin_order_notification

    background_tasks.add_task(
        send_order_confirmation,
        user_email=user.email,
        user_name=user.name or user.email,
        order=order_dict,
        is_wallet=is_wallet,
    )
    background_tasks.add_task(
        send_admin_order_notification,
        order=order_dict,
        user_email=user.email,
        user_name=user.name or user.email,
        payment_method=payment_method_id,
        payment_proof_url=proof_url,
        additional_note=additional_note,
    )

    # ── Notification for user ─────────────────────────────────────────────
    from app.models.notification import Notification
    notif_msg = (
        f"Your order #{order.id[:8].upper()} has been placed and payment confirmed."
        if is_wallet
        else f"Your order #{order.id[:8].upper()} is pending payment approval."
    )
    notif = Notification(
        user_id=user.id,
        title="Order Placed",
        message=notif_msg,
        type="order_status",
    )
    db.add(notif)
    await db.commit()

    return order_dict

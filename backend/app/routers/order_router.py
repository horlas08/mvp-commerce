from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Form, UploadFile, File, BackgroundTasks, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
import os
import uuid
import json

from app.database import get_db
from app.models.order import Order, OrderItem, OrderStatus, PaymentStatus
from app.models.cart import CartItem
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/orders", tags=["Orders"])


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
        order_items.append(OrderItem(
            product_id=ci.product_id,
            title=title,
            price=price,
            quantity=ci.quantity,
            image_url=image,
            source=ci.cart_type.value,
            external_url=ext_url,
        ))

    order = Order(
        user_id=user.id,
        total=round(total, 2),
        shipping_address=req.shipping_address,
        coupon_code=req.coupon_code,
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
        order_items.append(
            OrderItem(
                product_id=ci.product_id,
                title=title,
                price=price,
                quantity=ci.quantity,
                image_url=image,
                source=ci.cart_type.value,
                external_url=ext_url,
            )
        )

    # ── Calculate dynamic shipping and commission fees ───────────────────
    from app.models.address import Address
    from app.models.location import State, City

    result_addr = await db.execute(select(Address).where(Address.id == address_id, Address.user_id == user.id))
    addr = result_addr.scalar_one_or_none()

    shipping_fee = 0.0
    commission = 0.0

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
                    shipping_fee = city_db.shipping_fee
                elif state_db and state_db.shipping_fee > 0:
                    shipping_fee = state_db.shipping_fee
                else:
                    shipping_fee = 0.0

        if allow_team_review and cart_type != "internal":
            if city_db and city_db.no_commission:
                commission = 0.0
            elif state_db and state_db.no_commission:
                commission = 0.0
            else:
                if city_db and city_db.commission > 0:
                    commission = city_db.commission
                elif state_db and state_db.commission > 0:
                    commission = state_db.commission
                else:
                    commission = 5.0
    else:
        if allow_team_review and cart_type != "internal":
            commission = 5.0

    total += shipping_fee + commission
    total = round(total, 2)

    # ── Determine payment status based on method ──────────────────────────
    is_wallet = payment_method_id == "wallet"

    if is_wallet:
        if user.credit_balance < total:
            raise HTTPException(status_code=400, detail="Insufficient wallet balance")
        # Deduct wallet
        user.credit_balance = round(user.credit_balance - total, 2)
        p_status = PaymentStatus.NOT_REQUIRED  # Wallet is auto-approved
        order_status = OrderStatus.CONFIRMED
    else:
        p_status = PaymentStatus.PENDING_APPROVAL
        order_status = OrderStatus.PENDING

    # ── Create order ──────────────────────────────────────────────────────
    order = Order(
        user_id=user.id,
        total=total,
        status=order_status,
        cart_type=cart_type,
        shipping_address={"address_id": address_id},
        shipping_type=shipping_type,
        pickup_station_id=pickup_station_id,
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
            amount=total,
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

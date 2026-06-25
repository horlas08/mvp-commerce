from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Form, UploadFile, File, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
import os
import uuid
import asyncio

from app.database import get_db
from app.models.order import Order, OrderItem, OrderStatus
from app.models.cart import CartItem
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/orders", tags=["Orders"])



class CreateOrderRequest(BaseModel):
    shipping_address: Optional[dict] = None
    coupon_code: Optional[str] = None
    notes: Optional[str] = None
    cart_type: Optional[str] = None  # If None, checkout all selected cart items


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
        else:
            # Parse price string for external products (best effort)
            try:
                price = float("".join(c for c in (ci.price or "0") if c.isdigit() or c == "."))
            except ValueError:
                price = 0.0
            title = ci.title or "External Product"
            image = ci.image_url

        item_total = price * ci.quantity
        total += item_total
        order_items.append(OrderItem(
            product_id=ci.product_id,
            title=title,
            price=price,
            quantity=ci.quantity,
            image_url=image,
            source=ci.cart_type.value,
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
    
    # Fetch order again with items loaded to avoid lazy loading in to_dict()
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
    background_tasks: BackgroundTasks,
    address_id: str = Form(...),
    cart_type: str = Form(...),
    shipping_type: str = Form("home"),
    pickup_station_id: Optional[str] = Form(None),
    additional_note: Optional[str] = Form(None),
    allow_team_review: bool = Form(False),
    payment_method_id: str = Form(...),
    # Dynamic payment form fields are submitted as a flat JSON string
    payment_form_data: Optional[str] = Form(None),
    payment_proof: Optional[UploadFile] = File(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Multipart checkout endpoint called by the Flutter app.
    Accepts optional payment_proof image, creates order from selected cart
    items, clears the cart, then sends confirmation emails in the background.
    """
    from app.models.cart import CartType as CT

    # ── Validate cart_type ────────────────────────────────────────────────
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

    # ── Build order items & total ─────────────────────────────────────────
    total = 0.0
    order_items = []
    for ci in cart_items:
        if ci.product:
            price = float(ci.product.discount_price or ci.product.price or 0)
            title = ci.product.title_en
            image = (ci.product.images or [None])[0] if ci.product.images else None
        else:
            try:
                price = float("".join(c for c in (ci.price or "0") if c.isdigit() or c == "."))
            except ValueError:
                price = 0.0
            title = ci.title or "External Product"
            image = ci.image_url

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
            )
        )

    # ── Add team review fee for external carts ────────────────────────────
    if allow_team_review and cart_type != "internal":
        total += 5.0

    total = round(total, 2)

    # ── Process wallet payment if selected ────────────────────────────────
    if payment_method_id == "wallet":
        if user.credit_balance < total:
            raise HTTPException(status_code=400, detail="Insufficient wallet balance")
        user.credit_balance = round(user.credit_balance - total, 2)

    # ── Create order ──────────────────────────────────────────────────────
    order = Order(
        user_id=user.id,
        total=total,
        shipping_address={"address_id": address_id, "shipping_type": shipping_type,
                          "pickup_station_id": pickup_station_id},
        notes=additional_note,
        items=order_items,
    )
    # Store payment info in notes field (extend Order model later if needed)
    if payment_method_id:
        order.notes = (
            f"payment_method={payment_method_id}"
            + (f" | proof={proof_url}" if proof_url else "")
            + (f" | note={additional_note}" if additional_note else "")
        )

    db.add(order)

    # ── Clear purchased cart items ────────────────────────────────────────
    for ci in cart_items:
        await db.delete(ci)

    await db.commit()

    # ── Reload order with items for serialisation ─────────────────────────
    result = await db.execute(
        select(Order).where(Order.id == order.id).options(selectinload(Order.items))
    )
    order = result.scalar_one()
    order_dict = order.to_dict()

    # ── Fire emails in the background (non-blocking) ──────────────────────
    from app.email_service import send_order_confirmation, send_admin_order_notification

    background_tasks.add_task(
        send_order_confirmation,
        user_email=user.email,
        user_name=user.name or user.email,
        order=order_dict,
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

    return order_dict


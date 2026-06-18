from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

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

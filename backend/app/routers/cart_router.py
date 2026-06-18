from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.cart import CartItem, CartType
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/cart", tags=["Cart"])


class AddToCartRequest(BaseModel):
    cart_type: str = "internal"
    product_id: Optional[str] = None
    # For external products
    title: Optional[str] = None
    price: Optional[str] = None
    image_url: Optional[str] = None
    external_url: Optional[str] = None
    site_name: Optional[str] = None
    quantity: int = 1


class UpdateCartRequest(BaseModel):
    quantity: Optional[int] = None
    is_selected: Optional[bool] = None


@router.get("")
async def get_cart(
    cart_type: Optional[str] = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(CartItem).where(CartItem.user_id == user.id)
    if cart_type:
        try:
            ct = CartType(cart_type)
            query = query.where(CartItem.cart_type == ct)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid cart type: {cart_type}")

    # Eagerly load product for internal items
    query = query.options(selectinload(CartItem.product))
    result = await db.execute(query)
    items = result.scalars().all()
    return [item.to_dict() for item in items]


@router.post("")
async def add_to_cart(
    req: AddToCartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        ct = CartType(req.cart_type)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid cart type: {req.cart_type}")

    item = CartItem(
        user_id=user.id,
        cart_type=ct,
        product_id=req.product_id,
        title=req.title,
        price=req.price,
        image_url=req.image_url,
        external_url=req.external_url,
        site_name=req.site_name,
        quantity=req.quantity,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item.to_dict()


@router.put("/{item_id}")
async def update_cart_item(
    item_id: str,
    req: UpdateCartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    if req.quantity is not None:
        if req.quantity <= 0:
            await db.delete(item)
            await db.commit()
            return {"message": "Item removed from cart"}
        item.quantity = req.quantity
    if req.is_selected is not None:
        item.is_selected = req.is_selected

    await db.commit()
    await db.refresh(item)
    return item.to_dict()


@router.delete("/{item_id}")
async def remove_from_cart(
    item_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    await db.delete(item)
    await db.commit()
    return {"message": "Item removed from cart"}


@router.delete("")
async def clear_cart(
    cart_type: Optional[str] = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(CartItem).where(CartItem.user_id == user.id)
    if cart_type:
        try:
            ct = CartType(cart_type)
            query = query.where(CartItem.cart_type == ct)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid cart type: {cart_type}")

    result = await db.execute(query)
    items = result.scalars().all()
    for item in items:
        await db.delete(item)
    await db.commit()
    return {"message": f"Cleared {len(items)} items from cart"}

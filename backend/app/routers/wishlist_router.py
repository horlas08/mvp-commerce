from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.wishlist import WishlistItem
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/wishlist", tags=["Wishlist"])


class AddWishlistRequest(BaseModel):
    product_id: Optional[str] = None
    external_url: Optional[str] = None
    title: Optional[str] = None
    price: Optional[str] = None
    image_url: Optional[str] = None
    source: str = "internal"


@router.get("")
async def get_wishlist(
    lang: str = Query("en"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(WishlistItem).where(WishlistItem.user_id == user.id).options(selectinload(WishlistItem.product))
    )
    items = result.scalars().all()
    return [item.to_dict(lang) for item in items]


@router.post("")
async def add_to_wishlist(
    req: AddWishlistRequest,
    lang: str = Query("en"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    item = WishlistItem(user_id=user.id, **req.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item.to_dict(lang)


@router.delete("/{item_id}")
async def remove_from_wishlist(
    item_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(WishlistItem).where(WishlistItem.id == item_id, WishlistItem.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Wishlist item not found")

    await db.delete(item)
    await db.commit()
    return {"message": "Removed from wishlist"}

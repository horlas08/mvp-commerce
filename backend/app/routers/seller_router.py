from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.seller import Seller
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/sellers", tags=["Sellers"])


class SellerApplicationRequest(BaseModel):
    store_name_en: str
    store_name_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    logo_url: Optional[str] = None


@router.get("")
async def list_sellers(lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Seller).where(Seller.is_active == True))
    sellers = result.scalars().all()
    return [s.to_dict(lang) for s in sellers]


@router.post("/apply")
async def apply_as_seller(
    req: SellerApplicationRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Check if already a seller
    result = await db.execute(select(Seller).where(Seller.user_id == user.id))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="You are already registered as a seller")

    seller = Seller(user_id=user.id, **req.model_dump())
    db.add(seller)

    # Update user role
    user.role = "seller"
    await db.commit()
    await db.refresh(seller)
    return seller.to_dict()


@router.get("/{seller_id}")
async def get_seller(seller_id: str, lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Seller).where(Seller.id == seller_id))
    seller = result.scalar_one_or_none()
    if not seller:
        raise HTTPException(status_code=404, detail="Seller not found")
    return seller.to_dict(lang)

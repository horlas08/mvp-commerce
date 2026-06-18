from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.product import Product
from app.models.banner import Banner

router = APIRouter(prefix="/products", tags=["Products"])


@router.get("")
async def list_products(
    lang: str = Query("en"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    category_id: Optional[str] = None,
    seller_id: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    query = select(Product).where(Product.is_active == True)
    if category_id:
        query = query.where(Product.category_id == category_id)
    if seller_id:
        query = query.where(Product.seller_id == seller_id)
    query = query.offset((page - 1) * limit).limit(limit)

    result = await db.execute(query)
    products = result.scalars().all()
    return [p.to_dict(lang) for p in products]


@router.get("/top-selling")
async def top_selling(lang: str = Query("en"), limit: int = Query(10), db: AsyncSession = Depends(get_db)):
    query = select(Product).where(Product.is_active == True).order_by(Product.rating.desc()).limit(limit)
    result = await db.execute(query)
    products = result.scalars().all()
    return [p.to_dict(lang) for p in products]


@router.get("/search")
async def search_products(
    q: str = Query(..., min_length=1),
    lang: str = Query("en"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(Product).where(
        Product.is_active == True,
        (Product.title_en.ilike(f"%{q}%")) | (Product.title_ar.ilike(f"%{q}%"))
    ).offset((page - 1) * limit).limit(limit)

    result = await db.execute(query)
    products = result.scalars().all()
    return [p.to_dict(lang) for p in products]


@router.get("/banners")
async def list_banners(lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    query = select(Banner).where(Banner.is_active == True).order_by(Banner.sort_order)
    result = await db.execute(query)
    banners = result.scalars().all()
    return [b.to_dict(lang) for b in banners]


@router.get("/{product_id}")
async def get_product(product_id: str, lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Product not found")
    return product.to_dict(lang)

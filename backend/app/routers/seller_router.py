from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.seller import Seller
from app.models.product import Product
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/sellers", tags=["Sellers"])


class SellerApplicationRequest(BaseModel):
    store_name_en: str
    store_name_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    logo_url: Optional[str] = None


class CreateProductRequest(BaseModel):
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    price: float
    discount_price: Optional[float] = None
    currency: str = "SAR"
    images: Optional[List[str]] = None
    category_id: Optional[str] = None
    stock: int = 0
    variants: Optional[List[dict]] = None
    weight_kg: Optional[float] = None
    delivery_days: Optional[int] = None
    is_active: bool = True


class UpdateProductRequest(BaseModel):
    title_en: Optional[str] = None
    title_ar: Optional[str] = None
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    price: Optional[float] = None
    discount_price: Optional[float] = None
    currency: Optional[str] = None
    images: Optional[List[str]] = None
    category_id: Optional[str] = None
    stock: Optional[int] = None
    variants: Optional[List[dict]] = None
    weight_kg: Optional[float] = None
    delivery_days: Optional[int] = None
    is_active: Optional[bool] = None


# ─── Helper ──────────────────────────────────────────────────────────────────

async def _get_seller_for_user(user: User, db: AsyncSession) -> Seller:
    """Return the Seller record for the authenticated user, or 404."""
    result = await db.execute(select(Seller).where(Seller.user_id == user.id))
    seller = result.scalar_one_or_none()
    if not seller:
        raise HTTPException(status_code=404, detail="Seller profile not found")
    return seller


# ─── Existing public endpoints ────────────────────────────────────────────────

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


# ─── /sellers/me endpoints (must be defined BEFORE /{seller_id}) ──────────────

@router.get("/me")
async def get_my_seller_profile(
    lang: str = Query("en"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the current user's seller profile."""
    seller = await _get_seller_for_user(user, db)
    return seller.to_dict(lang)


@router.get("/me/products")
async def list_my_products(
    lang: str = Query("en"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all products belonging to the current seller."""
    seller = await _get_seller_for_user(user, db)
    result = await db.execute(select(Product).where(Product.seller_id == seller.id))
    products = result.scalars().all()
    return [p.to_dict(lang) for p in products]


@router.post("/me/products", status_code=201)
async def create_my_product(
    req: CreateProductRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a product for the current seller (must have seller role)."""
    if user.role != "seller":
        raise HTTPException(status_code=403, detail="Seller role required")
    seller = await _get_seller_for_user(user, db)

    product = Product(seller_id=seller.id, **req.model_dump())
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product.to_dict()


@router.patch("/me/products/{product_id}")
async def update_my_product(
    product_id: str,
    req: UpdateProductRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a product that belongs to the current seller."""
    seller = await _get_seller_for_user(user, db)

    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.seller_id != seller.id:
        raise HTTPException(status_code=403, detail="You do not own this product")

    for field, value in req.model_dump(exclude_unset=True).items():
        setattr(product, field, value)

    await db.commit()
    await db.refresh(product)
    return product.to_dict()


@router.delete("/me/products/{product_id}", status_code=204)
async def delete_my_product(
    product_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a product that belongs to the current seller."""
    seller = await _get_seller_for_user(user, db)

    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.seller_id != seller.id:
        raise HTTPException(status_code=403, detail="You do not own this product")

    await db.delete(product)
    await db.commit()


# ─── Public seller-by-id (must stay LAST to avoid shadowing /me routes) ───────

@router.get("/{seller_id}")
async def get_seller(seller_id: str, lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Seller).where(Seller.id == seller_id))
    seller = result.scalar_one_or_none()
    if not seller:
        raise HTTPException(status_code=404, detail="Seller not found")
    return seller.to_dict(lang)

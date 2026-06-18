from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone

from app.database import get_db
from app.models.coupon import Coupon

router = APIRouter(prefix="/coupons", tags=["Coupons"])


@router.get("")
async def list_coupons(lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    query = select(Coupon).where(
        Coupon.is_active == True,
        (Coupon.expires_at == None) | (Coupon.expires_at > now),
    )
    result = await db.execute(query)
    coupons = result.scalars().all()
    return [c.to_dict(lang) for c in coupons]


class ValidateCouponRequest(BaseModel):
    code: str
    order_total: float = 0.0


@router.post("/validate")
async def validate_coupon(req: ValidateCouponRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Coupon).where(Coupon.code == req.code))
    coupon = result.scalar_one_or_none()

    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon not found")
    if not coupon.is_active:
        raise HTTPException(status_code=400, detail="Coupon is no longer active")
    if coupon.expires_at and coupon.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
        raise HTTPException(status_code=400, detail="Coupon has expired")
    if coupon.usage_limit and coupon.used_count >= coupon.usage_limit:
        raise HTTPException(status_code=400, detail="Coupon usage limit reached")
    if req.order_total < coupon.min_order_amount:
        raise HTTPException(status_code=400, detail=f"Minimum order amount is {coupon.min_order_amount}")

    # Calculate discount
    if coupon.discount_type == "percentage":
        discount = req.order_total * (coupon.discount_value / 100)
        if coupon.max_discount:
            discount = min(discount, coupon.max_discount)
    else:
        discount = coupon.discount_value

    return {
        "valid": True,
        "discount": round(discount, 2),
        "coupon": coupon.to_dict(),
    }

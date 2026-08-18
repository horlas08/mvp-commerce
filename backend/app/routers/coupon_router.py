from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone

from app.database import get_db
from app.models.coupon import Coupon
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/coupons", tags=["Coupons"])


@router.get("")
async def list_coupons(lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    query = select(Coupon).where(
        Coupon.is_active == True,
        Coupon.applicability.notin_(["wallet", "funding"]),
        (Coupon.expires_at == None) | (Coupon.expires_at > now),
    )
    result = await db.execute(query)
    coupons = result.scalars().all()
    return [c.to_dict(lang) for c in coupons]


class ValidateCouponRequest(BaseModel):
    code: str
    order_total: float = 0.0


@router.post("/validate")
async def validate_coupon(
    req: ValidateCouponRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Coupon).where(Coupon.code == req.code.upper().strip()))
    coupon = result.scalar_one_or_none()

    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon not found")
    if not coupon.is_active:
        raise HTTPException(status_code=400, detail="Coupon is no longer active")
    if coupon.expires_at and coupon.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
        raise HTTPException(status_code=400, detail="Coupon has expired")
    if coupon.usage_limit and coupon.used_count >= coupon.usage_limit:
        raise HTTPException(status_code=400, detail="Coupon usage limit reached")
    if coupon.applicability in ["wallet", "funding"]:
        raise HTTPException(
            status_code=400,
            detail="This coupon is a wallet funding voucher. Please redeem it in 'My Credit' (رصيدي) to add balance."
        )

    # ── Fetch user active cart items to compute eligible subtotal ─────────
    from app.models.cart import CartItem
    from sqlalchemy.orm import selectinload

    result_cart = await db.execute(
        select(CartItem)
        .where(
            CartItem.user_id == user.id,
            CartItem.is_selected == True
        )
        .options(selectinload(CartItem.product))
    )
    cart_items = result_cart.scalars().all()

    eligible_total = 0.0
    total_cart_amount = 0.0

    if cart_items:
        # We compute the eligible total based on applicability
        for ci in cart_items:
            # Price calculation
            if ci.product:
                price = float(ci.product.discount_price or ci.product.price or 0)
                is_internal = True
            else:
                try:
                    price = float("".join(c for c in (ci.price or "0") if c.isdigit() or c == "."))
                except ValueError:
                    price = 0.0
                is_internal = False

            item_total = price * ci.quantity
            total_cart_amount += item_total

            # Applicability filters
            if coupon.applicability == "all":
                eligible_total += item_total
            elif coupon.applicability == "internal" and is_internal:
                eligible_total += item_total
            elif coupon.applicability == "external" and not is_internal:
                eligible_total += item_total
    else:
        # Fallback to order_total if cart is empty or loaded from another flow
        total_cart_amount = req.order_total
        eligible_total = req.order_total

    # Validate minimum order amount
    if total_cart_amount < coupon.min_order_amount:
        raise HTTPException(status_code=400, detail=f"Minimum order amount is {coupon.min_order_amount}")

    if eligible_total <= 0:
        msg = "Coupon is not applicable to the items in your cart"
        if coupon.applicability == "internal":
            msg = "Coupon is only applicable to internal store products"
        elif coupon.applicability == "external":
            msg = "Coupon is only applicable to external cart products (Aliexpress, Shein, etc.)"
        raise HTTPException(status_code=400, detail=msg)

    # Calculate discount
    if coupon.discount_type == "percentage":
        discount = eligible_total * (coupon.discount_value / 100)
        if coupon.max_discount:
            discount = min(discount, coupon.max_discount)
    else:
        # For fixed discount, cap at eligible subtotal
        discount = min(coupon.discount_value, eligible_total)

    return {
        "valid": True,
        "discount": round(discount, 2),
        "coupon": coupon.to_dict(),
    }

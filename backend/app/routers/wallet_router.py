from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from datetime import datetime, timezone

from app.database import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.coupon import Coupon
from app.models.wallet_transaction import WalletTransaction, WalletTransactionType

router = APIRouter(prefix="/wallet", tags=["Wallet"])


@router.get("/balance")
async def get_wallet_balance(user: User = Depends(get_current_user)):
    return {"balance": user.credit_balance}


@router.get("/transactions")
async def get_wallet_transactions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(WalletTransaction)
        .where(WalletTransaction.user_id == user.id)
        .order_by(desc(WalletTransaction.created_at))
        .limit(50)
    )
    txs = result.scalars().all()
    return [tx.to_dict() for tx in txs]


class CouponTopUpRequest(BaseModel):
    code: str


@router.post("/topup/coupon")
async def topup_via_coupon(
    req: CouponTopUpRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    code_clean = req.code.strip().upper()
    if not code_clean:
        raise HTTPException(status_code=400, detail="Please enter a valid coupon code")

    result = await db.execute(select(Coupon).where(Coupon.code == code_clean))
    coupon = result.scalar_one_or_none()

    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon code not found")
    if not coupon.is_active:
        raise HTTPException(status_code=400, detail="Coupon is inactive")
    if coupon.expires_at and coupon.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
        raise HTTPException(status_code=400, detail="Coupon has expired")
    if coupon.usage_limit and coupon.used_count >= coupon.usage_limit:
        raise HTTPException(status_code=400, detail="Coupon usage limit reached")
    if coupon.applicability in ["internal", "external"]:
        raise HTTPException(
            status_code=400,
            detail="This coupon code is reserved for store checkout discounts, not wallet funding."
        )

    amount = float(coupon.discount_value)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid coupon value")

    user.credit_balance = round(float(user.credit_balance or 0.0) + amount, 2)
    coupon.used_count += 1

    tx = WalletTransaction(
        user_id=user.id,
        amount=amount,
        type=WalletTransactionType.CREDIT,
        reason=f"Coupon Top-Up ({coupon.code})",
        reference_id=coupon.id,
        reference_type="coupon",
        balance_after=user.credit_balance,
    )
    db.add(tx)
    await db.commit()
    await db.refresh(user)

    return {
        "success": True,
        "amount_added": amount,
        "new_balance": user.credit_balance,
        "message": f"Successfully added {amount} SAR to your credit balance!",
    }

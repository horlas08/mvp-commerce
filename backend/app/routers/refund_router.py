from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.refund import RefundRequest, RefundStatus
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/refunds", tags=["Refunds"])


class CreateRefundRequest(BaseModel):
    order_id: str
    reason: str


@router.post("")
async def create_refund(
    req: CreateRefundRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    refund = RefundRequest(
        order_id=req.order_id,
        user_id=user.id,
        reason=req.reason,
    )
    db.add(refund)
    await db.commit()
    await db.refresh(refund)
    return refund.to_dict()


@router.get("")
async def list_refunds(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(RefundRequest).where(RefundRequest.user_id == user.id).order_by(RefundRequest.created_at.desc())
    )
    refunds = result.scalars().all()
    return [r.to_dict() for r in refunds]

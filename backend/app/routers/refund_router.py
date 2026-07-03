from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.refund import RefundRequest, RefundStatus
from app.models.order import Order, OrderStatus
from app.models.user import User
from app.models.support import SupportTicket, SupportMessage
from app.models.notification import Notification
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/refunds", tags=["Refunds"])


class CreateRefundRequest(BaseModel):
    order_id: str
    reason: str


@router.post("")
async def create_refund(
    req: CreateRefundRequest,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    User submits a refund request linked to an order.
    Automatically opens a support ticket for the refund discussion.
    """
    # Verify order belongs to user
    order_result = await db.execute(
        select(Order).where(Order.id == req.order_id, Order.user_id == user.id)
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Check no existing pending/approved refund for this order
    existing = await db.execute(
        select(RefundRequest).where(
            RefundRequest.order_id == req.order_id,
            RefundRequest.user_id == user.id,
            RefundRequest.status.in_([RefundStatus.PENDING, RefundStatus.APPROVED]),
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="A refund request already exists for this order")

    refund = RefundRequest(
        order_id=req.order_id,
        user_id=user.id,
        reason=req.reason,
    )
    db.add(refund)

    # Auto-create a support ticket for this refund
    ticket = SupportTicket(
        user_id=user.id,
        title=f"Refund Request — Order #{req.order_id[:8].upper()}",
        description=f"Refund requested.\n\nOrder: #{req.order_id[:8].upper()}\nReason: {req.reason}",
        status="open",
        admin_unread=True,
    )
    db.add(ticket)

    # Notification for user
    notif = Notification(
        user_id=user.id,
        title="Refund Request Submitted",
        message=f"Your refund request for order #{req.order_id[:8].upper()} has been submitted.",
        type="order_status",
    )
    db.add(notif)

    await db.commit()
    await db.refresh(refund)

    # Send admin alert
    from app.email_service import send_admin_support_alert
    background_tasks.add_task(
        send_admin_support_alert,
        ticket_title=ticket.title,
        ticket_description=ticket.description,
        username=user.name or user.email,
        user_email=user.email,
        is_new=True,
    )

    return refund.to_dict()


@router.get("")
async def list_refunds(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RefundRequest)
        .where(RefundRequest.user_id == user.id)
        .options(selectinload(RefundRequest.order))
        .order_by(RefundRequest.created_at.desc())
    )
    refunds = result.scalars().all()

    enriched = []
    for r in refunds:
        d = r.to_dict()
        if r.order:
            d["order_total"] = r.order.total
            d["order_status"] = r.order.status.value
        enriched.append(d)

    return enriched


@router.delete("/{refund_id}")
async def cancel_refund(
    refund_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """User can cancel a pending refund request."""
    result = await db.execute(
        select(RefundRequest).where(
            RefundRequest.id == refund_id,
            RefundRequest.user_id == user.id,
        )
    )
    refund = result.scalar_one_or_none()
    if not refund:
        raise HTTPException(status_code=404, detail="Refund request not found")
    if refund.status != RefundStatus.PENDING:
        raise HTTPException(status_code=400, detail="Only pending refund requests can be cancelled")

    await db.delete(refund)
    await db.commit()
    return {"message": "Refund request cancelled"}

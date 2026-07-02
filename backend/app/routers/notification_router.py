from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.models.notification import Notification
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("")
async def list_notifications(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Notification).where(Notification.user_id == user.id).order_by(Notification.created_at.desc())
    res = await db.execute(stmt)
    notifications = res.scalars().all()
    return [n.to_dict() for n in notifications]


@router.post("/{notification_id}/read")
async def mark_as_read(
    notification_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Notification).where(
        Notification.id == notification_id,
        Notification.user_id == user.id
    )
    res = await db.execute(stmt)
    notification = res.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.is_read = True
    await db.commit()
    return {"status": "success"}


@router.get("/unread-count")
async def get_unread_count(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Notification).where(
        Notification.user_id == user.id,
        Notification.is_read == False
    )
    res = await db.execute(stmt)
    unread = res.scalars().all()
    return {"count": len(unread)}

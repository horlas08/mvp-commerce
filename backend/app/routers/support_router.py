from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.support import SupportTicket, SupportMessage
from app.auth.dependencies import get_current_user
from app.email_service import send_admin_support_alert

router = APIRouter(prefix="/support", tags=["Support"])


# Pydantic schemas
class TicketCreate(BaseModel):
    title: str
    description: str


class MessageCreate(BaseModel):
    message: str


# Admin guard dependency
async def get_admin_user(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


# ── User Endpoints ────────────────────────────────────────────────────────────

@router.post("/tickets")
async def create_ticket(
    req: TicketCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    ticket = SupportTicket(
        user_id=user.id,
        title=req.title,
        description=req.description,
        status="open",
        user_unread=False,
        admin_unread=True
    )
    db.add(ticket)
    await db.commit()
    await db.refresh(ticket)

    # Add initial message from user detailing the issue
    initial_msg = SupportMessage(
        ticket_id=ticket.id,
        sender="user",
        message=req.description
    )
    db.add(initial_msg)
    await db.commit()

    # Send email alert to admin
    try:
        await send_admin_support_alert(
            ticket_title=ticket.title,
            ticket_description=ticket.description,
            username=user.name,
            user_email=user.email,
            is_new=True
        )
    except Exception as e:
        print(f"Failed to send email alert: {e}")

    return ticket.to_dict()


@router.get("/tickets")
async def list_tickets(
    status: Optional[str] = Query(None, description="Filter by status: open, pending, closed"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(SupportTicket).where(SupportTicket.user_id == user.id)
    if status:
        stmt = stmt.where(SupportTicket.status == status)
    stmt = stmt.order_by(SupportTicket.updated_at.desc())
    
    res = await db.execute(stmt)
    tickets = res.scalars().all()
    return [t.to_dict() for t in tickets]


@router.get("/tickets/{ticket_id}/messages")
async def get_messages(
    ticket_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Fetch ticket to verify ownership
    ticket_res = await db.execute(
        select(SupportTicket).where(SupportTicket.id == ticket_id)
    )
    ticket = ticket_res.scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    if ticket.user_id != user.id and user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")

    # Mark as read for user
    if ticket.user_id == user.id and ticket.user_unread:
        ticket.user_unread = False
        await db.commit()

    # Fetch messages
    msg_res = await db.execute(
        select(SupportMessage)
        .where(SupportMessage.ticket_id == ticket_id)
        .order_by(SupportMessage.created_at.asc())
    )
    messages = msg_res.scalars().all()
    return [m.to_dict() for m in messages]


@router.post("/tickets/{ticket_id}/messages")
async def send_message(
    ticket_id: int,
    req: MessageCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Fetch ticket to verify ownership and status
    ticket_res = await db.execute(
        select(SupportTicket).where(SupportTicket.id == ticket_id)
    )
    ticket = ticket_res.scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    if ticket.user_id != user.id and user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")

    if ticket.status == "closed":
        raise HTTPException(status_code=400, detail="Cannot send message to a closed ticket")

    sender = "admin" if user.role == "admin" else "user"

    msg = SupportMessage(
        ticket_id=ticket.id,
        sender=sender,
        message=req.message
    )
    db.add(msg)

    # Update ticket unread states and status
    ticket.updated_at = datetime.now(timezone.utc)
    if sender == "user":
        ticket.admin_unread = True
        ticket.status = "open"
    else:
        ticket.user_unread = True
        ticket.status = "pending"

    await db.commit()
    await db.refresh(msg)

    # Notify via email if user replies (so admin gets a prompt)
    if sender == "user":
        try:
            await send_admin_support_alert(
                ticket_title=ticket.title,
                ticket_description=req.message,
                username=user.name,
                user_email=user.email,
                is_new=False
            )
        except Exception as e:
            print(f"Failed to send reply email alert: {e}")

    return msg.to_dict()


@router.get("/unread-count")
async def get_unread_count(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(SupportTicket).where(
        SupportTicket.user_id == user.id,
        SupportTicket.user_unread == True
    )
    res = await db.execute(stmt)
    return {"count": len(res.scalars().all())}


# ── Admin Endpoints ───────────────────────────────────────────────────────────

@router.get("/admin/tickets")
async def admin_list_tickets(
    status: Optional[str] = Query(None, description="Filter by status: open, pending, closed"),
    _: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(SupportTicket)
    if status:
        stmt = stmt.where(SupportTicket.status == status)
    stmt = stmt.order_by(SupportTicket.updated_at.desc())
    
    res = await db.execute(stmt)
    tickets = res.scalars().all()
    
    # We load users for ticket detail display
    res_list = []
    for t in tickets:
        user_res = await db.execute(select(User).where(User.id == t.user_id))
        user_obj = user_res.scalar_one_or_none()
        t_dict = t.to_dict()
        t_dict["user"] = {
            "name": user_obj.name if user_obj else "Unknown",
            "email": user_obj.email if user_obj else "Unknown"
        }
        res_list.append(t_dict)
        
    return res_list


@router.post("/admin/tickets/{ticket_id}/close")
async def admin_close_ticket(
    ticket_id: int,
    _: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db)
):
    ticket_res = await db.execute(
        select(SupportTicket).where(SupportTicket.id == ticket_id)
    )
    ticket = ticket_res.scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")

    ticket.status = "closed"
    ticket.updated_at = datetime.now(timezone.utc)
    await db.commit()
    return ticket.to_dict()


@router.get("/admin/unread-count")
async def get_admin_unread_count(
    _: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(SupportTicket).where(SupportTicket.admin_unread == True)
    res = await db.execute(stmt)
    return {"count": len(res.scalars().all())}

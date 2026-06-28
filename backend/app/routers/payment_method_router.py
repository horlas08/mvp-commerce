from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.payment_method import PaymentMethod

router = APIRouter(prefix="/payment-methods", tags=["Payment Methods"])


@router.get("")
async def list_payment_methods(lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    """List all active payment methods."""
    query = select(PaymentMethod).where(PaymentMethod.is_active == True)
    result = await db.execute(query)
    methods = result.scalars().all()
    return [m.to_dict(lang) for m in methods]

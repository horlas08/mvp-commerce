from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional

from app.database import get_db
from app.models.location import State, City

router = APIRouter(tags=["Locations"])


@router.get("/states")
async def list_states(db: AsyncSession = Depends(get_db)):
    """Fetch all states ordered alphabetically by English name."""
    result = await db.execute(select(State).order_by(State.name_en))
    states = result.scalars().all()
    return [s.to_dict() for s in states]


@router.get("/cities")
async def list_cities(
    state_id: Optional[str] = Query(None, description="Filter cities by state ID"),
    db: AsyncSession = Depends(get_db)
):
    """Fetch cities, optionally filtered by state_id, ordered by English name."""
    query = select(City)
    if state_id:
        query = query.where(City.state_id == state_id)
    query = query.order_by(City.name_en)
    
    result = await db.execute(query)
    cities = result.scalars().all()
    return [c.to_dict() for c in cities]

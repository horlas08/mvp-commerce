from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.category import Category

router = APIRouter(prefix="/categories", tags=["Categories"])


@router.get("")
async def list_categories(lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    query = select(Category).order_by(Category.sort_order)
    result = await db.execute(query)
    categories = result.scalars().all()
    return [c.to_dict(lang) for c in categories]


@router.get("/{category_id}")
async def get_category(category_id: str, lang: str = Query("en"), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Category).where(Category.id == category_id))
    category = result.scalar_one_or_none()
    if not category:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Category not found")
    return category.to_dict(lang)

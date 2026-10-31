import json
from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.config import get_config_for_url, SITE_CONFIGS
from app.database import get_db
from app.models.app_setting import AppSetting

router = APIRouter(prefix="/config", tags=["Scraper Config"])

DEFAULT_EXCHANGE_RATES = {
    "SAR": 1.0,
    "USD": 3.75,
    "YER_OLD": 530.0,
    "YER_NEW": 1850.0,
    "EUR": 4.10,
    "AED": 1.02,
    "CNY": 0.52,
    "GBP": 4.75,
}

DEFAULT_STORE_ORDER = ["shein", "amazon", "iherb", "aliexpress", "alibaba"]


@router.get("/exchange-rates")
async def get_public_exchange_rates(db: AsyncSession = Depends(get_db)):
    """Public endpoint to fetch current currency exchange rates."""
    result = await db.execute(select(AppSetting).where(AppSetting.key == "exchange_rates"))
    setting = result.scalar_one_or_none()
    if not setting:
        return DEFAULT_EXCHANGE_RATES
    try:
        data = json.loads(setting.value_en)
        return {**DEFAULT_EXCHANGE_RATES, **data}
    except Exception:
        return DEFAULT_EXCHANGE_RATES


@router.get("/store-order")
async def get_public_store_order(db: AsyncSession = Depends(get_db)):
    """Public endpoint to fetch store icon arrangement."""
    result = await db.execute(select(AppSetting).where(AppSetting.key == "store_icon_order"))
    setting = result.scalar_one_or_none()
    if not setting:
        return DEFAULT_STORE_ORDER
    try:
        data = json.loads(setting.value_en)
        return data if isinstance(data, list) else DEFAULT_STORE_ORDER
    except Exception:
        return DEFAULT_STORE_ORDER


@router.get("", response_model=Dict[str, Any])
def get_config(url: str = Query(..., description="The e-commerce site URL")):
    config = get_config_for_url(url)
    if not config:
        raise HTTPException(
            status_code=404,
            detail=f"Configuration for URL '{url}' not found."
        )
    return config.model_dump()


@router.get("/all")
def get_all_configs():
    return {k: v.model_dump() for k, v in SITE_CONFIGS.items()}

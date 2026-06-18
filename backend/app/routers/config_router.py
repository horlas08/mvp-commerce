from fastapi import APIRouter, HTTPException, Query
from typing import Dict, Any
from app.config import get_config_for_url, SITE_CONFIGS

router = APIRouter(prefix="/config", tags=["Scraper Config"])


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

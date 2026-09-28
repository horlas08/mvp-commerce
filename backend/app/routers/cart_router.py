from datetime import datetime, timezone
import json
import re
from typing import Optional
from urllib.parse import urlparse
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.cart import CartItem, CartType
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/cart", tags=["Cart"])


def normalize_external_url(url: Optional[str]) -> str:
    if not url:
        return ""
    try:
        u = urlparse(url)
        path = u.path.rstrip("/")
        # AliExpress: /item/(\d+)\.html
        ali_match = re.search(r'/item/(\d+)\.html', path)
        if ali_match:
            return f"aliexpress://item/{ali_match.group(1)}"
        # Amazon: /dp/([A-Z0-9]{10}) or /gp/product/([A-Z0-9]{10})
        az_match = re.search(r'/(?:dp|gp/product)/([A-Z0-9]{10})', path, re.I)
        if az_match:
            return f"amazon://dp/{az_match.group(1).upper()}"
        # Shein: /goods-(\d+)\.html or -p-(\d+)\.html
        shein_match = re.search(r'(?:goods-|-p-)(\d+)', path)
        if shein_match:
            return f"shein://goods/{shein_match.group(1)}"
        # iHerb: /pr/([a-zA-Z0-9-]+)/(\d+)
        iherb_match = re.search(r'/pr/[^/]+/(\d+)', path)
        if iherb_match:
            return f"iherb://pr/{iherb_match.group(1)}"

        return f"{u.netloc.lower()}{path.lower()}"
    except Exception:
        return url.split("?")[0].rstrip("/").lower()


def normalize_selections_dict(raw: Optional[str]) -> dict:
    if not raw:
        return {}
    try:
        d = json.loads(raw)
        if isinstance(d, dict):
            norm = {}
            for k, v in d.items():
                clean_k = str(k).strip().lower().replace(":", "")
                clean_k = re.sub(r'^(ال|al-?)', '', clean_k).strip()
                if any(x in clean_k for x in ['لون', 'color', 'colour']):
                    clean_k = 'color'
                elif any(x in clean_k for x in ['حجم', 'مقاس', 'سعة', 'size']):
                    clean_k = 'size'

                clean_v = str(v).strip().lower()
                clean_v = re.sub(r'^(ال|al-?)', '', clean_v).strip()
                if clean_v:
                    norm[clean_k] = clean_v
            return norm
    except Exception:
        pass
    return {"raw": str(raw).strip().lower()}


class AddToCartRequest(BaseModel):
    cart_type: str = "internal"
    product_id: Optional[str] = None
    # For external products
    title: Optional[str] = None
    price: Optional[str] = None
    image_url: Optional[str] = None
    external_url: Optional[str] = None
    site_name: Optional[str] = None
    selections_json: Optional[str] = None
    min_quantity: int = 1
    quantity: int = 1


class UpdateCartRequest(BaseModel):
    quantity: Optional[int] = None
    is_selected: Optional[bool] = None
    price: Optional[str] = None



@router.get("")
async def get_cart(
    cart_type: Optional[str] = Query(None),
    lang: str = Query("en"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(CartItem).where(CartItem.user_id == user.id)
    if cart_type:
        try:
            ct = CartType(cart_type)
            query = query.where(CartItem.cart_type == ct)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid cart type: {cart_type}")

    # Eagerly load product for internal items
    query = query.options(selectinload(CartItem.product))
    result = await db.execute(query)
    items = result.scalars().all()
    return [item.to_dict(lang) for item in items]


@router.post("")
async def add_to_cart(
    req: AddToCartRequest,
    lang: str = Query("en"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        ct = CartType(req.cart_type)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid cart type: {req.cart_type}")

    # ── Deduplication: increment qty if same item already in cart ──────────
    existing_item = None

    if req.product_id:
        req_sel = normalize_selections_dict(req.selections_json)
        existing_query = select(CartItem).where(
            CartItem.user_id == user.id,
            CartItem.cart_type == ct,
            CartItem.product_id == req.product_id,
        )
        res = await db.execute(existing_query)
        candidates = res.scalars().all()
        for cand in candidates:
            cand_sel = normalize_selections_dict(cand.selections_json)
            if cand_sel == req_sel:
                existing_item = cand
                break
    elif req.external_url:
        req_norm_url = normalize_external_url(req.external_url)
        req_sel = normalize_selections_dict(req.selections_json)

        all_items_query = select(CartItem).where(
            CartItem.user_id == user.id,
            CartItem.cart_type == ct,
        )
        res = await db.execute(all_items_query)
        cart_items = res.scalars().all()

        for cand in cart_items:
            if not cand.external_url:
                continue
            cand_norm_url = normalize_external_url(cand.external_url)
            if cand_norm_url == req_norm_url:
                cand_sel = normalize_selections_dict(cand.selections_json)
                if cand_sel == req_sel:
                    existing_item = cand
                    break

    if existing_item:
        existing_item.quantity += req.quantity
        if req.price:
            existing_item.price = req.price
        if req.title:
            existing_item.title = req.title
        if req.image_url:
            existing_item.image_url = req.image_url
        if req.selections_json is not None:
            existing_item.selections_json = req.selections_json
        if req.min_quantity > 1:
            existing_item.min_quantity = req.min_quantity
        await db.commit()
        await db.refresh(existing_item)
        return existing_item.to_dict(lang)

    # ── No existing item found → insert new ───────────────────────────────
    item = CartItem(
        user_id=user.id,
        cart_type=ct,
        product_id=req.product_id,
        title=req.title,
        price=req.price,
        image_url=req.image_url,
        external_url=req.external_url,
        site_name=req.site_name,
        selections_json=req.selections_json,
        min_quantity=req.min_quantity,
        quantity=req.quantity,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item.to_dict(lang)



@router.put("/{item_id}")
async def update_cart_item(
    item_id: str,
    req: UpdateCartRequest,
    lang: str = Query("en"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    if req.quantity is not None:
        if req.quantity <= 0:
            await db.delete(item)
            await db.commit()
            return {"message": "Item removed from cart"}
        item.quantity = req.quantity
    if req.is_selected is not None:
        item.is_selected = req.is_selected
    if req.price is not None:
        item.price = req.price
        item.updated_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(item)
    return item.to_dict(lang)


@router.delete("/{item_id}")
async def remove_from_cart(
    item_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    await db.delete(item)
    await db.commit()
    return {"message": "Item removed from cart"}


@router.delete("")
async def clear_cart(
    cart_type: Optional[str] = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(CartItem).where(CartItem.user_id == user.id)
    if cart_type:
        try:
            ct = CartType(cart_type)
            query = query.where(CartItem.cart_type == ct)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid cart type: {cart_type}")

    result = await db.execute(query)
    items = result.scalars().all()
    for item in items:
        await db.delete(item)
    await db.commit()
    return {"message": f"Cleared {len(items)} items from cart"}

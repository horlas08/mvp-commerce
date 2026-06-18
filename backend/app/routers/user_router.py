from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
import os
import uuid
import shutil

from app.database import get_db
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    preferred_language: Optional[str] = None
    preferred_currency: Optional[str] = None


@router.get("/me")
async def get_profile(user: User = Depends(get_current_user)):
    return user.to_dict()


@router.put("/me")
async def update_profile(
    req: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if req.name is not None:
        user.name = req.name
    if req.phone is not None:
        user.phone = req.phone
    if req.avatar_url is not None:
        user.avatar_url = req.avatar_url
    if req.preferred_language is not None:
        user.preferred_language = req.preferred_language
    if req.preferred_currency is not None:
        user.preferred_currency = req.preferred_currency

    await db.commit()
    await db.refresh(user)
    return user.to_dict()


@router.post("/me/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Validate extension
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in [".jpg", ".jpeg", ".png", ".gif"]:
        raise HTTPException(status_code=400, detail="Only .jpg, .jpeg, .png, .gif files are allowed")

    # Create directory path
    static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "uploads", "avatars")
    os.makedirs(static_dir, exist_ok=True)

    # Save to unique filename
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(static_dir, unique_filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    avatar_url = f"/static/uploads/avatars/{unique_filename}"
    user.avatar_url = avatar_url

    await db.commit()
    await db.refresh(user)
    return {"avatar_url": avatar_url, "user": user.to_dict()}

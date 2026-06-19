from typing import Optional
import random
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from passlib.context import CryptContext

from app.database import get_db
from app.models.user import User
from app.auth.jwt_handler import create_access_token, create_refresh_token, verify_token
from app.auth.google_auth import verify_google_token
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ── Request / Response Schemas ──────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str
    phone: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class GoogleAuthRequest(BaseModel):
    id_token: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: dict
    debug_code: Optional[str] = None

class VerifyEmailRequest(BaseModel):
    code: str


# ── Endpoints ───────────────────────────────────────────────────────────────

@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check existing email
    result = await db.execute(select(User).where(User.email == req.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    if len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    code = "".join(random.choices("0123456789", k=6))
    user = User(
        email=req.email,
        password_hash=pwd_context.hash(req.password),
        name=req.name,
        phone=req.phone,
        is_verified=False,
        verification_code=code,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    access_token = create_access_token({"sub": user.id})
    refresh_token = create_refresh_token({"sub": user.id})
    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=user.to_dict(),
        debug_code=code
    )


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()

    if not user or not user.password_hash or not pwd_context.verify(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    code = user.verification_code if not user.is_verified else None
    access_token = create_access_token({"sub": user.id})
    refresh_token = create_refresh_token({"sub": user.id})
    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=user.to_dict(),
        debug_code=code
    )


@router.post("/google", response_model=AuthResponse)
async def google_auth(req: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    google_info = await verify_google_token(req.id_token)
    if not google_info:
        raise HTTPException(status_code=401, detail="Invalid Google token")

    google_id = google_info["google_id"]
    email = google_info["email"]

    # Check if user exists by google_id or email
    result = await db.execute(select(User).where((User.google_id == google_id) | (User.email == email)))
    user = result.scalar_one_or_none()

    code = None
    if user:
        # Link Google ID if not already linked
        if not user.google_id:
            user.google_id = google_id
            if google_info.get("picture") and not user.avatar_url:
                user.avatar_url = google_info["picture"]
            await db.commit()
            await db.refresh(user)
        if not user.is_verified:
            if not user.verification_code:
                user.verification_code = "".join(random.choices("0123456789", k=6))
                await db.commit()
                await db.refresh(user)
            code = user.verification_code
    else:
        code = "".join(random.choices("0123456789", k=6))
        # Create new user
        user = User(
            email=email,
            name=google_info["name"],
            google_id=google_id,
            avatar_url=google_info.get("picture"),
            is_verified=False,
            verification_code=code,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    access_token = create_access_token({"sub": user.id})
    refresh_token = create_refresh_token({"sub": user.id})
    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=user.to_dict(),
        debug_code=code
    )


@router.post("/forgot-password")
async def forgot_password(req: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """
    In production, this would send a reset email. For now, returns a reset token directly.
    """
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()

    # Always return success to prevent email enumeration
    if not user:
        return {"message": "If an account exists with this email, a reset link has been sent."}

    # Generate a short-lived reset token
    reset_token = create_access_token({"sub": user.id, "purpose": "reset"})
    return {"message": "If an account exists with this email, a reset link has been sent.", "reset_token": reset_token}


@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(req: RefreshTokenRequest, db: AsyncSession = Depends(get_db)):
    payload = verify_token(req.refresh_token, token_type="refresh")
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")

    access_token = create_access_token({"sub": user.id})
    new_refresh_token = create_refresh_token({"sub": user.id})
    return AuthResponse(access_token=access_token, refresh_token=new_refresh_token, user=user.to_dict())


@router.post("/verify-email")
async def verify_email(
    req: VerifyEmailRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.is_verified:
        return {"message": "Email already verified", "user": user.to_dict()}

    if not user.verification_code or user.verification_code != req.code:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    user.is_verified = True
    user.verification_code = None
    await db.commit()
    await db.refresh(user)
    return {"message": "Email verified successfully", "user": user.to_dict()}


@router.post("/resend-verification")
async def resend_verification(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.is_verified:
        return {"message": "Email already verified", "user": user.to_dict()}

    code = "".join(random.choices("0123456789", k=6))
    user.verification_code = code
    await db.commit()
    await db.refresh(user)
    return {"message": "Verification code resent.", "debug_code": code}

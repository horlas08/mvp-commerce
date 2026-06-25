from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.address import Address
from app.models.user import User
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/addresses", tags=["Addresses"])


class AddressRequest(BaseModel):
    label: str
    full_name: str
    phone: str
    street: str
    city: str
    state: Optional[str] = None
    country: str = "Saudi Arabia"
    postal_code: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    is_default: bool = False


class LocationUpdateRequest(BaseModel):
    lat: float
    lng: float


@router.get("")
async def list_addresses(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Address).where(Address.user_id == user.id))
    addresses = result.scalars().all()
    return [a.to_dict() for a in addresses]


@router.post("")
async def add_address(
    req: AddressRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # If setting as default, unset other defaults
    if req.is_default:
        result = await db.execute(select(Address).where(Address.user_id == user.id, Address.is_default == True))
        for addr in result.scalars().all():
            addr.is_default = False

    address = Address(user_id=user.id, **req.model_dump())
    db.add(address)
    await db.commit()
    await db.refresh(address)
    return address.to_dict()


@router.put("/{address_id}")
async def update_address(
    address_id: str,
    req: AddressRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Address).where(Address.id == address_id, Address.user_id == user.id))
    address = result.scalar_one_or_none()
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")

    if req.is_default:
        res = await db.execute(select(Address).where(Address.user_id == user.id, Address.is_default == True))
        for addr in res.scalars().all():
            addr.is_default = False

    for key, value in req.model_dump().items():
        setattr(address, key, value)

    await db.commit()
    await db.refresh(address)
    return address.to_dict()


@router.delete("/{address_id}")
async def delete_address(
    address_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Address).where(Address.id == address_id, Address.user_id == user.id))
    address = result.scalar_one_or_none()
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")

    await db.delete(address)
    await db.commit()
    return {"message": "Address deleted"}


@router.patch("/{address_id}/location")
async def update_address_location(
    address_id: str,
    req: LocationUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Address).where(Address.id == address_id, Address.user_id == user.id))
    address = result.scalar_one_or_none()
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")

    address.lat = req.lat
    address.lng = req.lng

    await db.commit()
    await db.refresh(address)
    return address.to_dict()


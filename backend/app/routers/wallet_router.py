from fastapi import APIRouter, Depends
from app.auth.dependencies import get_current_user
from app.models.user import User

router = APIRouter(prefix="/wallet", tags=["Wallet"])


@router.get("/balance")
async def get_wallet_balance(user: User = Depends(get_current_user)):
    return {"balance": user.credit_balance}

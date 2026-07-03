import uuid
import enum
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Float, Text, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class WalletTransactionType(str, enum.Enum):
    CREDIT = "credit"
    DEBIT = "debit"


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    type: Mapped[WalletTransactionType] = mapped_column(Enum(WalletTransactionType), nullable=False)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    reference_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)  # order_id or refund_id
    reference_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)  # "order", "refund", "admin_adjustment"
    balance_after: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    user = relationship("User", back_populates="wallet_transactions")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "amount": self.amount,
            "type": self.type.value,
            "reason": self.reason,
            "reference_id": self.reference_id,
            "reference_type": self.reference_type,
            "balance_after": self.balance_after,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

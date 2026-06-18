import uuid
import enum
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Text, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class RefundStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"


class RefundRequest(Base):
    __tablename__ = "refund_requests"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id: Mapped[str] = mapped_column(String(36), ForeignKey("orders.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[RefundStatus] = mapped_column(Enum(RefundStatus), default=RefundStatus.PENDING)
    admin_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relationships
    user = relationship("User", back_populates="refund_requests")
    order = relationship("Order")

    def to_dict(self):
        return {
            "id": self.id,
            "order_id": self.order_id,
            "user_id": self.user_id,
            "reason": self.reason,
            "status": self.status.value,
            "admin_note": self.admin_note,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

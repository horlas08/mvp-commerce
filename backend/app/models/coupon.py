import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Float, Integer, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class Coupon(Base):
    __tablename__ = "coupons"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    description_en: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    description_ar: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    discount_type: Mapped[str] = mapped_column(String(20), default="percentage")  # percentage, fixed
    discount_value: Mapped[float] = mapped_column(Float, nullable=False)
    min_order_amount: Mapped[float] = mapped_column(Float, default=0.0)
    max_discount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    usage_limit: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    used_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

    def to_dict(self, lang: str = "en"):
        return {
            "id": self.id,
            "code": self.code,
            "description": self.description_en if lang == "en" else self.description_ar,
            "discount_type": self.discount_type,
            "discount_value": self.discount_value,
            "min_order_amount": self.min_order_amount,
            "max_discount": self.max_discount,
            "is_active": self.is_active,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
        }

import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Boolean, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Seller(Base):
    __tablename__ = "sellers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), nullable=False, unique=True, index=True)
    store_name_en: Mapped[str] = mapped_column(String(255), nullable=False)
    store_name_ar: Mapped[str] = mapped_column(String(255), nullable=False)
    logo_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    description_en: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    description_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    products = relationship("Product", back_populates="seller")

    def to_dict(self, lang: str = "en"):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "store_name": self.store_name_en if lang == "en" else self.store_name_ar,
            "store_name_en": self.store_name_en,
            "store_name_ar": self.store_name_ar,
            "logo_url": self.logo_url,
            "description": self.description_en if lang == "en" else self.description_ar,
            "is_verified": self.is_verified,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

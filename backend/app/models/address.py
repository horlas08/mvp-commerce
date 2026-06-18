import uuid
from typing import Optional
from sqlalchemy import String, Float, Boolean, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Address(Base):
    __tablename__ = "addresses"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    label: Mapped[str] = mapped_column(String(100), nullable=False)  # e.g. "Home", "Work"
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[str] = mapped_column(String(20), nullable=False)
    street: Mapped[Text] = mapped_column(Text, nullable=False)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    country: Mapped[str] = mapped_column(String(100), default="Saudi Arabia")
    postal_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)

    # Relationships
    user = relationship("User", back_populates="addresses")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "label": self.label,
            "full_name": self.full_name,
            "phone": self.phone,
            "street": self.street,
            "city": self.city,
            "state": self.state,
            "country": self.country,
            "postal_code": self.postal_code,
            "lat": self.lat,
            "lng": self.lng,
            "is_default": self.is_default,
        }

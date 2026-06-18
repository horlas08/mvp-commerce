import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Float, Integer, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title_en: Mapped[str] = mapped_column(String(500), nullable=False)
    title_ar: Mapped[str] = mapped_column(String(500), nullable=False)
    description_en: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    description_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    price: Mapped[float] = mapped_column(Float, nullable=False)
    discount_price: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    currency: Mapped[str] = mapped_column(String(5), default="SAR")
    images: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)  # List of image URLs
    category_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("categories.id"), nullable=True)
    seller_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("sellers.id"), nullable=True)
    stock: Mapped[int] = mapped_column(Integer, default=0)
    rating: Mapped[float] = mapped_column(Float, default=0.0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    category = relationship("Category", back_populates="products")
    seller = relationship("Seller", back_populates="products")

    def to_dict(self, lang: str = "en"):
        return {
            "id": self.id,
            "title": self.title_en if lang == "en" else self.title_ar,
            "title_en": self.title_en,
            "title_ar": self.title_ar,
            "description": self.description_en if lang == "en" else self.description_ar,
            "price": self.price,
            "discount_price": self.discount_price,
            "currency": self.currency,
            "images": self.images or [],
            "category_id": self.category_id,
            "seller_id": self.seller_id,
            "stock": self.stock,
            "rating": self.rating,
            "rating_count": self.rating_count,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

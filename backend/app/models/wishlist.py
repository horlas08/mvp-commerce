import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class WishlistItem(Base):
    __tablename__ = "wishlist_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    product_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("products.id"), nullable=True)
    # For external products
    external_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    price: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    source: Mapped[str] = mapped_column(String(50), default="internal")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    user = relationship("User", back_populates="wishlist_items")
    product = relationship("Product")

    def to_dict(self):
        result = {
            "id": self.id,
            "user_id": self.user_id,
            "source": self.source,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if self.product_id and self.product:
            result["product"] = self.product.to_dict()
        else:
            result["external_url"] = self.external_url
            result["title"] = self.title
            result["price"] = self.price
            result["image_url"] = self.image_url
        return result

import uuid
import enum
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Float, Integer, Text, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class CartType(str, enum.Enum):
    INTERNAL = "internal"
    AMAZON = "amazon"
    ALIEXPRESS = "aliexpress"
    SHEIN = "shein"
    ALIBABA = "alibaba"


class CartItem(Base):
    __tablename__ = "cart_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    cart_type: Mapped[CartType] = mapped_column(Enum(CartType), nullable=False, default=CartType.INTERNAL)

    # For internal products
    product_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("products.id"), nullable=True)

    # For external products (scraped from WebView)
    title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    price: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    external_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    site_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    quantity: Mapped[int] = mapped_column(Integer, default=1)
    is_selected: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    user = relationship("User", back_populates="cart_items")
    product = relationship("Product")

    def to_dict(self, lang: str = "en"):
        result = {
            "id": self.id,
            "user_id": self.user_id,
            "cart_type": self.cart_type.value,
            "quantity": self.quantity,
            "is_selected": self.is_selected,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if self.cart_type == CartType.INTERNAL and self.product:
            result["product"] = self.product.to_dict(lang)
        else:
            result["title"] = self.title
            result["price"] = self.price
            result["image_url"] = self.image_url
            result["external_url"] = self.external_url
            result["site_name"] = self.site_name
        return result

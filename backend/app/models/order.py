import uuid
import enum
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, Float, Integer, Text, DateTime, ForeignKey, Enum, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class OrderStatus(str, enum.Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    PROCESSING = "processing"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), default=OrderStatus.PENDING)
    total: Mapped[float] = mapped_column(Float, default=0.0)
    currency: Mapped[str] = mapped_column(String(5), default="SAR")
    shipping_address: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    coupon_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    discount_amount: Mapped[float] = mapped_column(Float, default=0.0)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relationships
    user = relationship("User", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "status": self.status.value,
            "total": self.total,
            "currency": self.currency,
            "shipping_address": self.shipping_address,
            "coupon_code": self.coupon_code,
            "discount_amount": self.discount_amount,
            "notes": self.notes,
            "items": [item.to_dict() for item in self.items] if self.items else [],
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id: Mapped[str] = mapped_column(String(36), ForeignKey("orders.id"), nullable=False)
    product_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("products.id"), nullable=True)

    # Snapshot of product at order time
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    price: Mapped[float] = mapped_column(Float, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    source: Mapped[str] = mapped_column(String(50), default="internal")  # internal, amazon, aliexpress, etc.

    # Relationships
    order = relationship("Order", back_populates="items")

    def to_dict(self):
        return {
            "id": self.id,
            "order_id": self.order_id,
            "product_id": self.product_id,
            "title": self.title,
            "price": self.price,
            "quantity": self.quantity,
            "image_url": self.image_url,
            "source": self.source,
        }

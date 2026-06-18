import uuid
from typing import Optional
from sqlalchemy import String, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name_en: Mapped[str] = mapped_column(String(255), nullable=False)
    name_ar: Mapped[str] = mapped_column(String(255), nullable=False)
    icon: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # Icon name / emoji
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    parent_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("categories.id"), nullable=True)
    sort_order: Mapped[int] = mapped_column(default=0)

    # Relationships
    products = relationship("Product", back_populates="category")
    parent = relationship("Category", remote_side=[id], backref="children")

    def to_dict(self, lang: str = "en"):
        return {
            "id": self.id,
            "name": self.name_en if lang == "en" else self.name_ar,
            "name_en": self.name_en,
            "name_ar": self.name_ar,
            "icon": self.icon,
            "image_url": self.image_url,
            "parent_id": self.parent_id,
            "sort_order": self.sort_order,
        }

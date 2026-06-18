import uuid
from typing import Optional
from sqlalchemy import String, Integer, Boolean, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class Banner(Base):
    __tablename__ = "banners"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title_en: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    title_ar: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    image_url: Mapped[str] = mapped_column(Text, nullable=False)
    link_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    def to_dict(self, lang: str = "en"):
        return {
            "id": self.id,
            "title": self.title_en if lang == "en" else self.title_ar,
            "image_url": self.image_url,
            "link_url": self.link_url,
            "sort_order": self.sort_order,
            "is_active": self.is_active,
        }

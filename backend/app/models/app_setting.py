import uuid
from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class AppSetting(Base):
    __tablename__ = "app_settings"

    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    value_en: Mapped[str] = mapped_column(Text, nullable=False)
    value_ar: Mapped[str] = mapped_column(Text, nullable=False)

    def to_dict(self):
        return {
            "key": self.key,
            "value_en": self.value_en,
            "value_ar": self.value_ar,
        }

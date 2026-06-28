import uuid
import json
from typing import Optional
from sqlalchemy import String, Text, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class PaymentMethod(Base):
    __tablename__ = "payment_methods"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title_en: Mapped[str] = mapped_column(String(255), nullable=False)
    title_ar: Mapped[str] = mapped_column(String(255), nullable=False)
    details_en: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    details_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    
    # Store JSON array of fields like: [{"key": "bank_name", "label_en": "Bank Name", "label_ar": "اسم البنك"}]
    fields_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True, default="[]")

    def to_dict(self, lang: str = "en"):
        try:
            fields_list = json.loads(self.fields_json or "[]")
        except Exception:
            fields_list = []

        # Localize fields for the API response
        localized_fields = []
        for field in fields_list:
            item = {
                "key": field.get("key", ""),
                "label": field.get("label_en" if lang == "en" else "label_ar", field.get("label", "")),
                "type": field.get("type", "text")
            }
            if "options" in field:
                item["options"] = field["options"]
            localized_fields.append(item)

        return {
            "id": self.id,
            "title": self.title_en if lang == "en" else self.title_ar,
            "title_en": self.title_en,
            "title_ar": self.title_ar,
            "details": self.details_en if lang == "en" else self.details_ar,
            "details_en": self.details_en,
            "details_ar": self.details_ar,
            "image_url": self.image_url,
            "is_active": self.is_active,
            "fields": localized_fields,
            "raw_fields": fields_list,  # Raw list with localized labels for admin panel
        }

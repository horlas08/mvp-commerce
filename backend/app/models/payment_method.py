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
    description_en: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    description_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    details_en: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    details_ar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    
    # Store JSON array of fields like: [{"key": "bank_name", "label_en": "Bank Name", "label_ar": "اسم البنك"}]
    fields_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True, default="[]")
    # Store JSON array of bank accounts for bank transfer methods
    bank_accounts_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True, default="[]")

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

        try:
            bank_accounts_list = json.loads(self.bank_accounts_json or "[]")
        except Exception:
            bank_accounts_list = []

        localized_bank_accounts = []
        for acc in bank_accounts_list:
            localized_bank_accounts.append({
                "id": acc.get("id", ""),
                "bank_name": acc.get("bank_name_en" if lang == "en" else "bank_name_ar", acc.get("bank_name", "")),
                "bank_name_en": acc.get("bank_name_en", ""),
                "bank_name_ar": acc.get("bank_name_ar", ""),
                "account_number": acc.get("account_number", ""),
                "account_name": acc.get("account_name", ""),
                "iban": acc.get("iban", ""),
                "logo_url": acc.get("logo_url", ""),
            })

        return {
            "id": self.id,
            "title": self.title_en if lang == "en" else self.title_ar,
            "title_en": self.title_en,
            "title_ar": self.title_ar,
            "description": self.description_en if lang == "en" else self.description_ar,
            "description_en": self.description_en,
            "description_ar": self.description_ar,
            "details": self.details_en if lang == "en" else self.details_ar,
            "details_en": self.details_en,
            "details_ar": self.details_ar,
            "image_url": self.image_url,
            "is_active": self.is_active,
            "fields": localized_fields,
            "raw_fields": fields_list,  # Raw list with localized labels for admin panel
            "bank_accounts": localized_bank_accounts,
            "raw_bank_accounts": bank_accounts_list,
        }

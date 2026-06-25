import uuid
from sqlalchemy import String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class State(Base):
    __tablename__ = "states"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name_en: Mapped[str] = mapped_column(String(255), nullable=False)
    name_ar: Mapped[str] = mapped_column(String(255), nullable=False)

    cities = relationship("City", back_populates="state", cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name_en,
            "name_en": self.name_en,
            "name_ar": self.name_ar,
        }


class City(Base):
    __tablename__ = "cities"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    state_id: Mapped[str] = mapped_column(String(36), ForeignKey("states.id"), nullable=False, index=True)
    name_en: Mapped[str] = mapped_column(String(255), nullable=False)
    name_ar: Mapped[str] = mapped_column(String(255), nullable=False)

    state = relationship("State", back_populates="cities")

    def to_dict(self):
        return {
            "id": self.id,
            "state_id": self.state_id,
            "name": self.name_en,
            "name_en": self.name_en,
            "name_ar": self.name_ar,
        }

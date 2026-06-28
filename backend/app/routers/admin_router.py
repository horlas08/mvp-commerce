import os
import shutil
import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, File, UploadFile
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.order import Order, OrderStatus
from app.models.category import Category
from app.models.coupon import Coupon
from app.models.banner import Banner
from app.models.location import State, City
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/admin", tags=["Admin"])


# ── Admin guard dependency ──────────────────────────────────────────────────

async def get_admin_user(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


@router.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    # Validate extension
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in [".jpg", ".jpeg", ".png", ".gif", ".webp"]:
        raise HTTPException(status_code=400, detail="Only .jpg, .jpeg, .png, .gif, .webp files are allowed")

    # Create directory path
    static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "uploads", "images")
    os.makedirs(static_dir, exist_ok=True)

    # Save to unique filename
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(static_dir, unique_filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    image_url = f"/static/uploads/images/{unique_filename}"
    return {"image_url": image_url}


# ── Stats ───────────────────────────────────────────────────────────────────

@router.get("/stats")
async def get_stats(db: AsyncSession = Depends(get_db), _: User = Depends(get_admin_user)):
    """Overall dashboard stats."""
    total_users = (await db.execute(select(func.count(User.id)))).scalar_one()
    total_products = (await db.execute(select(func.count(Product.id)))).scalar_one()
    total_orders = (await db.execute(select(func.count(Order.id)))).scalar_one()
    total_revenue = (await db.execute(select(func.coalesce(func.sum(Order.total), 0.0)))).scalar_one()
    pending_orders = (await db.execute(
        select(func.count(Order.id)).where(Order.status == OrderStatus.PENDING)
    )).scalar_one()
    active_products = (await db.execute(
        select(func.count(Product.id)).where(Product.is_active == True)
    )).scalar_one()

    return {
        "total_users": total_users,
        "total_products": total_products,
        "total_orders": total_orders,
        "total_revenue": float(total_revenue),
        "pending_orders": pending_orders,
        "active_products": active_products,
    }


# ── Users ───────────────────────────────────────────────────────────────────

@router.get("/users")
async def list_users(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    role: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    query = select(User)
    if search:
        query = query.where(
            (User.email.ilike(f"%{search}%")) | (User.name.ilike(f"%{search}%"))
        )
    if role:
        query = query.where(User.role == role)
    query = query.order_by(User.created_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    users = result.scalars().all()
    count_query = select(func.count(User.id))
    if search:
        count_query = count_query.where(
            (User.email.ilike(f"%{search}%")) | (User.name.ilike(f"%{search}%"))
        )
    if role:
        count_query = count_query.where(User.role == role)
    total = (await db.execute(count_query)).scalar_one()
    return {"users": [u.to_dict() for u in users], "total": total, "page": page, "limit": limit}


class UpdateUserRequest(BaseModel):
    role: Optional[str] = None
    is_active: Optional[bool] = None
    credit_balance: Optional[float] = None


@router.patch("/users/{user_id}")
async def update_user(
    user_id: str,
    req: UpdateUserRequest,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if req.role is not None:
        user.role = req.role
    if req.is_active is not None:
        user.is_active = req.is_active
    if req.credit_balance is not None:
        user.credit_balance = req.credit_balance
    await db.commit()
    return user.to_dict()


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_admin_user),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    await db.delete(user)
    await db.commit()
    return {"message": "User deleted"}


# ── Products ─────────────────────────────────────────────────────────────────

@router.get("/products")
async def list_products_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    category_id: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    query = select(Product)
    if search:
        query = query.where(
            (Product.title_en.ilike(f"%{search}%")) | (Product.title_ar.ilike(f"%{search}%"))
        )
    if category_id:
        query = query.where(Product.category_id == category_id)
    query = query.order_by(Product.created_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    products = result.scalars().all()

    count_query = select(func.count(Product.id))
    if search:
        count_query = count_query.where(
            (Product.title_en.ilike(f"%{search}%")) | (Product.title_ar.ilike(f"%{search}%"))
        )
    if category_id:
        count_query = count_query.where(Product.category_id == category_id)
    total = (await db.execute(count_query)).scalar_one()

    return {"products": [p.to_dict() for p in products], "total": total, "page": page, "limit": limit}


class CreateProductRequest(BaseModel):
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    price: float
    discount_price: Optional[float] = None
    category_id: Optional[str] = None
    stock: int = 0
    images: Optional[list] = None


@router.post("/products")
async def create_product(
    req: CreateProductRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    product = Product(**req.model_dump())
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product.to_dict()


class UpdateProductRequest(BaseModel):
    title_en: Optional[str] = None
    title_ar: Optional[str] = None
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    price: Optional[float] = None
    discount_price: Optional[float] = None
    category_id: Optional[str] = None
    stock: Optional[int] = None
    is_active: Optional[bool] = None
    images: Optional[list] = None


@router.patch("/products/{product_id}")
async def update_product(
    product_id: str,
    req: UpdateProductRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    for field, value in req.model_dump(exclude_none=True).items():
        setattr(product, field, value)
    await db.commit()
    return product.to_dict()


@router.delete("/products/{product_id}")
async def delete_product(
    product_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    await db.delete(product)
    await db.commit()
    return {"message": "Product deleted"}


# ── Orders ───────────────────────────────────────────────────────────────────

@router.get("/orders")
async def list_orders_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    query = select(Order).options(selectinload(Order.items), selectinload(Order.user))
    if status:
        try:
            os_ = OrderStatus(status)
            query = query.where(Order.status == os_)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid status: {status}")
    query = query.order_by(Order.created_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    orders = result.scalars().all()

    count_query = select(func.count(Order.id))
    if status:
        count_query = count_query.where(Order.status == OrderStatus(status))
    total = (await db.execute(count_query)).scalar_one()

    def order_dict(o: Order):
        d = o.to_dict()
        d["user_name"] = o.user.name if o.user else None
        d["user_email"] = o.user.email if o.user else None
        return d

    return {"orders": [order_dict(o) for o in orders], "total": total, "page": page, "limit": limit}


class UpdateOrderStatusRequest(BaseModel):
    status: str


@router.patch("/orders/{order_id}/status")
async def update_order_status(
    order_id: str,
    req: UpdateOrderStatusRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    try:
        order.status = OrderStatus(req.status)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid status: {req.status}")
    await db.commit()
    return {"message": "Status updated", "status": order.status.value}


# ── Categories ────────────────────────────────────────────────────────────────

@router.get("/categories")
async def list_categories_admin(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Category).order_by(Category.sort_order))
    categories = result.scalars().all()
    return [c.to_dict() for c in categories]


class CategoryRequest(BaseModel):
    name_en: str
    name_ar: str
    icon: Optional[str] = None
    image_url: Optional[str] = None
    sort_order: int = 0


@router.post("/categories")
async def create_category(
    req: CategoryRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    import uuid
    cat = Category(id=str(uuid.uuid4()), **req.model_dump())
    db.add(cat)
    await db.commit()
    await db.refresh(cat)
    return cat.to_dict()


@router.patch("/categories/{cat_id}")
async def update_category(
    cat_id: str,
    req: CategoryRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Category).where(Category.id == cat_id))
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    for field, value in req.model_dump(exclude_none=True).items():
        setattr(cat, field, value)
    await db.commit()
    return cat.to_dict()


@router.delete("/categories/{cat_id}")
async def delete_category(
    cat_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Category).where(Category.id == cat_id))
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await db.delete(cat)
    await db.commit()
    return {"message": "Category deleted"}


# ── Admin login (creates/finds admin user) ────────────────────────────────────

class AdminLoginRequest(BaseModel):
    email: str
    password: str


@router.post("/login")
async def admin_login(req: AdminLoginRequest, db: AsyncSession = Depends(get_db)):
    """Admin-specific login endpoint that only accepts admin-role users."""
    from app.auth.security import verify_password
    from app.auth.jwt_handler import create_access_token, create_refresh_token

    result = await db.execute(select(User).where(User.email == req.email, User.role == "admin"))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials or not an admin")
    if not user.is_active:
        raise HTTPException(status_code=401, detail="Admin account is inactive")
    if not user.password_hash:
        raise HTTPException(status_code=401, detail="Password login not configured for this account")
    if not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token({"sub": user.id, "role": user.role})
    refresh_token = create_refresh_token({"sub": user.id})
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user": user.to_dict(),
    }


@router.post("/seed-admin")
async def seed_admin(db: AsyncSession = Depends(get_db)):
    """One-time endpoint to create the default admin account. Remove in production."""
    from app.auth.security import hash_password

    result = await db.execute(select(User).where(User.role == "admin"))
    existing = result.scalar_one_or_none()
    if existing:
        if not existing.is_active:
            existing.is_active = True
            await db.commit()
            return {"message": "Admin account activated", "email": existing.email}
        return {"message": "Admin already exists", "email": existing.email}

    password_hash = hash_password("admin123")
    admin = User(
        email="admin@koon.sa",
        password_hash=password_hash,
        name="Koon Admin",
        role="admin",
        is_active=True,
        is_verified=True,
    )
    db.add(admin)
    await db.commit()
    return {"message": "Admin created", "email": "admin@koon.sa", "password": "admin123"}


# ── States & Cities ──────────────────────────────────────────────────────────

class StateRequest(BaseModel):
    name_en: str
    name_ar: str

class CityRequest(BaseModel):
    state_id: str
    name_en: str
    name_ar: str

@router.get("/states")
async def list_states_admin(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    result = await db.execute(select(State).order_by(State.name_en))
    return [s.to_dict() for s in result.scalars().all()]

@router.post("/states")
async def create_state_admin(
    req: StateRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    state = State(**req.model_dump())
    db.add(state)
    await db.commit()
    await db.refresh(state)
    return state.to_dict()

@router.patch("/states/{state_id}")
async def update_state_admin(
    state_id: str,
    req: StateRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    result = await db.execute(select(State).where(State.id == state_id))
    state = result.scalar_one_or_none()
    if not state:
        raise HTTPException(status_code=404, detail="State not found")
    state.name_en = req.name_en
    state.name_ar = req.name_ar
    await db.commit()
    await db.refresh(state)
    return state.to_dict()

@router.delete("/states/{state_id}")
async def delete_state_admin(
    state_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    result = await db.execute(select(State).where(State.id == state_id))
    state = result.scalar_one_or_none()
    if not state:
        raise HTTPException(status_code=404, detail="State not found")
    await db.delete(state)
    await db.commit()
    return {"message": "State deleted"}

@router.get("/cities")
async def list_cities_admin(
    state_id: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    query = select(City)
    if state_id:
        query = query.where(City.state_id == state_id)
    query = query.order_by(City.name_en)
    result = await db.execute(query)
    return [c.to_dict() for c in result.scalars().all()]

@router.post("/cities")
async def create_city_admin(
    req: CityRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    # Verify state exists
    state_check = await db.execute(select(State).where(State.id == req.state_id))
    if not state_check.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="State not found")
    city = City(**req.model_dump())
    db.add(city)
    await db.commit()
    await db.refresh(city)
    return city.to_dict()

@router.patch("/cities/{city_id}")
async def update_city_admin(
    city_id: str,
    req: CityRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")
    
    state_check = await db.execute(select(State).where(State.id == req.state_id))
    if not state_check.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="State not found")

    city.state_id = req.state_id
    city.name_en = req.name_en
    city.name_ar = req.name_ar
    await db.commit()
    await db.refresh(city)
    return city.to_dict()

@router.delete("/cities/{city_id}")
async def delete_city_admin(
    city_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")
    await db.delete(city)
    await db.commit()
    return {"message": "City deleted"}


# ── Payment Methods ──────────────────────────────────────────────────────────

class PaymentMethodRequest(BaseModel):
    title_en: str
    title_ar: str
    details_en: Optional[str] = None
    details_ar: Optional[str] = None
    image_url: Optional[str] = None
    is_active: bool = True
    fields: Optional[list] = None  # list of field dicts: [{"key": "...", "label_en": "...", "label_ar": "..."}]


@router.get("/payment-methods")
async def list_payment_methods_admin(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    from app.models.payment_method import PaymentMethod
    result = await db.execute(select(PaymentMethod))
    methods = result.scalars().all()
    return [m.to_dict("en") for m in methods]


@router.post("/payment-methods")
async def create_payment_method_admin(
    req: PaymentMethodRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    from app.models.payment_method import PaymentMethod
    import json
    import uuid
    fields_str = json.dumps(req.fields or [])
    method = PaymentMethod(
        id=str(uuid.uuid4()),
        title_en=req.title_en,
        title_ar=req.title_ar,
        details_en=req.details_en,
        details_ar=req.details_ar,
        image_url=req.image_url,
        is_active=req.is_active,
        fields_json=fields_str
    )
    db.add(method)
    await db.commit()
    await db.refresh(method)
    return method.to_dict("en")


@router.patch("/payment-methods/{method_id}")
async def update_payment_method_admin(
    method_id: str,
    req: PaymentMethodRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    from app.models.payment_method import PaymentMethod
    import json
    result = await db.execute(select(PaymentMethod).where(PaymentMethod.id == method_id))
    method = result.scalar_one_or_none()
    if not method:
        raise HTTPException(status_code=404, detail="Payment method not found")
    
    method.title_en = req.title_en
    method.title_ar = req.title_ar
    method.details_en = req.details_en
    method.details_ar = req.details_ar
    method.image_url = req.image_url
    method.is_active = req.is_active
    if req.fields is not None:
        method.fields_json = json.dumps(req.fields)
        
    await db.commit()
    await db.refresh(method)
    return method.to_dict("en")


@router.delete("/payment-methods/{method_id}")
async def delete_payment_method_admin(
    method_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user)
):
    from app.models.payment_method import PaymentMethod
    result = await db.execute(select(PaymentMethod).where(PaymentMethod.id == method_id))
    method = result.scalar_one_or_none()
    if not method:
        raise HTTPException(status_code=404, detail="Payment method not found")
    await db.delete(method)
    await db.commit()
    return {"message": "Payment method deleted"}

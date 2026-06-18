from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.database import init_db
from app.routers import (
    auth_router,
    user_router,
    product_router,
    category_router,
    cart_router,
    order_router,
    wishlist_router,
    address_router,
    coupon_router,
    seller_router,
    refund_router,
    config_router,
)

# Ensure all models are imported so SQLAlchemy can create their tables
import app.models  # noqa: F401


@asynccontextmanager
async def lifespan(application: FastAPI):
    """Startup / shutdown lifecycle manager."""
    await init_db()
    await _seed_demo_data()
    yield


app = FastAPI(
    title="Koon Commerce API",
    description="Full e-commerce API with internal products + external store aggregation",
    version="2.0.0",
    lifespan=lifespan,
)

# Mount static files directory
static_dir = os.path.join(os.path.dirname(__file__), "static")
os.makedirs(os.path.join(static_dir, "uploads", "avatars"), exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Enable CORS for mobile development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Register API routers ────────────────────────────────────────────────────
API_PREFIX = "/api/v1"
app.include_router(auth_router.router, prefix=API_PREFIX)
app.include_router(user_router.router, prefix=API_PREFIX)
app.include_router(product_router.router, prefix=API_PREFIX)
app.include_router(category_router.router, prefix=API_PREFIX)
app.include_router(cart_router.router, prefix=API_PREFIX)
app.include_router(order_router.router, prefix=API_PREFIX)
app.include_router(wishlist_router.router, prefix=API_PREFIX)
app.include_router(address_router.router, prefix=API_PREFIX)
app.include_router(coupon_router.router, prefix=API_PREFIX)
app.include_router(seller_router.router, prefix=API_PREFIX)
app.include_router(refund_router.router, prefix=API_PREFIX)
app.include_router(config_router.router, prefix=API_PREFIX)


@app.get("/")
def read_root():
    return {"message": "Koon Commerce API v2.0 is running.", "docs": "/docs"}


# ── Seed demo data ──────────────────────────────────────────────────────────

async def _seed_demo_data():
    """Populate the database with demo categories, products, and banners for development."""
    from app.database import async_session
    from app.models.category import Category
    from app.models.product import Product
    from app.models.banner import Banner
    from app.models.coupon import Coupon
    from sqlalchemy import select
    from datetime import datetime, timedelta, timezone

    async with async_session() as db:
        # Only seed if categories table is empty
        result = await db.execute(select(Category).limit(1))
        if result.scalar_one_or_none():
            return

        # Categories
        categories = [
            Category(id="cat-electronics", name_en="Electronics", name_ar="إلكترونيات", icon="📱", sort_order=1,
                     image_url="https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400"),
            Category(id="cat-fashion", name_en="Fashion", name_ar="أزياء", icon="👗", sort_order=2,
                     image_url="https://images.unsplash.com/photo-1445205170230-053b83016050?w=400"),
            Category(id="cat-home", name_en="Home & Garden", name_ar="المنزل والحديقة", icon="🏠", sort_order=3,
                     image_url="https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400"),
            Category(id="cat-beauty", name_en="Beauty & Health", name_ar="الجمال والصحة", icon="💄", sort_order=4,
                     image_url="https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400"),
            Category(id="cat-sports", name_en="Sports & Outdoors", name_ar="رياضة وأنشطة خارجية", icon="⚽", sort_order=5,
                     image_url="https://images.unsplash.com/photo-1461896836934-bd45ba8fcf9b?w=400"),
            Category(id="cat-toys", name_en="Toys & Kids", name_ar="ألعاب وأطفال", icon="🧸", sort_order=6,
                     image_url="https://images.unsplash.com/photo-1558060370-d644479cb6f7?w=400"),
            Category(id="cat-auto", name_en="Automotive", name_ar="سيارات", icon="🚗", sort_order=7,
                     image_url="https://images.unsplash.com/photo-1489824904134-891ab64532f1?w=400"),
            Category(id="cat-books", name_en="Books & Stationery", name_ar="كتب وقرطاسية", icon="📚", sort_order=8,
                     image_url="https://images.unsplash.com/photo-1524578271613-d550eacf6090?w=400"),
        ]
        db.add_all(categories)

        # Products
        products = [
            Product(
                title_en="Wireless Bluetooth Headphones",
                title_ar="سماعات بلوتوث لاسلكية",
                description_en="Premium noise-cancelling headphones with 30hr battery life",
                description_ar="سماعات فاخرة بخاصية إلغاء الضوضاء مع بطارية تدوم 30 ساعة",
                price=299.0, discount_price=249.0, category_id="cat-electronics",
                stock=50, rating=4.5, rating_count=128,
                images=["https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400"],
            ),
            Product(
                title_en="Smart Watch Pro",
                title_ar="ساعة ذكية برو",
                description_en="Advanced fitness tracking, heart rate monitor, GPS",
                description_ar="تتبع اللياقة البدنية المتقدم، مراقب معدل ضربات القلب، GPS",
                price=599.0, discount_price=499.0, category_id="cat-electronics",
                stock=30, rating=4.7, rating_count=256,
                images=["https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400"],
            ),
            Product(
                title_en="Elegant Summer Dress",
                title_ar="فستان صيفي أنيق",
                description_en="Lightweight floral summer dress, perfect for warm days",
                description_ar="فستان صيفي خفيف بنقشة زهور، مثالي للأيام الدافئة",
                price=189.0, discount_price=149.0, category_id="cat-fashion",
                stock=100, rating=4.3, rating_count=89,
                images=["https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=400"],
            ),
            Product(
                title_en="Men's Casual Sneakers",
                title_ar="حذاء رياضي كاجوال رجالي",
                description_en="Comfortable everyday sneakers with memory foam insole",
                description_ar="حذاء رياضي مريح للاستخدام اليومي مع نعل داخلي من الإسفنج",
                price=259.0, category_id="cat-fashion",
                stock=75, rating=4.1, rating_count=67,
                images=["https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400"],
            ),
            Product(
                title_en="Luxury Perfume Set",
                title_ar="طقم عطور فاخر",
                description_en="Premium fragrance collection, 3 bottles gift set",
                description_ar="مجموعة عطور فاخرة، طقم هدايا 3 زجاجات",
                price=450.0, discount_price=380.0, category_id="cat-beauty",
                stock=40, rating=4.8, rating_count=192,
                images=["https://images.unsplash.com/photo-1541643600914-78b084683601?w=400"],
            ),
            Product(
                title_en="Kids Formal Suit - 5 Pieces",
                title_ar="طقم ولادي رسمي - 5 قطع",
                description_en="Complete formal suit set for boys, ideal for events",
                description_ar="طقم بدلة رسمية كامل للأولاد، مثالي للمناسبات",
                price=330.0, discount_price=315.0, category_id="cat-toys",
                stock=25, rating=4.4, rating_count=45,
                images=["https://images.unsplash.com/photo-1503944583220-79d8926ad5e2?w=400"],
            ),
            Product(
                title_en="Robot Vacuum Cleaner",
                title_ar="مكنسة روبوت ذكية",
                description_en="Self-charging robot vacuum with mapping technology",
                description_ar="مكنسة روبوت ذاتية الشحن مع تقنية الخرائط",
                price=899.0, discount_price=749.0, category_id="cat-home",
                stock=20, rating=4.6, rating_count=312,
                images=["https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400"],
            ),
            Product(
                title_en="Yoga Mat Premium",
                title_ar="سجادة يوغا فاخرة",
                description_en="Non-slip exercise mat, extra thick, eco-friendly",
                description_ar="سجادة تمارين مانعة للانزلاق، سميكة، صديقة للبيئة",
                price=120.0, discount_price=89.0, category_id="cat-sports",
                stock=60, rating=4.2, rating_count=78,
                images=["https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=400"],
            ),
        ]
        db.add_all(products)

        # Banners
        banners = [
            Banner(
                title_en="Summer Sale - Up to 50% Off",
                title_ar="تخفيضات الصيف - خصم يصل إلى 50%",
                image_url="https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800",
                sort_order=1,
            ),
            Banner(
                title_en="New Arrivals Collection",
                title_ar="مجموعة الوصول الجديدة",
                image_url="https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800",
                sort_order=2,
            ),
            Banner(
                title_en="Free Shipping on Orders Over 200 SAR",
                title_ar="شحن مجاني للطلبات فوق 200 ريال",
                image_url="https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800",
                sort_order=3,
            ),
        ]
        db.add_all(banners)

        # Coupons
        coupons = [
            Coupon(
                code="WELCOME10",
                description_en="10% off your first order",
                description_ar="خصم 10% على طلبك الأول",
                discount_type="percentage",
                discount_value=10.0,
                min_order_amount=50.0,
                max_discount=100.0,
                expires_at=datetime.now(timezone.utc) + timedelta(days=90),
            ),
            Coupon(
                code="SUMMER50",
                description_en="50 SAR off orders over 300 SAR",
                description_ar="خصم 50 ريال على الطلبات فوق 300 ريال",
                discount_type="fixed",
                discount_value=50.0,
                min_order_amount=300.0,
                expires_at=datetime.now(timezone.utc) + timedelta(days=30),
            ),
        ]
        db.add_all(coupons)

        await db.commit()
        print("✅ Demo data seeded successfully.")

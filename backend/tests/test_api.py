import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from fastapi.testclient import TestClient
import sys
import os

# Ensure backend directory is in path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Use file-based SQLite for tests to avoid memory connection pooling issues
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test_koon.db"

from app.main import app
from app.database import init_db, engine
from app.main import _seed_demo_data
import asyncio

client = TestClient(app)


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    # Remove existing test DB if any
    if os.path.exists("./test_koon.db"):
        try:
            os.remove("./test_koon.db")
        except:
            pass

    # Run database initialization and seeding
    loop = asyncio.get_event_loop()
    loop.run_until_complete(init_db())
    loop.run_until_complete(_seed_demo_data())

    yield

    # Teardown: close engine and remove test DB
    loop.run_until_complete(engine.dispose())
    if os.path.exists("./test_koon.db"):
        try:
            os.remove("./test_koon.db")
        except:
            pass


# ── Health Check ────────────────────────────────────────────────────────────

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "Koon Commerce API" in response.json()["message"]


# ── Auth Endpoints ──────────────────────────────────────────────────────────

def test_register():
    response = client.post("/api/v1/auth/register", json={
        "email": "test@koon.com",
        "password": "password123",
        "name": "Test User",
    })
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == "test@koon.com"
    assert data["user"]["name"] == "Test User"


def test_register_duplicate_email():
    # First registration
    client.post("/api/v1/auth/register", json={
        "email": "dup@koon.com",
        "password": "password123",
        "name": "Dup User",
    })
    # Second registration with same email
    response = client.post("/api/v1/auth/register", json={
        "email": "dup@koon.com",
        "password": "password123",
        "name": "Dup User 2",
    })
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"]


def test_register_short_password():
    response = client.post("/api/v1/auth/register", json={
        "email": "short@koon.com",
        "password": "123",
        "name": "Short Pass",
    })
    assert response.status_code == 400


def test_login():
    # Register first
    client.post("/api/v1/auth/register", json={
        "email": "login@koon.com",
        "password": "password123",
        "name": "Login User",
    })
    # Login
    response = client.post("/api/v1/auth/login", json={
        "email": "login@koon.com",
        "password": "password123",
    })
    assert response.status_code == 200
    assert "access_token" in response.json()


def test_login_invalid_credentials():
    response = client.post("/api/v1/auth/login", json={
        "email": "nonexistent@koon.com",
        "password": "wrong",
    })
    assert response.status_code == 401


def test_forgot_password():
    response = client.post("/api/v1/auth/forgot-password", json={
        "email": "any@koon.com",
    })
    assert response.status_code == 200


def test_refresh_token():
    # Register to get tokens
    reg = client.post("/api/v1/auth/register", json={
        "email": "refresh@koon.com",
        "password": "password123",
        "name": "Refresh User",
    })
    refresh_token = reg.json()["refresh_token"]

    response = client.post("/api/v1/auth/refresh", json={
        "refresh_token": refresh_token,
    })
    assert response.status_code == 200
    assert "access_token" in response.json()


# ── Protected Endpoints ─────────────────────────────────────────────────────

def _get_auth_header():
    """Helper: register and return auth header."""
    import uuid
    email = f"user-{uuid.uuid4().hex[:8]}@koon.com"
    reg = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "name": "Auth User",
    })
    data = reg.json()
    token = data["access_token"]
    debug_code = data.get("debug_code")
    # Verify the email immediately so protected tests pass
    if debug_code:
        client.post(
            "/api/v1/auth/verify-email",
            json={"code": debug_code},
            headers={"Authorization": f"Bearer {token}"}
        )
    return {"Authorization": f"Bearer {token}"}


def test_get_profile():
    headers = _get_auth_header()
    response = client.get("/api/v1/users/me", headers=headers)
    assert response.status_code == 200
    assert response.json()["name"] == "Auth User"


def test_update_profile():
    headers = _get_auth_header()
    response = client.put("/api/v1/users/me", headers=headers, json={
        "name": "Updated Name",
        "preferred_language": "ar",
    })
    assert response.status_code == 200
    assert response.json()["name"] == "Updated Name"
    assert response.json()["preferred_language"] == "ar"


def test_unauthorized_access():
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401


# ── Products ────────────────────────────────────────────────────────────────

def test_list_products():
    response = client.get("/api/v1/products")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_top_selling():
    response = client.get("/api/v1/products/top-selling")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_search_products():
    response = client.get("/api/v1/products/search?q=headphones")
    assert response.status_code == 200


def test_get_banners():
    response = client.get("/api/v1/products/banners")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


# ── Categories ──────────────────────────────────────────────────────────────

def test_list_categories():
    response = client.get("/api/v1/categories")
    assert response.status_code == 200
    categories = response.json()
    assert isinstance(categories, list)
    # Demo data should have seeded categories
    assert len(categories) > 0


# ── Cart ────────────────────────────────────────────────────────────────────

def test_cart_crud():
    headers = _get_auth_header()

    # Cart should be empty
    response = client.get("/api/v1/cart", headers=headers)
    assert response.status_code == 200
    assert len(response.json()) == 0

    # Add external item
    response = client.post("/api/v1/cart", headers=headers, json={
        "cart_type": "amazon",
        "title": "Test Product",
        "price": "SAR 100",
        "image_url": "https://example.com/img.jpg",
        "external_url": "https://amazon.sa/dp/123",
        "site_name": "Amazon SA",
    })
    assert response.status_code == 200
    item_id = response.json()["id"]

    # Verify cart has 1 item
    response = client.get("/api/v1/cart?cart_type=amazon", headers=headers)
    assert len(response.json()) == 1

    # Update quantity
    response = client.put(f"/api/v1/cart/{item_id}", headers=headers, json={"quantity": 3})
    assert response.status_code == 200
    assert response.json()["quantity"] == 3

    # Remove item
    response = client.delete(f"/api/v1/cart/{item_id}", headers=headers)
    assert response.status_code == 200

    # Verify empty
    response = client.get("/api/v1/cart", headers=headers)
    assert len(response.json()) == 0


def test_cart_deduplication():
    headers = _get_auth_header()

    # Add external item first time
    response = client.post("/api/v1/cart", headers=headers, json={
        "cart_type": "amazon",
        "title": "Dup Test Product",
        "price": "SAR 100",
        "image_url": "https://example.com/img.jpg",
        "external_url": "https://amazon.sa/dp/dup123",
        "site_name": "Amazon SA",
        "quantity": 1,
    })
    assert response.status_code == 200
    
    # Add exact same item second time
    response2 = client.post("/api/v1/cart", headers=headers, json={
        "cart_type": "amazon",
        "title": "Dup Test Product",
        "price": "SAR 100",
        "image_url": "https://example.com/img.jpg",
        "external_url": "https://amazon.sa/dp/dup123",
        "site_name": "Amazon SA",
        "quantity": 2,
    })
    assert response2.status_code == 200
    assert response2.json()["quantity"] == 3

    # Verify cart has only 1 item with quantity 3
    response_list = client.get("/api/v1/cart?cart_type=amazon", headers=headers)
    assert len(response_list.json()) == 1
    assert response_list.json()[0]["quantity"] == 3


# ── Orders ──────────────────────────────────────────────────────────────────

def test_create_order():
    headers = _get_auth_header()

    # Add item to cart first
    client.post("/api/v1/cart", headers=headers, json={
        "cart_type": "internal",
        "title": "Order Product",
        "price": "150",
        "site_name": "Internal",
    })

    # Create order
    response = client.post("/api/v1/orders", headers=headers, json={})
    assert response.status_code == 200
    order = response.json()
    assert order["status"] == "pending"
    assert len(order["items"]) == 1

    # List orders
    response = client.get("/api/v1/orders", headers=headers)
    assert response.status_code == 200
    assert len(response.json()) >= 1


def test_place_order_multipart():
    headers = _get_auth_header()

    # Add item to cart first
    client.post("/api/v1/cart", headers=headers, json={
        "cart_type": "internal",
        "title": "Multipart Product",
        "price": "200",
        "site_name": "Internal",
    })

    # Prepare multipart form fields
    data = {
        "address_id": "addr_123",
        "cart_type": "internal",
        "shipping_type": "home",
        "payment_method_id": "cod",
        "additional_note": "Please deliver quickly",
    }
    # Mocking a payment proof file upload
    files = {
        "payment_proof": ("proof.jpg", b"fake image bytes", "image/jpeg")
    }

    # Place order
    response = client.post(
        "/api/v1/orders/place",
        headers=headers,
        data=data,
        files=files,
    )
    assert response.status_code == 200
    order = response.json()
    assert "payment_method=cod" in order["notes"]
    assert "proof=" in order["notes"]
    assert len(order["items"]) == 1


# ── Coupons ─────────────────────────────────────────────────────────────────

def test_list_coupons():
    response = client.get("/api/v1/coupons")
    assert response.status_code == 200
    coupons = response.json()
    assert len(coupons) > 0


def test_validate_coupon():
    response = client.post("/api/v1/coupons/validate", json={
        "code": "WELCOME10",
        "order_total": 200.0,
    })
    assert response.status_code == 200
    assert response.json()["valid"] is True
    assert response.json()["discount"] > 0


def test_validate_invalid_coupon():
    response = client.post("/api/v1/coupons/validate", json={
        "code": "INVALIDCODE",
        "order_total": 100.0,
    })
    assert response.status_code == 404


# ── Scraper Config ──────────────────────────────────────────────────────────

def test_get_config_amazon():
    response = client.get("/api/v1/config?url=https://www.amazon.sa/dp/B08GL5DFV4")
    assert response.status_code == 200
    assert response.json()["name"] == "Amazon SA"


def test_get_config_aliexpress():
    response = client.get("/api/v1/config?url=https://www.aliexpress.com/item/123.html")
    assert response.status_code == 200
    assert response.json()["name"] == "AliExpress"


def test_get_config_alibaba():
    response = client.get("/api/v1/config?url=https://www.alibaba.com/product/123")
    assert response.status_code == 200
    assert response.json()["name"] == "Alibaba"


def test_get_config_shein():
    response = client.get("/api/v1/config?url=https://ar.shein.com/goods-p-12345.html")
    assert response.status_code == 200
    assert response.json()["name"] == "Shein"


def test_get_config_not_found():
    response = client.get("/api/v1/config?url=https://google.com")
    assert response.status_code == 404


# ── Sellers ─────────────────────────────────────────────────────────────────

def test_list_sellers():
    response = client.get("/api/v1/sellers")
    assert response.status_code == 200


def test_apply_as_seller():
    headers = _get_auth_header()
    response = client.post("/api/v1/sellers/apply", headers=headers, json={
        "store_name_en": "My Store",
        "store_name_ar": "متجري",
    })
    assert response.status_code == 200
    assert response.json()["store_name"] == "My Store"


# ── Addresses ───────────────────────────────────────────────────────────────

def test_address_crud():
    headers = _get_auth_header()

    # Add address
    response = client.post("/api/v1/addresses", headers=headers, json={
        "label": "Home",
        "full_name": "Test User",
        "phone": "+966500000000",
        "street": "123 Main St",
        "city": "Riyadh",
        "is_default": True,
    })
    assert response.status_code == 200
    addr_id = response.json()["id"]

    # List addresses
    response = client.get("/api/v1/addresses", headers=headers)
    assert len(response.json()) == 1

    # Delete
    response = client.delete(f"/api/v1/addresses/{addr_id}", headers=headers)
    assert response.status_code == 200


# ── Wishlist ────────────────────────────────────────────────────────────────

def test_wishlist_crud():
    headers = _get_auth_header()

    # Add to wishlist
    response = client.post("/api/v1/wishlist", headers=headers, json={
        "title": "Wish Product",
        "external_url": "https://example.com/product",
        "source": "amazon",
    })
    assert response.status_code == 200
    item_id = response.json()["id"]

    # List wishlist
    response = client.get("/api/v1/wishlist", headers=headers)
    assert len(response.json()) == 1

    # Remove
    response = client.delete(f"/api/v1/wishlist/{item_id}", headers=headers)
    assert response.status_code == 200

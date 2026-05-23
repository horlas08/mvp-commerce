import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
import sys
import os

# Ensure backend directory is in path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "MVP Commerce Scraper Backend API is running."}

def test_get_config_amazon():
    response = client.get("/api/config?url=https://www.amazon.sa/dp/B08GL5DFV4")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Amazon SA"
    assert "#add-to-cart-button" in data["hide_selectors"]
    assert data["title_selector"] == "#productTitle"

def test_get_config_shein():
    response = client.get("/api/config?url=https://ar.shein.com/goods-p-12345.html")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Shein"
    assert ".add-to-bag" in data["hide_selectors"]
    assert "h1.product-intro__head-name, .product-intro__head-name" in data["title_selector"]

def test_get_config_not_found():
    response = client.get("/api/config?url=https://google.com")
    assert response.status_code == 404

def test_cart_operations():
    # 1. Cart is initially empty
    response = client.get("/api/cart")
    assert response.status_code == 200
    assert len(response.json()) == 0

    # 2. Add an item to the cart
    payload = {
        "title": "Amazon Product",
        "price": "SR 199.00",
        "image_url": "https://images.amazon.com/test.jpg",
        "url": "https://amazon.sa/dp/123",
        "site": "Amazon SA"
    }
    response = client.post("/api/cart", json=payload)
    assert response.status_code == 200
    added_item = response.json()
    assert added_item["title"] == payload["title"]
    assert "id" in added_item

    # 3. Verify item is in the cart
    response = client.get("/api/cart")
    assert response.status_code == 200
    cart_items = response.json()
    assert len(cart_items) == 1
    assert cart_items[0]["id"] == added_item["id"]

    # 4. Remove item from the cart
    item_id = added_item["id"]
    response = client.delete(f"/api/cart/{item_id}")
    assert response.status_code == 200
    assert response.json() == {"message": "Item successfully removed from cart."}

    # 5. Verify cart is empty again
    response = client.get("/api/cart")
    assert len(response.json()) == 0

@patch("httpx.Client")
def test_scrape_endpoint_amazon(mock_client_class):
    # Setup mock response HTML
    mock_html = """
    <html>
        <body>
            <span id="productTitle">Awesome Bluetooth Headphones</span>
            <span class="a-price"><span class="a-offscreen">SAR 150.00</span></span>
            <img id="landingImage" src="https://images-na.ssl-images-amazon.com/images/I/71.jpg"/>
        </body>
    </html>
    """
    
    # Configure mock client
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.text = mock_html
    mock_client.get.return_value = mock_response
    mock_client_class.return_value.__enter__.return_value = mock_client

    response = client.post("/api/scrape?url=https://www.amazon.sa/dp/B08GL5DFV4")
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Awesome Bluetooth Headphones"
    assert data["price"] == "SAR 150.00"
    assert data["image_url"] == "https://images-na.ssl-images-amazon.com/images/I/71.jpg"
    assert data["site"] == "Amazon SA"

@patch("httpx.Client")
def test_scrape_endpoint_shein(mock_client_class):
    # Setup mock response HTML
    mock_html = """
    <html>
        <body>
            <h1 class="product-intro__head-name">Elegant Summer Dress</h1>
            <div class="product-intro__head-mainprice">SAR 89.00</div>
            <img class="product-intro__gallery-img" src="https://shein.com/dress.jpg"/>
        </body>
    </html>
    """
    
    # Configure mock client
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.text = mock_html
    mock_client.get.return_value = mock_response
    mock_client_class.return_value.__enter__.return_value = mock_client

    response = client.post("/api/scrape?url=https://ar.shein.com/goods-p-12345.html")
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Elegant Summer Dress"
    assert data["price"] == "SAR 89.00"
    assert data["image_url"] == "https://shein.com/dress.jpg"
    assert data["site"] == "Shein"

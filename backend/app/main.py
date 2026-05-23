import uuid
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
from bs4 import BeautifulSoup

from app.config import get_config_for_url, SITE_CONFIGS, ScraperConfig

app = FastAPI(title="MVP Commerce Scraper Backend")

# Enable CORS for mobile development integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory Cart Database for MVP
cart_db: List[Dict[str, Any]] = []

class ProductItemInput(BaseModel):
    title: str
    price: str
    image_url: str
    url: str
    site: str

class CartItem(BaseModel):
    id: str
    title: str
    price: str
    image_url: str
    url: str
    site: str

@app.get("/")
def read_root():
    return {"message": "MVP Commerce Scraper Backend API is running."}

@app.get("/api/config", response_model=Dict[str, Any])
def get_config(url: str = Query(..., description="The e-commerce site URL")):
    """
    Returns selectors to hide checkout buttons and extract details based on domain.
    """
    config = get_config_for_url(url)
    if not config:
        # Return a default configuration or raise error
        raise HTTPException(
            status_code=404,
            detail=f"Configuration for URL '{url}' not found. Supported domains are Amazon SA and Shein."
        )
    return config.model_dump()

@app.get("/api/configs")
def get_all_configs():
    """
    Returns all configuration patterns.
    """
    return {k: v.model_dump() for k, v in SITE_CONFIGS.items()}

@app.post("/api/cart", response_model=CartItem)
def add_to_cart(item: ProductItemInput):
    """
    Adds a product item to the user's cart.
    """
    cart_item = {
        "id": str(uuid.uuid4()),
        "title": item.title,
        "price": item.price,
        "image_url": item.image_url,
        "url": item.url,
        "site": item.site
    }
    cart_db.append(cart_item)
    return cart_item

@app.get("/api/cart", response_model=List[CartItem])
def get_cart():
    """
    Lists all items currently in the cart.
    """
    return cart_db

@app.delete("/api/cart/{item_id}")
def remove_from_cart(item_id: str):
    """
    Removes a product from the cart.
    """
    global cart_db
    initial_length = len(cart_db)
    cart_db = [item for item in cart_db if item["id"] != item_id]
    if len(cart_db) == initial_length:
        raise HTTPException(status_code=404, detail="Item not found in cart.")
    return {"message": "Item successfully removed from cart."}

@app.post("/api/scrape")
def scrape_product(url: str = Query(..., description="URL of the product detail page")):
    """
    Backend scraper endpoint (Option A) to parse product details from HTML.
    Sends a request, handles basic headers, and extracts details.
    """
    config = get_config_for_url(url)
    if not config:
        raise HTTPException(status_code=404, detail="No scraper configuration found for this website.")

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache"
    }

    try:
        # We use a client with redirection handling
        with httpx.Client(follow_redirects=True, headers=headers, timeout=10.0) as client:
            response = client.get(url)
            
            if response.status_code != 200:
                raise HTTPException(status_code=response.status_code, detail=f"Failed to fetch webpage. Site returned status code: {response.status_code}")
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract product title
            title_elem = soup.select_one(config.title_selector)
            title = title_elem.get_text(strip=True) if title_elem else "Unknown Title"
            
            # Extract price
            price = "Unknown Price"
            for price_selector in config.price_selectors:
                price_elem = soup.select_one(price_selector)
                if price_elem:
                    price = price_elem.get_text(strip=True)
                    break
            
            # Extract image
            image_url = ""
            for image_selector in config.image_selectors:
                img_elem = soup.select_one(image_selector)
                if img_elem:
                    # Check standard attributes
                    if img_elem.has_attr("src"):
                        image_url = img_elem["src"]
                    elif img_elem.has_attr("data-a-dynamic-image"):
                        # Amazon dynamic image parse (JSON object where keys are URLs)
                        import json
                        try:
                            dyn_img = json.loads(img_elem["data-a-dynamic-image"])
                            if dyn_img:
                                image_url = list(dyn_img.keys())[0]
                        except Exception:
                            pass
                    if image_url:
                        break
            
            return {
                "title": title,
                "price": price,
                "image_url": image_url,
                "url": url,
                "site": config.name
            }
            
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Request error while scraping: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to scrape webpage: {str(e)}")

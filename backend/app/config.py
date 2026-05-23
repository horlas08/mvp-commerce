from typing import Dict, List, Any
from pydantic import BaseModel

class ScraperConfig(BaseModel):
    name: str
    domain: str
    hide_selectors: List[str]
    title_selector: str
    price_selectors: List[str]
    image_selectors: List[str]

# Configuration mappings for supported websites
SITE_CONFIGS: Dict[str, ScraperConfig] = {
    "amazon": ScraperConfig(
        name="Amazon SA",
        domain="amazon.sa",
        hide_selectors=[
            "#add-to-cart-button",
            "#buy-now-button",
            "#add-to-cart-button-ubb",
            "#buy-now-button-ubb",
            "#commerce-gift-owner-button",
            "input[name='submit.add-to-cart']",
            "input[name='submit.buy-now']",
            "[name='submit.add-to-cart']",
            "[name='submit.buy-now']",
            "#fpp-buy-box-container",
            ".a-button-stack", # Hides the container buttons too
            "#atc-declarative",
            "#buyNow-declarative"
        ],
        title_selector="#productTitle",
        price_selectors=[
            ".a-price .a-offscreen",
            "#price_inside_buybox",
            "#priceblock_ourprice",
            ".a-color-price"
        ],
        image_selectors=[
            "#landingImage",
            "#imgBlkFront",
            "#main-image"
        ]
    ),
    "shein": ScraperConfig(
        name="Shein",
        domain="shein.com",
        hide_selectors=[
            ".product-intro__buy",
            ".add-to-bag",
            ".buy-now",
            ".she-btn-black",
            "button[class*='add-to-cart']",
            "button[class*='add-to-bag']",
            ".she-btn-xl",
            ".goods-detail-buy"
        ],
        title_selector="h1.product-intro__head-name, .product-intro__head-name",
        price_selectors=[
            ".product-intro__head-mainprice",
            ".product-intro__head-price .original",
            ".product-intro__head-price",
            ".goods-price-num"
        ],
        image_selectors=[
            ".product-intro__gallery-img",
            ".goods-detail-zoom-img",
            ".main-image img"
        ]
    )
}

def get_config_for_url(url: str) -> ScraperConfig | None:
    url_lower = url.lower()
    for key, config in SITE_CONFIGS.items():
        if config.domain in url_lower or key in url_lower:
            return config
    return None

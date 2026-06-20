from typing import Dict, List, Any, Optional
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
            # --- Buy box buttons ---
            "#add-to-cart-button",
            "#buy-now-button",
            "#add-to-cart-button-ubb",
            "#buy-now-button-ubb",
            "#commerce-gift-owner-button",
            "#atc-declarative",
            "#buyNow-declarative",
            "#fpp-buy-box-container",
            "#buybox",
            "#buybox-see-all-buying-choices",
            "#desktop-ptc-button-v2",
            "#ptc-button",
            "#submit\\.buy-now",
            "input[name='submit.add-to-cart']",
            "input[name='submit.buy-now']",
            "[name='submit.add-to-cart']",
            "[name='submit.buy-now']",
            ".a-button-stack",
            ".a-button[data-action='add-to-cart']",
            ".a-button[data-action='buying-now']",

            # --- Mobile buy bar ---
            "#mobile-buybox",
            "#mobile-buybox-main",
            "#a-sticky-popover-bottom",
            ".a-sticky-popover",
            "#sitbReaderFrame",
            "#cpmss-buy-box",
            "#buy-now-button-container",

            # --- Cart icon – all variants seen in desktop/mobile headers ---
            "#nav-cart",
            "#nav-cart-count-container",
            "#nav-cart-text-container",
            ".nav-cart-icon",
            ".nav-cart-count",
            ".nav-button-cart",
            "#nav-link-cart",
            "#nav-cart-count",
            "span.nav-cart-icon",
            "#aw-sm-bottom-nav-cart",
            # Mobile tab-bar cart
            "#aw-bottom-nav",
            ".aw-bottom-nav",

            # --- Sign-in / account links ---
            "#nav-link-accountList",
            "#nav-logobar-greeting",
            "#nav-signin-tooltip",
            "#nav-link-accountList-nav-line-1",
            "#nav-link-accountList-nav-line-2",
            ".nav-bb-signin",

            # --- Catch-all href patterns (covers desktop & mobile) ---
            "a[href*='/cart']",
            "a[href*='signin']",
            "a[href*='register']",
            "a[href*='ap/signin']",
            "a[href*='gp/cart']",
            "a[href*='gp/signin']",
        ],
        title_selector="#productTitle, #title, span#title, #title-section h1",
        price_selectors=[
            ".a-price .a-offscreen",
            "#corePrice_feature_div .a-price",
            "#corePriceDisplay_desktop_feature_div .a-price",
            "#price_inside_buybox",
            "#priceblock_ourprice",
            ".a-color-price",
            ".a-price-whole"
        ],
        image_selectors=[
            "#main-image",
            "#landingImage",
            "#imgBlkFront",
            "img.a-dynamic-image",
            "#main-image-container img"
        ]
    ),
    "shein": ScraperConfig(
        name="Shein",
        domain="shein.com",
        hide_selectors=[
            ".product-intro__buy",
            ".product-intro__action",
            ".product-intro__add-bag",
            ".add-to-bag",
            ".buy-now",
            ".she-btn-black",
            ".she-btn-xl",
            ".goods-detail-buy",
            ".j-goods-detail-bottom",
            ".goods-detail-bottom",
            ".product-bottom-bar",
            ".mshe-btn-pay",
            ".mshe-btn-bag",
            "button[class*='add-to-cart']",
            "button[class*='add-to-bag']",
            "button[class*='buy-now']",
            "[class*='AddToBag']",
            "[class*='BuyNow']",
            ".j-header-cart",
            ".head-cart",
            ".header-right-cart",
            ".c-header-nav-cart",
            ".sui-icon-nav-cart",
            ".c-icon-nav-cart",
            ".icon-cart",
            ".she-header__icon--cart",
            ".header__icon--bag",
            ".j-cart-icon",
            ".cart-icon",
            ".bag-icon",
            ".header-bag",
            "span[class*='cart']",
            "span[class*='bag']",
            "i[class*='cart']",
            "i[class*='bag']",
            ".c-header-nav-user",
            ".j-header-user",
            ".header-right-user",
            ".she-header__icon--user",
            ".login-box",
            ".header-user",
            "a[href*='/cart']",
            "a[href*='/bag']",
            "a[href*='login']",
            "a[href*='register']",
            "a[href*='signup']",
        ],
        title_selector="h1.goods-title-name, .goods-title-name, h1.product-intro__head-name, .product-intro__head-name, h1, .product-title",
        price_selectors=[
            ".goods-price-num",
            ".product-intro__head-mainprice",
            ".discount-price",
            ".sale-price",
            ".product-price",
            ".price-discount",
            ".product-intro__head-price .original",
            ".product-intro__head-price"
        ],
        image_selectors=[
            ".goods-detail-zoom-img",
            ".product-intro__gallery-img",
            ".main-image img",
            ".crop-image-container img",
            ".swiper-slide-active img",
            ".goods-detail-image img"
        ]
    ),
    "aliexpress": ScraperConfig(
        name="AliExpress",
        domain="aliexpress.com",
        hide_selectors=[
            ".add-to-cart-button",
            ".buy-now-button",
            "#product-action",
            ".product-action",
            "[class*='addToCart']",
            "[class*='buyNow']",
            "[class*='AddToCart']",
            "[class*='BuyNow']",
            "button[class*='cart']",
            "button[class*='buy']",
            ".cart-icon",
            ".header-cart",
            "[class*='header-cart']",
            "a[href*='/cart']",
            "a[href*='login']",
            "a[href*='register']",
        ],
        title_selector="h1[data-pl='product-title'], h1.product-title-text, .product-title-text, h1",
        price_selectors=[
            ".product-price-current",
            ".uniform-banner-box-price",
            "[class*='product-price']",
            ".es--wrap--erdmPRe .notranslate",
        ],
        image_selectors=[
            ".magnifier-image",
            ".pdp-comp-img img",
            ".slider--img--D7MJNPZ img",
            "img[class*='product-img']",
        ]
    ),
    "alibaba": ScraperConfig(
        name="Alibaba",
        domain="alibaba.com",
        hide_selectors=[
            # --- Buy / order / contact buttons ---
            ".order-now-btn",
            ".contact-supplier-btn",
            "#J-add-to-cart",
            ".atc-btn",
            "button[class*='cart']",
            "button[class*='order']",
            "button[class*='Order']",
            "button[class*='Cart']",
            "[class*='addToCart']",
            "[class*='AddToCart']",
            "[class*='OrderNow']",
            "[class*='order-now']",
            "[class*='ContactSupplier']",
            "[class*='contact-supplier']",
            "[class*='startOrder']",
            "[class*='start-order']",
            "[class*='ChatNow']",
            "[class*='chat-now']",
            "[data-spm*='cart']",
            "[data-spm*='order']",
            # --- Header cart / sign-in / register ---
            "[class*='headerCart']",
            "[class*='header-cart']",
            "[class*='HeaderCart']",
            "[class*='nav-cart']",
            "[class*='MyAlibaba']",
            "[class*='signIn']",
            "[class*='sign-in']",
            "[class*='SignIn']",
            "[class*='register']",
            "[class*='Register']",
            "a[href*='/cart']",
            "a[href*='login']",
            "a[href*='signin']",
            "a[href*='register']",
            "a[href*='join']",
            "a[href*='member.alibaba.com']",
            # --- Arabic Alibaba (arabic.alibaba.com) specific ---
            "[class*='ar-cart']",
            "[class*='ar-header-cart']",
            "[class*='arHeader']",
            "[class*='arNav']",
            "[class*='ar-signin']",
            "[class*='ar-register']",
        ],
        title_selector=".module-pdp-title h1, .title-text, h1.product-title, [class*='product-title'] h1, h1",
        price_selectors=[
            ".module-pdp-price .price",
            ".price-origin",
            ".ladder-price-item",
            "[class*='pdp-price']",
            "[class*='Price'] [class*='current']",
            "[class*='price-value']",
        ],
        image_selectors=[
            ".main-image img",
            ".detail-gallery-turn img",
            ".pdp-gallery img",
            ".magic-image img",
            "[class*='main-image'] img",
            "[class*='gallery'] img",
        ]
    ),
}

def get_config_for_url(url: str) -> Optional[ScraperConfig]:
    url_lower = url.lower()
    for key, config in SITE_CONFIGS.items():
        if config.domain in url_lower or key in url_lower:
            return config
    return None

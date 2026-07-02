# Koon Cart Auto-Update Design Document

This document outlines the proposed client-side design for automatically updating prices, variant options, and stock statuses for external items (AliExpress, SHEIN, Alibaba, iHerb, Amazon) saved in the user's cart.

## Overview

Since external products are rendered dynamically (often requiring JavaScript execution, browser-specific cookies, and session headers to display the correct price/variant), we cannot easily crawl them from the backend. Instead, we will use a **Client-Side Headless WebView** approach on the mobile device.

---

## Technical Approach: Client-Side WebView refresh

When the user navigates to the **Cart Screen**:
1. Fetch all items in the cart from the backend (`GET /api/v1/cart`).
2. Identify items belonging to external stores (`amazon`, `aliexpress`, `shein`, `alibaba`, `iherb`).
3. For each external item, instantiate a hidden/headless `InAppWebView`:
   - Set the cookies for the respective domain (enforcing language/currency, e.g., `b_locale=ar_SA` and `c_tp=SAR` for AliExpress).
   - Load the product's `external_url` (which contains variant identifiers).
   - Inject the established scraper script (`extractProduct()`) to parse the current details.
4. Compare the newly scraped price/details with the ones stored in the cart:
   - If the price has changed, trigger a PUT request to the backend `PUT /api/v1/cart/{itemId}` with the updated price.
   - If the item is out of stock or no longer exists, flag it in the UI and database.
5. Refresh the local cart state to update the UI.

---

## API Endpoints Utilized

- **Fetch Cart**: `GET /api/v1/cart`
- **Update Item**: `PUT /api/v1/cart/{itemId}` (sends `{ "price": "SAR <new_price>" }`)

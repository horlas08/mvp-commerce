import httpx
from bs4 import BeautifulSoup
import json

headers = {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
    "Accept-Language": "en-US,en;q=0.9",
}

urls = [
    "https://www.amazon.sa/-/en/Sony-WH-1000XM4-Wireless-Cancelling-Over-Ear/dp/B08EC2D11V",
    "https://ar.shein.com/goods-p-32456488.html"
]

for url in urls:
    print(f"\n--- Fetching {url} ---")
    try:
        r = httpx.get(url, headers=headers, timeout=15.0, follow_redirects=True)
        soup = BeautifulSoup(r.text, 'html.parser')
        
        # Look for Title
        title = soup.find('h1')
        print(f"H1 Title: {title.text.strip() if title else 'None'} | id: {title.get('id') if title else ''} | class: {title.get('class') if title else ''}")
        
        # Print first few elements that might be price
        prices = soup.select('.a-price, .price, [class*=\"price\"], [id*=\"price\"]')
        print("Possible prices:")
        for p in prices[:5]:
            print(f" - {p.text.strip()} | id: {p.get('id')} | class: {p.get('class')}")
            
        # Print elements that might be images
        images = soup.select('img[id*=\"img\"], img[id*=\"image\"], img[class*=\"img\"], img[class*=\"image\"]')
        print("Possible images:")
        for img in images[:5]:
            print(f" - src: {img.get('src')} | id: {img.get('id')} | class: {img.get('class')} | data-a-dynamic-image: {img.get('data-a-dynamic-image')[:20] if img.get('data-a-dynamic-image') else 'None'}")
            
        # Print buttons that might be buy/cart
        buy_btns = soup.select('button, input[type=\"submit\"], input[type=\"button\"], a[id*=\"buy\"], a[class*=\"buy\"], a[id*=\"cart\"], a[class*=\"cart\"]')
        print("Possible Buy/Cart elements:")
        for btn in buy_btns[:10]:
            print(f" - text: {btn.text.strip()[:20] if btn.text else ''} | tag: {btn.name} | id: {btn.get('id')} | class: {btn.get('class')} | name: {btn.get('name')}")
            
    except Exception as e:
        print(f"Error: {e}")


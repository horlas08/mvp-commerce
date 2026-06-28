import os
import httpx

base_static = os.path.join(os.path.dirname(__file__), "app", "static", "seed")
dest_path = os.path.join(base_static, "products", "vacuum.jpg")

url = "https://images.unsplash.com/photo-1527515637462-cff94eecc1ac?w=400"
print(f"Downloading {url} -> {dest_path}")
client = httpx.Client(timeout=30.0)
try:
    response = client.get(url)
    if response.status_code == 200:
        with open(dest_path, "wb") as f:
            f.write(response.content)
        print("  Done.")
    else:
        print(f"  Failed with status: {response.status_code}")
except Exception as e:
    print(f"  Error: {e}")

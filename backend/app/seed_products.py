import asyncio
from sqlalchemy import select, delete
from app.database import async_session
from app.models.product import Product

SAMPLE_ABAYA_HTML_AR = """
<h3 style="color:#111; font-size:18px; margin-bottom:12px;">عباءة أسود فاخرة</h3>

<p style="margin-bottom:8px;">
  <span style="color:#e91e63; font-weight:bold; font-size:14px;">ميزة النسيج :</span>
  مصنوع من قماش بتك فاخر من الدرجة الأولى. ناعم، انسيابي، وبارد ومناسب لجميع فصول السنة.
</p>

<p style="margin-bottom:8px;">
  <span style="color:#e91e63; font-weight:bold; font-size:14px;">ميزة المنتج :</span>
  تصميم عصري أنيق ومزود بسحاب أمامي مخفي وعملي. الجيوب جانبية مدمجة بحرفية عالية مع حزام داخلي اختياري لضبط المقاس.
</p>

<p style="margin-bottom:8px;">
  <span style="color:#e91e63; font-weight:bold; font-size:14px;">تعليمات الغسيل :</span>
  يغسل بماء بارد عند درجة حرارة لا تتعدى 30 مئوية (غسيل خفيف) دون استخدام مبيضات.
</p>

<p style="margin-bottom:14px;">
  <span style="color:#e91e63; font-weight:bold; font-size:14px;">ملاحظة الموديل :</span>
  الموديل ترتدي مقاس (38-40) وطول 138 سم.
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333;">جدول مقاسات العباءة (سم)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px;">الحجم</th>
      <th style="border:1px solid #ddd; padding:8px;">الصدر</th>
      <th style="border:1px solid #ddd; padding:8px;">الطول</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">S (38-40)</td>
      <td style="border:1px solid #ddd; padding:8px;">100</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">M (42-44)</td>
      <td style="border:1px solid #ddd; padding:8px;">108</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">L (46-48)</td>
      <td style="border:1px solid #ddd; padding:8px;">120</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">XL (50-52)</td>
      <td style="border:1px solid #ddd; padding:8px;">128</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
  </tbody>
</table>
"""

SAMPLE_ABAYA_HTML_EN = """
<h3 style="color:#111; font-size:18px; margin-bottom:12px;">Premium Black Abaya</h3>

<p style="margin-bottom:8px;">
  <span style="color:#e91e63; font-weight:bold; font-size:14px;">Fabric Quality :</span>
  Crafted from first-grade premium crepe fabric. Breathable, fluid, and suitable for all four seasons.
</p>

<p style="margin-bottom:8px;">
  <span style="color:#e91e63; font-weight:bold; font-size:14px;">Product Feature :</span>
  Modern silhouette with concealed front zipper closure and integrated side pockets. Includes an optional inner tie belt.
</p>

<p style="margin-bottom:8px;">
  <span style="color:#e91e63; font-weight:bold; font-size:14px;">Care Instructions :</span>
  Machine wash cold at 30°C delicate cycle. Do not bleach.
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333;">Abaya Size Chart (cm)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px;">Size</th>
      <th style="border:1px solid #ddd; padding:8px;">Chest</th>
      <th style="border:1px solid #ddd; padding:8px;">Length</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">S (38-40)</td>
      <td style="border:1px solid #ddd; padding:8px;">100 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">138 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">M (42-44)</td>
      <td style="border:1px solid #ddd; padding:8px;">108 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">138 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">L (46-48)</td>
      <td style="border:1px solid #ddd; padding:8px;">120 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">138 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">XL (50-52)</td>
      <td style="border:1px solid #ddd; padding:8px;">128 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">138 cm</td>
    </tr>
  </tbody>
</table>
"""

SAMPLE_DRESS_HTML_AR = """
<h3 style="color:#111; font-size:18px; margin-bottom:12px;">فستان حريري مطرز</h3>

<p style="margin-bottom:8px;">
  <span style="color:#ff6b00; font-weight:bold; font-size:14px;">خامة ممتازة :</span>
  حرير كريب طبيعي فائق النعومة، خفيف ومريح على البشرة.
</p>

<p style="margin-bottom:8px;">
  <span style="color:#ff6b00; font-weight:bold; font-size:14px;">المناسبة :</span>
  مثالي للحفلات، الأعياد، والزيارات الرسمية مع لمسات تطريز يدوية أنيقة.
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333;">جدول مقاسات الفستان (سم)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px;">المقاس</th>
      <th style="border:1px solid #ddd; padding:8px;">الصدر</th>
      <th style="border:1px solid #ddd; padding:8px;">الخصر</th>
      <th style="border:1px solid #ddd; padding:8px;">الطول</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">S</td>
      <td style="border:1px solid #ddd; padding:8px;">92</td>
      <td style="border:1px solid #ddd; padding:8px;">72</td>
      <td style="border:1px solid #ddd; padding:8px;">135</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">M</td>
      <td style="border:1px solid #ddd; padding:8px;">98</td>
      <td style="border:1px solid #ddd; padding:8px;">78</td>
      <td style="border:1px solid #ddd; padding:8px;">136</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">L</td>
      <td style="border:1px solid #ddd; padding:8px;">104</td>
      <td style="border:1px solid #ddd; padding:8px;">84</td>
      <td style="border:1px solid #ddd; padding:8px;">137</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">XL</td>
      <td style="border:1px solid #ddd; padding:8px;">112</td>
      <td style="border:1px solid #ddd; padding:8px;">92</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
  </tbody>
</table>
"""

SAMPLE_DRESS_HTML_EN = """
<h3 style="color:#111; font-size:18px; margin-bottom:12px;">Embroidered Silk Dress</h3>

<p style="margin-bottom:8px;">
  <span style="color:#ff6b00; font-weight:bold; font-size:14px;">Material :</span>
  Ultra-soft natural silk crepe, lightweight and breathable.
</p>

<p style="margin-bottom:8px;">
  <span style="color:#ff6b00; font-weight:bold; font-size:14px;">Occasion :</span>
  Ideal for gatherings, holidays, and evening events with delicate handcrafted embroidery.
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333;">Size Guide (cm)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px;">Size</th>
      <th style="border:1px solid #ddd; padding:8px;">Bust</th>
      <th style="border:1px solid #ddd; padding:8px;">Waist</th>
      <th style="border:1px solid #ddd; padding:8px;">Length</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">S</td>
      <td style="border:1px solid #ddd; padding:8px;">92 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">72 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">135 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">M</td>
      <td style="border:1px solid #ddd; padding:8px;">98 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">78 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">136 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">L</td>
      <td style="border:1px solid #ddd; padding:8px;">104 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">84 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">137 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">XL</td>
      <td style="border:1px solid #ddd; padding:8px;">112 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">92 cm</td>
      <td style="border:1px solid #ddd; padding:8px;">138 cm</td>
    </tr>
  </tbody>
</table>
"""

async def run_seed():
    async with async_session() as db:
        # Check existing products
        res = await db.execute(select(Product))
        products = res.scalars().all()

        fashion_products = [p for p in products if p.category_id == 'cat-fashion']
        
        # 1. First Showcase Product: Abaya with Color Swatches & Sizes & Table
        abaya = next((p for p in products if 'abaya' in p.title_en.lower() or 'dress' in p.title_en.lower()), None)
        if abaya:
            abaya.title_ar = "عباءة أسود فاخرة بتطريز ناعم"
            abaya.title_en = "Luxury Black Abaya with Delicate Embroidery"
            abaya.description_ar = SAMPLE_ABAYA_HTML_AR
            abaya.description_en = SAMPLE_ABAYA_HTML_EN
            abaya.price = 280.0
            abaya.discount_price = 240.0
            abaya.category_id = "cat-fashion"
            abaya.stock = 45
            abaya.rating = 4.9
            abaya.rating_count = 142
            abaya.variants = [
                {
                    "type": "اللون",
                    "name": "اللون",
                    "options": [
                        {"name": "بني", "color_hex": "#795548", "stock": 15, "price_override": 240.0},
                        {"name": "رمادي", "color_hex": "#616161", "stock": 20, "price_override": 240.0},
                        {"name": "أسود", "color_hex": "#212121", "stock": 10, "price_override": 260.0},
                    ]
                },
                {
                    "type": "المقاس",
                    "name": "المقاس",
                    "options": [
                        {"name": "S", "stock": 10, "price_override": 240.0},
                        {"name": "M", "stock": 15, "price_override": 240.0},
                        {"name": "L", "stock": 12, "price_override": 240.0},
                        {"name": "XL", "stock": 8, "price_override": 255.0},
                    ]
                }
            ]

        # 2. Second Showcase Product: Dress with Colors, Sizes & Table
        sneakers = next((p for p in products if 'sneakers' in p.title_en.lower() or 'shoe' in p.title_en.lower()), None)
        if sneakers:
            sneakers.title_ar = "فستان حريري مطرز راقي"
            sneakers.title_en = "Elegant Embroidered Silk Dress"
            sneakers.description_ar = SAMPLE_DRESS_HTML_AR
            sneakers.description_en = SAMPLE_DRESS_HTML_EN
            sneakers.price = 320.0
            sneakers.discount_price = 275.0
            sneakers.category_id = "cat-fashion"
            sneakers.images = ["/static/seed/products/dress.jpg"]
            sneakers.stock = 30
            sneakers.rating = 4.8
            sneakers.rating_count = 95
            sneakers.variants = [
                {
                    "type": "اللون",
                    "name": "اللون",
                    "options": [
                        {"name": "أزرق كحلي", "color_hex": "#1A237E", "stock": 10, "price_override": 275.0},
                        {"name": "وردي ناعم", "color_hex": "#E91E63", "stock": 12, "price_override": 275.0},
                        {"name": "بيج", "color_hex": "#D7CCC8", "stock": 8, "price_override": 290.0},
                    ]
                },
                {
                    "type": "المقاس",
                    "name": "المقاس",
                    "options": [
                        {"name": "S", "stock": 8, "price_override": 275.0},
                        {"name": "M", "stock": 10, "price_override": 275.0},
                        {"name": "L", "stock": 7, "price_override": 275.0},
                        {"name": "XL", "stock": 5, "price_override": 290.0},
                    ]
                }
            ]

        # 3. Third Product (Smart Watch) in Electronics
        watch = next((p for p in products if 'smart watch' in p.title_en.lower()), None)
        if watch:
            watch.variants = [
                {
                    "type": "اللون",
                    "name": "اللون",
                    "options": [
                        {"name": "فضي", "color_hex": "#E0E0E0", "stock": 15, "price_override": 499.0},
                        {"name": "أسود كربوني", "color_hex": "#212121", "stock": 10, "price_override": 520.0},
                        {"name": "ذهبي وردي", "color_hex": "#F48FB1", "stock": 5, "price_override": 540.0},
                    ]
                },
                {
                    "type": "حجم الهيكل",
                    "name": "حجم الهيكل",
                    "options": [
                        {"name": "40 mm", "stock": 12, "price_override": 499.0},
                        {"name": "44 mm", "stock": 18, "price_override": 549.0},
                    ]
                }
            ]

        # 4. Fourth Product (Headphones) in Electronics
        headphones = next((p for p in products if 'headphones' in p.title_en.lower()), None)
        if headphones:
            headphones.variants = [
                {
                    "type": "اللون",
                    "name": "اللون",
                    "options": [
                        {"name": "أسود مطفي", "color_hex": "#212121", "stock": 25, "price_override": 249.0},
                        {"name": "أبيض لؤلؤي", "color_hex": "#FAFAFA", "stock": 15, "price_override": 249.0},
                        {"name": "أزرق سماوي", "color_hex": "#0288D1", "stock": 10, "price_override": 269.0},
                    ]
                }
            ]

        await db.commit()
        print("✅ Showcase products with rich HTML tables, color swatches, sizes, and similar items seeded successfully!")

if __name__ == "__main__":
    asyncio.run(run_seed())

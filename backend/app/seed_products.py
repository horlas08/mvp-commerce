import asyncio
from sqlalchemy import select
from app.database import async_session
from app.models.product import Product

SAMPLE_ABAYA_HTML_AR = """
<h3 style="color:#111; font-size:18px; font-weight:bold; margin-bottom:12px; text-align:right;">عباءة أسود</h3>

<p style="margin-bottom:8px; line-height:1.6; text-align:right;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">ميزة النسيج : </span>
  <span>مصنوع من قماش بتك من الدرجة الأولى. الفصول الأربعة الموسم يمكن استخدامه.</span>
</p>

<p style="margin-bottom:8px; line-height:1.6; text-align:right;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">ميزة المنتج : </span>
  <span>إنه منتج أزياء حجاب للموسم الجديد. المنتج لديه ياقة دائرية .غير مبطنة. مزود بسحاب أمامي الدبوس غير شامل في المنتج. الجيب متاح. السوار مطاطي. الحزام متضمن، يمكن استخدامها حسب الرغبة قد يكون هناك اختلاف في الدرجة اللونية في المنتج بسبب التقاط الصور الفوتوغرافية.</span>
</p>

<p style="margin-bottom:8px; line-height:1.6; text-align:right;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">الغسيل : </span>
  <span>يمكن غسلها عند 30 درجة دون كتابة. (غسيل دقيق)</span>
</p>

<p style="margin-bottom:8px; line-height:1.6; text-align:right;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">ميزة الحزام : </span>
  <span>لمنع الحزام من التموج، يتم خياطة الطرفين ويترك الوسط فارغاً (غير مخيط).</span>
</p>

<p style="margin-bottom:12px; font-weight:bold; color:#d81b60; text-align:right;">
  (المنتج على الموديل مقاس 38-40).
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333; text-align:right;">عباءة مقاسات الحجم (سم)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">الحجم</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">الصدر</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">الطول</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">38-40</td>
      <td style="border:1px solid #ddd; padding:8px;">100</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">42-44</td>
      <td style="border:1px solid #ddd; padding:8px;">108</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">46-48</td>
      <td style="border:1px solid #ddd; padding:8px;">120</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">50-52</td>
      <td style="border:1px solid #ddd; padding:8px;">128</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
  </tbody>
</table>
"""

SAMPLE_ABAYA_HTML_EN = """
<h3 style="color:#111; font-size:18px; font-weight:bold; margin-bottom:12px;">Black Abaya</h3>

<p style="margin-bottom:8px; line-height:1.6;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">Fabric Quality : </span>
  <span>Crafted from first-grade premium fabric. Breathable and suitable for all four seasons.</span>
</p>

<p style="margin-bottom:8px; line-height:1.6;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">Product Feature : </span>
  <span>New season hijab fashion styling. Round neck, unlined with concealed front zipper and integrated side pockets. Elasticated cuffs and matching belt included.</span>
</p>

<p style="margin-bottom:8px; line-height:1.6;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">Care Instructions : </span>
  <span>Machine wash cold at 30°C delicate cycle without bleach.</span>
</p>

<p style="margin-bottom:8px; line-height:1.6;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">Belt Feature : </span>
  <span>To prevent buckling, ends are stitched leaving center free.</span>
</p>

<p style="margin-bottom:12px; font-weight:bold; color:#d81b60;">
  (Model is wearing size 38-40).
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333;">Abaya Size Chart (cm)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">Size</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">Chest</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">Length</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">38-40</td>
      <td style="border:1px solid #ddd; padding:8px;">100</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">42-44</td>
      <td style="border:1px solid #ddd; padding:8px;">108</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">46-48</td>
      <td style="border:1px solid #ddd; padding:8px;">120</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; font-weight:600;">50-52</td>
      <td style="border:1px solid #ddd; padding:8px;">128</td>
      <td style="border:1px solid #ddd; padding:8px;">138</td>
    </tr>
  </tbody>
</table>
"""

SAMPLE_DRESS_HTML_AR = """
<h3 style="color:#111; font-size:18px; margin-bottom:12px; font-weight:bold; text-align:right;">فستان سهرة راقي</h3>

<p style="margin-bottom:8px; text-align:right;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">خامة ممتازة : </span>
  <span>حرير كريب طبيعي فائق النعومة، خفيف ومريح على البشرة.</span>
</p>

<p style="margin-bottom:8px; text-align:right;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">المناسبة : </span>
  <span>مثالي للحفلات، الأعياد، والزيارات الرسمية مع لمسات تطريز يدوية أنيقة.</span>
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333; text-align:right;">جدول مقاسات الفستان (سم)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">المقاس</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">الصدر</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">الخصر</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">الطول</th>
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
<h3 style="color:#111; font-size:18px; margin-bottom:12px; font-weight:bold;">Elegant Evening Dress</h3>

<p style="margin-bottom:8px;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">Material : </span>
  <span>Ultra-soft natural silk crepe, lightweight and breathable.</span>
</p>

<p style="margin-bottom:8px;">
  <span style="color:#d81b60; font-weight:bold; font-size:14px;">Occasion : </span>
  <span>Ideal for gatherings, holidays, and evening events with delicate handcrafted embroidery.</span>
</p>

<h4 style="margin-top:16px; margin-bottom:8px; font-weight:bold; color:#333;">Size Guide (cm)</h4>
<table style="width:100%; border-collapse:collapse; margin:10px 0; font-size:13px; text-align:center;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">Size</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">Bust</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">Waist</th>
      <th style="border:1px solid #ddd; padding:8px; font-weight:bold;">Length</th>
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
        res = await db.execute(select(Product))
        products = res.scalars().all()

        for p in products:
            t_en = (p.title_en or '').lower()
            t_ar = (p.title_ar or '')

            # 1. Showcase Abaya (EXACT match to user Image 1 & Image 2)
            if 'abaya' in t_en or 'عباءة' in t_ar:
                p.title_ar = "عباءة أسود"
                p.title_en = "Black Abaya"
                p.description_ar = SAMPLE_ABAYA_HTML_AR
                p.description_en = SAMPLE_ABAYA_HTML_EN
                p.price = 280.0
                p.discount_price = 240.0
                p.category_id = "cat-fashion"
                p.stock = 45
                p.rating = 4.9
                p.rating_count = 142
                p.variants = [
                    {
                        "type": "اللون",
                        "name": "اللون",
                        "options": [
                            {"name": "بني", "color_hex": "#795548", "stock": 15, "price_override": 240.0},
                            {"name": "رمادي", "color_hex": "#616161", "stock": 20, "price_override": 240.0},
                        ]
                    },
                    {
                        "type": "المقاس",
                        "name": "المقاس",
                        "options": [
                            {"name": "XL", "stock": 8, "price_override": 255.0},
                            {"name": "L", "stock": 12, "price_override": 240.0},
                            {"name": "M", "stock": 15, "price_override": 240.0},
                            {"name": "S", "stock": 10, "price_override": 240.0},
                        ]
                    }
                ]

            # 2. Evening / Silk Dresses
            elif 'dress' in t_en or 'فستان' in t_ar or '5770edf311' in t_en.lower():
                p.title_ar = "فستان سهرة راقي"
                p.title_en = "Elegant Evening Dress"
                p.description_ar = SAMPLE_DRESS_HTML_AR
                p.description_en = SAMPLE_DRESS_HTML_EN
                p.category_id = "cat-fashion"
                p.price = 320.0
                p.discount_price = 275.0
                p.stock = 35
                p.rating = 4.8
                p.rating_count = 89
                p.variants = [
                    {
                        "type": "اللون",
                        "name": "اللون",
                        "options": [
                            {"name": "أزرق كحلي", "color_hex": "#1A237E", "stock": 10, "price_override": 275.0},
                            {"name": "وردي ناعم", "color_hex": "#E91E63", "stock": 15, "price_override": 275.0},
                            {"name": "بيج", "color_hex": "#D7CCC8", "stock": 10, "price_override": 290.0},
                        ]
                    },
                    {
                        "type": "المقاس",
                        "name": "المقاس",
                        "options": [
                            {"name": "XL", "stock": 6, "price_override": 290.0},
                            {"name": "L", "stock": 10, "price_override": 275.0},
                            {"name": "M", "stock": 12, "price_override": 275.0},
                            {"name": "S", "stock": 7, "price_override": 275.0},
                        ]
                    }
                ]

            # 3. Kids Formal Suit
            elif 'kids' in t_en or 'ولادي' in t_ar or 'suit' in t_en:
                p.category_id = "cat-fashion"
                p.variants = [
                    {
                        "type": "اللون",
                        "name": "اللون",
                        "options": [
                            {"name": "كحلي", "color_hex": "#1A237E", "stock": 10, "price_override": 315.0},
                            {"name": "رمادي", "color_hex": "#757575", "stock": 12, "price_override": 315.0},
                            {"name": "أسود", "color_hex": "#212121", "stock": 8, "price_override": 330.0},
                        ]
                    },
                    {
                        "type": "المقاس",
                        "name": "المقاس",
                        "options": [
                            {"name": "4-5 سنوات", "stock": 5, "price_override": 315.0},
                            {"name": "6-7 سنوات", "stock": 10, "price_override": 315.0},
                            {"name": "8-9 سنوات", "stock": 8, "price_override": 325.0},
                            {"name": "10-12 سنة", "stock": 7, "price_override": 330.0},
                        ]
                    }
                ]

            # 4. Smart Watch
            elif 'watch' in t_en or 'ساعة' in t_ar:
                p.category_id = "cat-electronics"
                p.variants = [
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
                        "type": "المقاس",
                        "name": "المقاس",
                        "options": [
                            {"name": "40 mm", "stock": 12, "price_override": 499.0},
                            {"name": "44 mm", "stock": 18, "price_override": 549.0},
                        ]
                    }
                ]

            # 5. Headphones
            elif 'headphones' in t_en or 'سماعات' in t_ar:
                p.category_id = "cat-electronics"
                p.variants = [
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

            # 6. Perfumes
            elif 'perfume' in t_en or 'عطر' in t_ar or 'oud' in t_en or 'عود' in t_ar:
                p.category_id = "cat-beauty"
                p.variants = [
                    {
                        "type": "الحجم",
                        "name": "الحجم",
                        "options": [
                            {"name": "50 ml", "stock": 20, "price_override": 180.0},
                            {"name": "80 ml", "stock": 15, "price_override": 240.0},
                            {"name": "100 ml", "stock": 10, "price_override": 290.0},
                        ]
                    }
                ]

            # 7. Yoga Mat
            elif 'yoga' in t_en or 'سجادة' in t_ar:
                p.variants = [
                    {
                        "type": "اللون",
                        "name": "اللون",
                        "options": [
                            {"name": "أرجواني", "color_hex": "#9C27B0", "stock": 12, "price_override": 89.0},
                            {"name": "وردي", "color_hex": "#E91E63", "stock": 10, "price_override": 89.0},
                            {"name": "أزرق", "color_hex": "#2196F3", "stock": 8, "price_override": 89.0},
                        ]
                    }
                ]

            # 8. Vacuum Cleaner or fallback
            else:
                p.variants = [
                    {
                        "type": "اللون",
                        "name": "اللون",
                        "options": [
                            {"name": "أبيض ناصع", "color_hex": "#FFFFFF", "stock": 10, "price_override": p.price},
                            {"name": "أسود ملكي", "color_hex": "#212121", "stock": 10, "price_override": p.price},
                        ]
                    }
                ]

        await db.commit()
        print("✅ Successfully seeded all products with rich variants, colors, sizes, and descriptions!")

if __name__ == "__main__":
    asyncio.run(run_seed())

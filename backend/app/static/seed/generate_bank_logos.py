import os
import math
import struct
import zlib

BANKS_DIR = os.path.join(os.path.dirname(__file__), "banks")
os.makedirs(BANKS_DIR, exist_ok=True)

def save_png(width, height, pixel_func, filepath):
    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0) # Filter type 0 (None)
        for x in range(width):
            r, g, b, a = pixel_func(x, y, width, height)
            raw_data.extend([int(r) & 0xFF, int(g) & 0xFF, int(b) & 0xFF, int(a) & 0xFF])
            
    compressed = zlib.compress(bytes(raw_data), 9)
    
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc

    png = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    png += chunk(b'IHDR', ihdr)
    png += chunk(b'IDAT', compressed)
    png += chunk(b'IEND', b'')
    
    with open(filepath, 'wb') as f:
        f.write(png)
    print(f"Generated {filepath}")

# Helper geometry functions
def dist(x1, y1, x2, y2):
    return math.sqrt((x1 - x2)**2 + (y1 - y2)**2)

# 1. Kuraimi Haseb Point (Purple circle with mascot/card icon)
def kuraimi_haseb(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    if r > w / 2 - 4:
        alpha = int((w / 2 - 2 - r) * 127)
        return (92, 36, 131, max(0, min(255, alpha)))
    
    # Base purple: #5c2483
    base_r, base_g, base_b = 92, 36, 131
    
    # White decorative circular ring of dots
    ring_r = w * 0.38
    if abs(r - ring_r) < 3.5:
        angle = math.atan2(y - cy, x - cx)
        if (int(angle * 12 / math.pi) % 2) == 0:
            return (255, 255, 255, 240)
            
    # Center POS/Mascot card
    nx, ny = (x - cx) / (w * 0.25), (y - cy) / (h * 0.25)
    if -0.8 <= nx <= 0.8 and -0.9 <= ny <= 0.9:
        # Rounded box
        corner_d = max(0, abs(nx) - 0.5)**2 + max(0, abs(ny) - 0.6)**2
        if corner_d < 0.12:
            # Inside screen/eyes
            if (-0.5 <= nx <= -0.1 or 0.1 <= nx <= 0.5) and -0.5 <= ny <= -0.1:
                return (92, 36, 131, 255) # Eyes
            if -0.5 <= nx <= 0.5 and 0.2 <= ny <= 0.5:
                return (92, 36, 131, 255) # Smile
            return (255, 255, 255, 255)
            
    return (base_r, base_g, base_b, 255)

# 2. Shamil Money (White circle with Orange & Green leaves)
def shamil_money(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    
    # Outer white/light grey ring
    if r > w / 2 - 6:
        return (230, 235, 240, 255)
    
    # Inner white circle
    # Orange top-right leaf (#f58220), Green bottom-left leaf (#008752)
    nx, ny = (x - cx) / (w * 0.4), (y - cy) / (h * 0.4)
    
    # Orange leaf
    if (nx - 0.2)**2 + (ny + 0.3)**2 < 0.45 and nx > -0.2 and ny < 0.2:
        return (245, 130, 32, 255)
    # Green leaf
    if (nx + 0.2)**2 + (ny - 0.1)**2 < 0.5 and nx < 0.3 and ny > -0.3:
        return (0, 135, 82, 255)
        
    # Text bar in green at bottom
    if -0.8 <= nx <= 0.8 and 0.45 <= ny <= 0.75:
        if abs(nx) < 0.7:
            return (0, 100, 60, 255)
            
    return (255, 255, 255, 255)

# 3. Al Qutaibi Bank (Lime Green circle with clock gauge)
def qutaibi_bank(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    
    # Lime green: #8ec63f / #99cc33
    base_r, base_g, base_b = 152, 201, 38
    
    # White clock gauge ring
    if w * 0.25 <= r <= w * 0.36:
        angle = math.atan2(y - cy, x - cx)
        # Open wedge at top-right
        if not (0.2 < angle < 1.1):
            return (255, 255, 255, 255)
            
    # Clock needle pointing top-right
    nx, ny = (x - cx), (y - cy)
    if 0 <= nx <= w * 0.22 and -w * 0.22 <= ny <= 0:
        if abs(nx + ny) < 4:
            return (255, 255, 255, 255)
            
    # Center dot
    if r <= w * 0.08:
        return (255, 255, 255, 255)
        
    return (base_r, base_g, base_b, 255)

# 4. Al Salam Capital (White circle with Royal Blue geometric star)
def salam_capital(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    if r > w / 2 - 5:
        return (220, 230, 245, 255)
        
    # Royal blue: #1d4ed8 / #2563eb
    nx, ny = abs(x - cx), abs(y - cy)
    # Square 1
    s1 = max(nx, ny)
    # Square 2 rotated 45 deg
    s2 = (nx + ny) / 1.414
    
    blue_r, blue_g, blue_b = 37, 99, 235
    
    # Overlapping geometric interlaced borders
    if (w * 0.20 <= s1 <= w * 0.32) or (w * 0.20 <= s2 <= w * 0.32):
        if not (s1 < w * 0.15 and s2 < w * 0.15):
            return (blue_r, blue_g, blue_b, 255)
            
    return (255, 255, 255, 255)

# 5. Kuraimi Bank (Purple circle with floral calligraphy)
def kuraimi_bank(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    
    # Deep purple: #58237b
    base_r, base_g, base_b = 88, 35, 123
    
    # Outer white beaded ring
    if abs(r - w * 0.42) < 2:
        return (255, 255, 255, 230)
        
    # Inner circular calligraphy motif
    nx, ny = (x - cx) / (w * 0.32), (y - cy) / (h * 0.32)
    if nx**2 + ny**2 < 1.0:
        # Stylized Arabic curves
        pattern = math.sin(nx * 6) * math.cos(ny * 6) + math.cos(r * 0.2)
        if pattern > 0.2:
            return (255, 255, 255, 255)
            
    return (base_r, base_g, base_b, 255)

# 6. Yemen Kuwait Bank YKB (White circle with Blue Star & YKB)
def ykb_bank(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    if r > w / 2 - 5:
        return (220, 235, 250, 255)
        
    # Cyan & Navy 8-pointed star
    nx, ny = (x - cx) / (w * 0.3), (y - (cy - h * 0.08)) / (h * 0.3)
    star_r = math.sqrt(nx**2 + ny**2)
    angle = math.atan2(ny, nx)
    star_shape = 0.6 + 0.35 * math.cos(angle * 8)
    
    if star_r < star_shape:
        if star_r < 0.35:
            return (255, 255, 255, 255)
        return (0, 114, 188, 255) # YKB Blue
        
    # YKB text bar at bottom
    if (y - cy) > h * 0.25 and abs(x - cx) < w * 0.35 and (y - cy) < h * 0.42:
        return (0, 80, 150, 255)
        
    return (255, 255, 255, 255)

# 7. Al-Amal Bank (White circle with colorful ribbon waves)
def alamal_bank(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    if r > w / 2 - 5:
        return (235, 240, 248, 255)
        
    nx, ny = (x - cx) / (w * 0.4), (y - (cy - h * 0.06)) / (h * 0.4)
    # Concentric arches
    arch_r = math.sqrt(nx**2 + (ny + 0.3)**2)
    if 0.5 <= arch_r <= 1.0 and ny < 0.3:
        angle = math.atan2(ny + 0.3, nx)
        if 0 <= angle <= math.pi:
            if arch_r > 0.85:
                return (217, 38, 93, 255) # Pink/Red arch
            elif arch_r > 0.70:
                return (124, 58, 142, 255) # Purple arch
            else:
                return (0, 150, 214, 255) # Cyan arch
                
    # Text bar at bottom
    if (y - cy) > h * 0.24 and abs(x - cx) < w * 0.38 and (y - cy) < h * 0.42:
        return (0, 120, 180, 255)
        
    return (255, 255, 255, 255)

# 8. Pyes CAC Wallet (Bright Orange circle with white badge)
def pyes_wallet(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    
    # Warm orange: #f57c00 / #ff9800
    base_r, base_g, base_b = 245, 124, 0
    
    # White rounded pill badge in center
    nx, ny = (x - cx) / (w * 0.36), (y - cy) / (h * 0.22)
    if max(abs(nx) - 0.4, 0)**2 + ny**2 < 0.6:
        # Arabic text "بيس" inside badge in cyan/blue
        if abs(nx) < 0.6 and abs(ny) < 0.4:
            # Stylized PYES letters/dots
            if -0.4 <= nx <= 0.4 and -0.15 <= ny <= 0.15:
                return (0, 140, 200, 255)
            # Two dots below
            if (-0.2 <= nx <= -0.1 or 0.1 <= nx <= 0.2) and 0.2 <= ny <= 0.35:
                return (0, 140, 200, 255)
        return (255, 255, 255, 255)
        
    return (base_r, base_g, base_b, 255)

# 9. Al Sharq Bank / Shamil Yemen Bank SYB
def alsharq_bank(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    if r > w / 2 - 5:
        return (230, 235, 245, 255)
        
    # Navy SYB bold letters in center
    nx, ny = (x - cx) / (w * 0.38), (y - cy) / (h * 0.3)
    if -0.85 <= nx <= 0.85 and -0.5 <= ny <= 0.25:
        # S, Y, B strokes
        if abs(math.sin(nx * 5) + ny * 2) < 0.5 or (abs(nx) < 0.7 and abs(ny) < 0.2):
            return (15, 45, 90, 255) # Deep navy
            
    # Green underline
    if -0.8 <= nx <= 0.8 and 0.35 <= ny <= 0.48:
        return (0, 150, 75, 255) # Emerald Green
        
    return (255, 255, 255, 255)

# 10. Salam Pay Point (White circle with Royal Blue stylized 'S' curve)
def salam_pay(x, y, w, h):
    cx, cy = w / 2, h / 2
    r = dist(x, y, cx, cy)
    if r > w / 2 - 2:
        return (0, 0, 0, 0)
    if r > w / 2 - 5:
        return (225, 235, 250, 255)
        
    # Stylized S ribbon curve
    nx, ny = (x - cx) / (w * 0.32), (y - cy) / (h * 0.36)
    
    # S curve ribbon
    s_curve = math.sin(ny * 2.8) * 0.55
    dist_to_curve = abs(nx - s_curve)
    
    if dist_to_curve < 0.32 and -0.85 <= ny <= 0.85:
        # Top loop and bottom check loop
        return (30, 64, 175, 255) # Royal navy blue
        
    return (255, 255, 255, 255)

def main():
    size = 180
    banks = [
        ("kuraimi_haseb.png", kuraimi_haseb),
        ("shamil_money.png", shamil_money),
        ("qutaibi_bank.png", qutaibi_bank),
        ("salam_capital.png", salam_capital),
        ("kuraimi_bank.png", kuraimi_bank),
        ("ykb_bank.png", ykb_bank),
        ("alamal_bank.png", alamal_bank),
        ("pyes_wallet.png", pyes_wallet),
        ("alsharq_bank.png", alsharq_bank),
        ("salam_pay.png", salam_pay),
    ]
    
    for filename, func in banks:
        filepath = os.path.join(BANKS_DIR, filename)
        save_png(size, size, func, filepath)

if __name__ == "__main__":
    main()

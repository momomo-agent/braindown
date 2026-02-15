from PIL import Image, ImageDraw, ImageFont
import math
import os

size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Blue gradient background with rounded corners
def rounded_rect(draw, xy, radius, fill_top, fill_bottom):
    x0, y0, x1, y1 = xy
    # Create gradient
    for y in range(y0, y1):
        t = (y - y0) / (y1 - y0)
        r = int(fill_top[0] + t * (fill_bottom[0] - fill_top[0]))
        g = int(fill_top[1] + t * (fill_bottom[1] - fill_top[1]))
        b = int(fill_top[2] + t * (fill_bottom[2] - fill_top[2]))
        draw.line([(x0, y), (x1, y)], fill=(r, g, b, 255))

# Draw gradient background
fill_top = (60, 130, 246)     # Bright blue
fill_bottom = (37, 78, 192)   # Deeper blue
rounded_rect(draw, (0, 0, size, size), 180, fill_top, fill_bottom)

# Apply rounded corners mask
mask = Image.new('L', (size, size), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle([(0, 0), (size-1, size-1)], radius=220, fill=255)
img.putalpha(mask)

# Draw a stylized document/markdown icon
# White document shape
doc_left = 280
doc_top = 160
doc_right = 744
doc_bottom = 864
corner_fold = 120

# Document body
doc_points = [
    (doc_left, doc_top),
    (doc_right - corner_fold, doc_top),
    (doc_right, doc_top + corner_fold),
    (doc_right, doc_bottom),
    (doc_left, doc_bottom),
]
draw.polygon(doc_points, fill=(255, 255, 255, 230))

# Corner fold
fold_points = [
    (doc_right - corner_fold, doc_top),
    (doc_right, doc_top + corner_fold),
    (doc_right - corner_fold, doc_top + corner_fold),
]
draw.polygon(fold_points, fill=(200, 220, 255, 200))

# Draw "MD" text or markdown-style lines on the document
# Heading line (thick)
draw.rounded_rectangle([(340, 340), (700, 380)], radius=8, fill=(60, 130, 246, 200))

# Body lines
line_color = (120, 160, 220, 160)
draw.rounded_rectangle([(340, 420), (680, 448)], radius=6, fill=line_color)
draw.rounded_rectangle([(340, 478), (640, 506)], radius=6, fill=line_color)
draw.rounded_rectangle([(340, 536), (700, 564)], radius=6, fill=line_color)
draw.rounded_rectangle([(340, 594), (580, 622)], radius=6, fill=line_color)

# Bold "M" watermark in the center-bottom area
# Draw a stylized down-arrow / markdown symbol
# Simple "⬇" style M for Markdown
md_color = (37, 78, 192, 80)
# M shape
m_points = [
    (380, 680), (420, 680), (460, 730), (500, 680), (540, 680),
    (540, 780), (500, 780), (500, 720), (460, 770), (420, 720),
    (420, 780), (380, 780),
]
draw.polygon(m_points, fill=md_color)

# Down arrow
arrow_points = [
    (570, 680), (660, 680), (660, 740),
    (690, 740), (615, 790), (540, 740),
    (570, 740),
]
draw.polygon(arrow_points, fill=md_color)

# Save
output_dir = '/Users/kenefe/LOCAL/momo-agent/BrainDown/Resources/Assets.xcassets/AppIcon.appiconset'
os.makedirs(output_dir, exist_ok=True)
img.save(os.path.join(output_dir, 'icon_512x512@2x.png'), 'PNG')

# Also save a 512x512 version
img_512 = img.resize((512, 512), Image.LANCZOS)
img_512.save(os.path.join(output_dir, 'icon_512x512.png'), 'PNG')

print("Icon generated successfully!")

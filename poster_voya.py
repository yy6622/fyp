from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).parent
W, H = 1080, 1730
HERO_H = 500
photo = Image.open(ROOT / 'assets/images/community.jpg').convert('RGB')
logo = Image.open(ROOT / 'assets/images/voya_logo.png').convert('RGBA')
canvas = Image.new('RGB', (W, H), '#f5f1e8')

# Portrait crop of the project's scenic trip photo.
scale = max(W / photo.width, HERO_H / photo.height)
photo = photo.resize((int(photo.width * scale), int(photo.height * scale)), Image.Resampling.LANCZOS)
left = (photo.width - W) // 2
top = max(0, (photo.height - HERO_H) // 2 - 10)
photo = photo.crop((left, top, left + W, top + HERO_H))
canvas.paste(photo, (0, 0))
shade = Image.new('RGBA', (W, HERO_H), (4, 27, 35, 0))
pix = shade.load()
for y in range(HERO_H):
    a = int(18 + 220 * (y / HERO_H) ** 2.1)
    for x in range(W):
        pix[x, y] = (4, 27, 35, a)
canvas.paste(Image.alpha_composite(canvas.crop((0, 0, W, HERO_H)).convert('RGBA'), shade).convert('RGB'), (0, 0))

draw = ImageDraw.Draw(canvas)
font_dir = Path('C:/Windows/Fonts')
def font(name, size):
    return ImageFont.truetype(str(font_dir / name), size)
regular = lambda s: font('msyh.ttc', s)
bold = lambda s: font('msyhbd.ttc', s)
navy, teal, coral = '#0d2932', '#0c5964', '#ed805f'
cream, white, muted = '#f5f1e8', '#fffdf8', '#647174'

# Brand and hero statement
logo = logo.crop(logo.getbbox())
logo.thumbnail((112, 76), Image.Resampling.LANCZOS)
canvas.paste(logo, (58, 40), logo)
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((58, 267, 295, 312), 22, fill=coral)
draw.text((77, 276), 'GROUP TRIP PLANNER', font=bold(18), fill=white)
draw.text((55, 323), 'Less group chat.', font=bold(58), fill=white, stroke_width=1, stroke_fill=white)
draw.text((55, 384), 'More great trips.', font=bold(58), fill=white, stroke_width=1, stroke_fill=white)
draw.text((59, 454), 'Plan itineraries, vote on details & split costs together.', font=regular(20), fill='#edf3ef')

# Intro block
draw.rectangle((0, HERO_H, W, H), fill=cream)
draw.text((58, 535), 'One trip. One shared plan.', font=bold(27), fill=navy)
draw.text((60, 575), 'Plan the itinerary, make group decisions and keep trip costs clear.', font=regular(17), fill=muted)

features = [
    ('01', 'Create a Trip', 'Set dates, budget & invite your crew', 'calendar'),
    ('02', 'Explore & Save', 'Find flights, stays & places.\nSave your favorites.', 'pin'),
    ('03', 'Shared Itinerary', 'Shape each day. Reorder and\nupdate plans together.', 'route'),
    ('04', 'AI Trip Assistant', 'Turn group chat into\nready-to-review trip ideas.', 'spark'),
    ('05', 'Group Polls', 'Vote on hotels, dining\nand activities as a group.', 'poll'),
    ('06', 'Expenses & Splits', 'Log costs, split bills\nand track who has paid.', 'wallet'),
    ('07', 'Flights & Stays', 'Keep flight and hotel details\nwith your shared trip.', 'plane'),
    ('08', 'Weather Updates', 'Check the forecast and\nadjust outdoor plans.', 'weather'),
    ('09', 'Safety & Help', 'Emergency info. Share your\nlocation with the group.', 'shield'),
    ('10', 'Community & Insurance', 'Get trip ideas. Compare\ntravel insurance coverage.', 'people'),
]

# Compact cards with quick-scan pictograms.
def icon(kind, x, y):
    d = ImageDraw.Draw(canvas)
    d.ellipse((x, y, x+64, y+64), fill='#dcebe6')
    c, a = teal, coral
    if kind == 'calendar':
        d.rounded_rectangle((x+15,y+17,x+49,y+49), radius=5, outline=c, width=3)
        d.line((x+15,y+26,x+49,y+26), fill=a, width=3)
        d.line((x+23,y+12,x+23,y+21), fill=c, width=3); d.line((x+41,y+12,x+41,y+21), fill=c, width=3)
        for xx in (x+24,x+34,x+44): d.ellipse((xx-1,y+32,xx+2,y+35), fill=c)
    elif kind == 'pin':
        d.ellipse((x+16,y+12,x+48,y+44), outline=c, width=4)
        d.polygon([(x+19,y+36),(x+45,y+36),(x+32,y+54)], fill=c)
        d.ellipse((x+27,y+22,x+37,y+32), fill=a)
    elif kind == 'route':
        d.line((x+17,y+45,x+31,y+20,x+46,y+42), fill=c, width=4)
        d.ellipse((x+12,y+40,x+23,y+51), fill=a); d.ellipse((x+26,y+15,x+37,y+26), fill=c); d.ellipse((x+41,y+37,x+52,y+48), fill=a)
    elif kind == 'spark':
        d.line((x+32,y+10,x+37,y+27,x+53,y+32,x+37,y+37,x+32,y+54,x+27,y+37,x+11,y+32,x+27,y+27,x+32,y+10), fill=c, width=3)
        d.ellipse((x+43,y+11,x+49,y+17), fill=a); d.ellipse((x+14,y+45,x+20,y+51), fill=a)
    elif kind == 'poll':
        for yy in (17,29,41):
            d.rounded_rectangle((x+12,y+yy,x+23,y+yy+10), radius=2, outline=c, width=2)
            d.line((x+29,y+yy+5,x+51,y+yy+5), fill=c, width=3)
        d.line((x+14,y+34,x+17,y+37,x+22,y+30), fill=a, width=2)
    elif kind == 'wallet':
        d.rounded_rectangle((x+11,y+18,x+52,y+47), radius=6, outline=c, width=3)
        d.rounded_rectangle((x+34,y+26,x+54,y+40), radius=4, fill=a)
        d.ellipse((x+40,y+31,x+45,y+36), fill=white)
    elif kind == 'plane':
        d.line((x+13,y+42,x+49,y+22), fill=c, width=5)
        d.line((x+27,y+34,x+23,y+17), fill=c, width=4)
        d.line((x+30,y+33,x+43,y+44), fill=c, width=4)
        d.line((x+15,y+41,x+10,y+34), fill=a, width=3)
    elif kind == 'weather':
        d.ellipse((x+12,y+12,x+35,y+35), outline=a, width=3)
        for xx,yy in ((23,6),(23,39),(6,23),(40,23)):
            if xx == 23: d.line((x+xx,y+yy,x+xx,y+yy+5 if yy<20 else y+yy+5), fill=a, width=2)
            else: d.line((x+xx,y+yy,x+xx+5,y+yy), fill=a, width=2)
        d.ellipse((x+22,y+32,x+43,y+51), fill=c); d.ellipse((x+34,y+28,x+52,y+50), fill=c); d.rectangle((x+28,y+40,x+49,y+50), fill=c)
    elif kind == 'shield':
        d.polygon([(x+32,y+11),(x+49,y+18),(x+46,y+39),(x+32,y+53),(x+18,y+39),(x+15,y+18)], outline=c, fill=None)
        d.line((x+23,y+32,x+30,y+39,x+42,y+25), fill=a, width=4)
    elif kind == 'people':
        d.ellipse((x+14,y+15,x+30,y+31), fill=c); d.ellipse((x+35,y+15,x+51,y+31), fill=a)
        d.arc((x+8,y+28,x+36,y+54), 185, 355, fill=c, width=4); d.arc((x+28,y+28,x+56,y+54), 185, 355, fill=a, width=4)

card_w, card_h = 466, 170
gap_x, gap_y = 32, 16
start_x, start_y = 58, 620
for i, (num, title, subtitle, glyph) in enumerate(features):
    col, row = i % 2, i // 2
    x = start_x + col * (card_w + gap_x)
    y = start_y + row * (card_h + gap_y)
    draw.rounded_rectangle((x, y, x + card_w, y + card_h), radius=22, fill=white, outline='#e4ddd1', width=2)
    icon(glyph, x + 24, y + 53)
    draw.text((x + 108, y + 51), title, font=bold(23), fill=navy)
    draw.multiline_text((x + 108, y + 91), subtitle, font=regular(17), fill='#536265', spacing=5)

# Closing band
footer_y = start_y + 5 * (card_h + gap_y) + 8
draw.rounded_rectangle((58, footer_y, 1022, footer_y + 100), radius=24, fill=navy)
draw.text((88, footer_y + 22), 'Plan together, travel better', font=bold(27), fill=white)
draw.text((89, footer_y + 62), 'YOUR NEXT ADVENTURE STARTS HERE', font=regular(15), fill='#bfd6d2')

out = ROOT / 'voya_trip_planner_poster.png'
canvas.save(out, optimize=True)
print(out)

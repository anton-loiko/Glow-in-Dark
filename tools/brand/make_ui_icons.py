#!/usr/bin/env python3
"""UI-иконки вкладок и валют + рамки редкости (DS §02, Gear DS §00/§01) → src/assets/ui/{icons,gear}/*.svg.

Иконки — сетка 24pt, мягкие формы, заливка + внутренний тёплый блик, без контура, белые под modulate.
Искра всегда круг, Кристалл всегда ромб (DS). Рамки редкости — 96×96 для 9-slice (texture_margin 24), градиент
кромки 300 → 700 (Легендарный — золото в три стопа + искры в углах). PNG растеризует Inkscape.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS_OUT = os.path.join(ROOT, "src", "assets", "ui", "icons")
FRAMES_OUT = os.path.join(ROOT, "src", "assets", "ui", "gear")

FILL = """<linearGradient id="fill" x1="0.2" y1="0.1" x2="0.8" y2="0.95">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#C9C4BA"/>
    </linearGradient>"""
HL = 'fill="#FFF1C8" fill-opacity="0.55"'

ICONS = {
    # Маяк: кристалл на постаменте.
    "tab_beacon": """<path id="crystal" fill="url(#fill)" d="M12 1.5l5 7l-5 8l-5-8z"/>
  <path id="base" fill="url(#fill)" d="M5 18h14a1.5 1.5 0 0 1 1.5 1.5V21a1 1 0 0 1-1 1h-15a1 1 0 0 1-1-1v-1.5A1.5 1.5 0 0 1 5 18z"/>
  <path id="hl" {HL} d="M11.6 3.6L8.3 8.4l.9 1.4l2.4-3.9z"/>""",
    # Магазин: лавка с навесом.
    "tab_shop": """<path id="awning" fill="url(#fill)" d="M3 4h18l1.5 5.2a2.4 2.4 0 0 1-4.6 1.2a2.4 2.4 0 0 1-4.4 0h-.9a2.4 2.4 0 0 1-4.4 0a2.4 2.4 0 0 1-4.6-1.2z"/>
  <path id="shop" fill="url(#fill)" d="M4.5 12.5h15V20a1.5 1.5 0 0 1-1.5 1.5H6A1.5 1.5 0 0 1 4.5 20z"/>
  <rect id="door" x="10" y="15" width="4" height="6.5" rx="1" fill="#8F98AB"/>
  <path id="hl" {HL} d="M4.2 5h2.2l-1 4.2H4z"/>""",
    # Навыки: раскрытая книга.
    "tab_skills": """<path id="left" fill="url(#fill)" d="M11.2 5.5C9.3 4 6.6 3.3 3 3.5v15c3.6-.2 6.3.5 8.2 2z"/>
  <path id="right" fill="url(#fill)" fill-opacity="0.85" d="M12.8 5.5c1.9-1.5 4.6-2.2 8.2-2v15c-3.6-.2-6.3.5-8.2 2z"/>
  <path id="hl" {HL} d="M4.2 4.8c2.2 0 4 .4 5.5 1.3v1.2c-1.5-.9-3.3-1.3-5.5-1.3z"/>""",
    # Экипировка: шлем.
    "tab_gear": """<path id="helm" fill="url(#fill)" d="M12 2.5c5 0 8.5 3.6 8.5 8.5v4.5a2 2 0 0 1-2 2h-3.3v-5.3a3.2 3.2 0 0 0-6.4 0v5.3H5.5a2 2 0 0 1-2-2V11c0-4.9 3.5-8.5 8.5-8.5z"/>
  <rect id="crest" x="11" y="1" width="2" height="5" rx="1" fill="url(#fill)"/>
  <path id="hl" {HL} d="M5.5 10.2c.4-2.6 2.2-4.7 4.8-5.5l.3.9c-2.2.7-3.7 2.4-4.1 4.7z"/>""",
    # Искра: всегда круг — шар с бликом-звёздочкой.
    "cur_spark": """<circle id="orb" cx="12" cy="12" r="9" fill="url(#fill)"/>
  <path id="glint" fill="#FFFFFF" d="M9 5.5l.8 2.4l2.4.8l-2.4.8L9 11.9l-.8-2.4l-2.4-.8l2.4-.8z"/>
  <path id="hl" {HL} d="M5.4 12a6.6 6.6 0 0 1 1.3-3.9l.8.6A5.6 5.6 0 0 0 6.4 12z"/>""",
    # Кристалл: всегда ромб — огранённый.
    "cur_crystal": """<path id="gem" fill="url(#fill)" d="M12 1.5l8.5 10.5L12 22.5L3.5 12z"/>
  <path id="facet" fill="#FFFFFF" fill-opacity="0.45" d="M12 1.5L7.5 12H3.5zM12 1.5l4.5 10.5H12z"/>
  <path id="hl" {HL} d="M11.4 4.2L7.6 9.6l.5.7l3.3-4.8z"/>""",
}

# Рамки: стопы градиента кромки (Gear DS §00).
RARITY = {
    "common": ["#8F98AB", "#3A4356"],
    "uncommon": ["#B8F0C0", "#3F8A4E"],
    "rare": ["#A8C4FF", "#2F56B8"],
    "epic": ["#D4B0FF", "#6A3FB0"],
    "legendary": ["#FFF1C8", "#FFB547", "#B8621A"],
}


def icon_svg(name, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" id="{name}" width="96" height="96" viewBox="0 0 24 24">\n  '
            f'<defs>\n    {FILL}\n  </defs>\n  {body.replace("{HL}", HL)}\n</svg>\n')


def frame_svg(name, stops):
    offsets = [0, 1] if len(stops) == 2 else [0, 0.45, 1]
    grad = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in zip(offsets, stops))
    extra = ""
    if name == "legendary":
        # три искры в углах — двойное кодирование редкости (не только цвет)
        for cx, cy in ((14, 14), (82, 14), (82, 82)):
            extra += (f'<path id="spark_{cx}_{cy}" fill="#FFF1C8" d="M{cx} {cy - 6}l1.6 4.4l4.4 1.6l-4.4 1.6l-1.6 4.4'
                      f'l-1.6-4.4l-4.4-1.6l4.4-1.6z"/>')
    inner = 3 if name in ("epic", "legendary") else 0
    inner_ring = (f'<rect id="inner" x="9" y="9" width="78" height="78" rx="20" fill="none" stroke="{stops[0]}" '
                  f'stroke-opacity="0.35" stroke-width="{inner}"/>') if inner else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" id="frame_{name}" width="96" height="96" viewBox="0 0 96 96">\n  '
            f'<defs><linearGradient id="edge" x1="0" y1="0" x2="0.3" y2="1">{grad}</linearGradient></defs>\n  '
            f'<rect id="edge_ring" x="3" y="3" width="90" height="90" rx="26" fill="none" stroke="url(#edge)" stroke-width="6"/>\n  '
            f'<path id="top_hl" d="M24 5.5h48" stroke="#FFFFFF" stroke-opacity="0.45" stroke-width="2" stroke-linecap="round"/>\n  '
            f'{inner_ring}{extra}\n</svg>\n')


def main():
    os.makedirs(ICONS_OUT, exist_ok=True)
    os.makedirs(FRAMES_OUT, exist_ok=True)
    for name, body in ICONS.items():
        with open(os.path.join(ICONS_OUT, name + ".svg"), "w") as f:
            f.write(icon_svg(name, body))
    for name, stops in RARITY.items():
        with open(os.path.join(FRAMES_OUT, "frame_" + name + ".svg"), "w") as f:
            f.write(frame_svg(name, stops))
    # мягкое свечение для blend add (modulate = цвет 500)
    glow = ('<svg xmlns="http://www.w3.org/2000/svg" id="gear_glow" width="128" height="128" viewBox="0 0 128 128">'
            '<defs><radialGradient id="g"><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0.9"/>'
            '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient></defs>'
            '<rect id="glow" width="128" height="128" rx="40" fill="url(#g)"/></svg>\n')
    with open(os.path.join(FRAMES_OUT, "gear_glow.svg"), "w") as f:
        f.write(glow)
    print("icons", len(ICONS), "frames", len(RARITY) + 1)


if __name__ == "__main__":
    main()

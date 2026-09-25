#!/usr/bin/env python3
"""Бренд-пак Glow in the Dark (DS §07, task_8 §1) → src/assets/brand/*.svg.

Знак: капля-Огонёк в тайле ink.900 (r 28%). Иконка приложения: Огонёк с лицом — 40% ширины, центр на 52% Y,
пара красных глаз в левом верхнем углу (в мелкой версии — без них). Android adaptive — передний план в
безопасной зоне 66%, фон, монохром. Boot splash — знак со свечением на ink.900.
PNG растеризует Inkscape: tools/brand/export_brand.sh.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "src", "assets", "brand")

INK_900 = "#07090F"
INK_700 = "#0E1320"
LIGHT_300 = "#FFD08A"
LIGHT_500 = "#FFB547"
LIGHT_700 = "#E08A1E"
HERO_CORE = "#FFFDF5"
THREAT = "#FF3B5C"


def droplet(cx, cy, r):
    """Капля: круг снизу, мягкое острие сверху. Центр круга — (cx, cy + 0.1r)."""
    top = cy - 1.55 * r
    by = cy + 0.1 * r
    return (f"M {cx:.1f},{top:.1f} "
            f"C {cx + 0.38 * r:.1f},{cy - 1.0 * r:.1f} {cx + r:.1f},{cy - 0.5 * r:.1f} {cx + r:.1f},{by:.1f} "
            f"A {r:.1f} {r:.1f} 0 1 1 {cx - r:.1f},{by:.1f} "
            f"C {cx - r:.1f},{cy - 0.5 * r:.1f} {cx - 0.38 * r:.1f},{cy - 1.0 * r:.1f} {cx:.1f},{top:.1f} Z")


def defs(glow_opacity=0.55):
    return f"""<defs id="defs">
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="{LIGHT_500}" stop-opacity="{glow_opacity}"/>
      <stop offset="0.45" stop-color="{LIGHT_700}" stop-opacity="{glow_opacity * 0.35:.3f}"/>
      <stop offset="1" stop-color="{LIGHT_700}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="body" cx="0.42" cy="0.62" r="0.7">
      <stop offset="0" stop-color="{LIGHT_300}"/>
      <stop offset="0.55" stop-color="{LIGHT_500}"/>
      <stop offset="1" stop-color="{LIGHT_700}"/>
    </radialGradient>
    <radialGradient id="core" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="{HERO_CORE}"/>
      <stop offset="0.7" stop-color="{HERO_CORE}" stop-opacity="0.85"/>
      <stop offset="1" stop-color="{LIGHT_300}" stop-opacity="0"/>
    </radialGradient>
  </defs>"""


def hero(cx, cy, r, face=True, prefix="hero"):
    """Огонёк: свечение, тело, раскалённое ядро, внутренний тёплый блик и (опционально) лицо."""
    parts = [
        f'<circle id="{prefix}-glow" cx="{cx}" cy="{cy + 0.1 * r:.1f}" r="{r * 2.4:.1f}" fill="url(#glow)"/>',
        f'<path id="{prefix}-body" d="{droplet(cx, cy, r)}" fill="url(#body)"/>',
        f'<ellipse id="{prefix}-core" cx="{cx}" cy="{cy + 0.2 * r:.1f}" rx="{r * 0.55:.1f}" ry="{r * 0.52:.1f}" fill="url(#core)"/>',
        f'<path id="{prefix}-highlight" d="M {cx - 0.62 * r:.1f},{cy - 0.2 * r:.1f} Q {cx - 0.55 * r:.1f},{cy - 0.75 * r:.1f} {cx - 0.12 * r:.1f},{cy - 1.1 * r:.1f}" '
        f'stroke="{HERO_CORE}" stroke-opacity="0.55" stroke-width="{r * 0.09:.1f}" stroke-linecap="round" fill="none"/>',
    ]
    if face:
        ex, ey, er = r * 0.3, cy + 0.12 * r, r * 0.16
        for side, sx in (("l", -1), ("r", 1)):
            parts.append(f'<ellipse id="{prefix}-eye-{side}" cx="{cx + sx * ex:.1f}" cy="{ey:.1f}" rx="{er:.1f}" ry="{er * 1.25:.1f}" fill="{INK_900}"/>')
            parts.append(f'<circle id="{prefix}-eye-{side}-shine" cx="{cx + sx * ex + er * 0.35:.1f}" cy="{ey - er * 0.45:.1f}" r="{er * 0.38:.1f}" fill="{HERO_CORE}"/>')
    return "\n  ".join(parts)


def red_eyes(x, y, s, prefix="threat"):
    """Пара красных глаз во тьме — угроза (только #FF3B5C)."""
    return (f'<g id="{prefix}" fill="{THREAT}">'
            f'<ellipse id="{prefix}-l" cx="{x - s:.1f}" cy="{y:.1f}" rx="{s * 0.55:.1f}" ry="{s * 0.32:.1f}" transform="rotate(12 {x - s:.1f} {y:.1f})"/>'
            f'<ellipse id="{prefix}-r" cx="{x + s:.1f}" cy="{y:.1f}" rx="{s * 0.55:.1f}" ry="{s * 0.32:.1f}" transform="rotate(-12 {x + s:.1f} {y:.1f})"/>'
            f'</g>')


def svg(w, h, body, glow_opacity=0.55):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" id="root" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n  '
            f'{defs(glow_opacity)}\n  {body}\n</svg>\n')


def write(name, content):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w") as f:
        f.write(content)
    print("wrote", os.path.relpath(os.path.join(OUT, name), ROOT))


def main():
    s = 1024
    # Знак: капля в тайле ink.900, скругление 28%.
    write("mark.svg", svg(s, s, f'<rect id="tile" width="{s}" height="{s}" rx="{s * 0.28:.1f}" fill="{INK_900}"/>\n  ' + hero(512, 560, 200, face=False)))
    # Иконка приложения: Огонёк 40% ширины (r = 0.2 * s), центр на 52% Y, красные глаза слева вверху.
    r = s * 0.2
    base = f'<rect id="bg" width="{s}" height="{s}" fill="{INK_900}"/>\n  '
    write("app_icon.svg", svg(s, s, base + red_eyes(200, 210, 46) + "\n  " + hero(512, s * 0.52, r)))
    write("app_icon_small.svg", svg(s, s, base + hero(512, s * 0.52, r)))
    # Android adaptive 432: передний план в безопасной зоне (центральные 66%).
    a = 432
    write("android_fg.svg", svg(a, a, hero(216, 226, a * 0.14)))
    write("android_bg.svg", svg(a, a, f'<rect id="bg" width="{a}" height="{a}" fill="{INK_900}"/>\n  <circle id="bg-glow" cx="216" cy="230" r="230" fill="url(#glow)" opacity="0.35"/>'))
    write("android_mono.svg", svg(a, a, f'<path id="mono" d="{droplet(216, 226, a * 0.14)}" fill="#FFFFFF"/>'))
    # Boot splash 1080×1920: знак со свечением на 36% высоты, без текста (надпись рисует экран S01).
    write("splash.svg", svg(1080, 1920, f'<rect id="bg" width="1080" height="1920" fill="{INK_900}"/>\n  ' + hero(540, 1920 * 0.36, 120, face=False), glow_opacity=0.45))


if __name__ == "__main__":
    main()

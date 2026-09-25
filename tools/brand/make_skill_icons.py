#!/usr/bin/env python3
"""Иконки навыков (DS §02, Skills DS) → src/assets/ui/skills/<id>.svg.

Сетка 24pt (viewBox 0 0 24 24): мягкие формы, заливка + внутренний тёплый блик, без контура. Цвет — белый/светло-серый,
чтобы игра перекрашивала иконку modulate цветом категории. PNG 128px растеризует Inkscape (inkscape_file batch_convert).
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "src", "assets", "ui", "skills")

DEFS = """<defs>
    <linearGradient id="fill" x1="0.2" y1="0.1" x2="0.8" y2="0.95">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#C9C4BA"/>
    </linearGradient>
  </defs>"""

# Тёплый внутренний блик — полупрозрачная светлая форма у верхнего левого края.
HL = 'fill="#FFF1C8" fill-opacity="0.55"'

ICONS = {
    # ▲ Аура: кольцо жара с тремя языками пламени.
    "aura": """<path id="ring" fill-rule="evenodd" fill="url(#fill)" d="M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18zm0 3.2a5.8 5.8 0 1 0 0 11.6a5.8 5.8 0 1 0 0-11.6z"/>
  <circle id="core" cx="12" cy="12" r="2.6" fill="url(#fill)"/>
  <path id="hl" {HL} d="M6.2 9.2a6.6 6.6 0 0 1 4.3-4.1a0.9 0.9 0 0 1 .5 1.7a4.9 4.9 0 0 0-3.1 3a0.9 0.9 0 0 1-1.7-.6z"/>""",
    # ▲ Пульсар: ядро и две волны.
    "pulsar": """<circle id="core" cx="12" cy="12" r="3.4" fill="url(#fill)"/>
  <path id="wave1" fill="url(#fill)" d="M12 5.4a6.6 6.6 0 0 1 6.6 6.6h-2.2a4.4 4.4 0 0 0-4.4-4.4zM12 18.6a6.6 6.6 0 0 1-6.6-6.6h2.2a4.4 4.4 0 0 0 4.4 4.4z"/>
  <path id="wave2" fill="url(#fill)" fill-opacity="0.75" d="M12 1.8a10.2 10.2 0 0 1 10.2 10.2h-2a8.2 8.2 0 0 0-8.2-8.2zM12 22.2a10.2 10.2 0 0 1-10.2-10.2h2a8.2 8.2 0 0 0 8.2 8.2z"/>
  <circle id="hl" cx="11" cy="11" r="1.2" {HL}/>""",
    # ▲ Огненный след: три капли пламени по убыванию.
    "trail": """<path id="f1" fill="url(#fill)" d="M16.5 4c1.8 2.4 3.5 4.3 3.5 6.6a3.6 3.6 0 0 1-7.2 0c0-2.3 1.9-4.2 3.7-6.6z"/>
  <path id="f2" fill="url(#fill)" fill-opacity="0.8" d="M10 9.5c1.3 1.7 2.5 3 2.5 4.6a2.6 2.6 0 0 1-5.2 0c0-1.6 1.4-2.9 2.7-4.6z"/>
  <path id="f3" fill="url(#fill)" fill-opacity="0.6" d="M5 14.5c.9 1.2 1.8 2.1 1.8 3.3a1.9 1.9 0 0 1-3.8 0c0-1.2 1-2.1 2-3.3z"/>
  <path id="hl" {HL} d="M15.3 8.4c.4-.9 1-1.8 1.6-2.6a.5.5 0 0 1 .8.6c-.5.7-1 1.5-1.4 2.3a.55.55 0 0 1-1-.3z"/>""",
    # ▲ Луч: сужающийся луч и вспышка у источника.
    "beam": """<path id="beam" fill="url(#fill)" d="M5 10.6L21 11.3a.7.7 0 0 1 0 1.4L5 13.4z"/>
  <path id="star" fill="url(#fill)" d="M5 5.5l1.3 4.2l4.2 1.3l-4.2 1.3L5 16.5l-1.3-4.2L-.5 11l4.2-1.3z" transform="translate(1.5 1)"/>
  <circle id="hl" cx="6.2" cy="11.3" r="1" {HL}/>""",
    # ● Сферы: три сферы на орбите вокруг ядра.
    "orbs": """<circle id="core" cx="12" cy="12" r="2.4" fill="url(#fill)" fill-opacity="0.7"/>
  <circle id="o1" cx="12" cy="4.6" r="2.8" fill="url(#fill)"/>
  <circle id="o2" cx="18.4" cy="15.7" r="2.8" fill="url(#fill)"/>
  <circle id="o3" cx="5.6" cy="15.7" r="2.8" fill="url(#fill)"/>
  <circle id="hl" cx="11.2" cy="3.8" r=".9" {HL}/>""",
    # ■ Энергоёмкость: капсула-аккумулятор со светом внутри.
    "capacity": """<path id="shell" fill-rule="evenodd" fill="url(#fill)" d="M8 3.5h8a2.5 2.5 0 0 1 2.5 2.5v13a2.5 2.5 0 0 1-2.5 2.5H8A2.5 2.5 0 0 1 5.5 19V6A2.5 2.5 0 0 1 8 3.5zm.3 2.3a.8.8 0 0 0-.8.8v11.8a.8.8 0 0 0 .8.8h7.4a.8.8 0 0 0 .8-.8V6.6a.8.8 0 0 0-.8-.8z"/>
  <rect id="cap" x="10" y="1.5" width="4" height="2" rx=".8" fill="url(#fill)"/>
  <rect id="charge" x="8.8" y="10" width="6.4" height="8.3" rx="1" fill="url(#fill)"/>
  <rect id="hl" x="9.6" y="11" width="1.2" height="5" rx=".6" {HL}/>""",
    # ■ Щит.
    "shield": """<path id="shield" fill="url(#fill)" d="M12 2.5l7.5 3v6c0 4.7-3.2 8.2-7.5 10c-4.3-1.8-7.5-5.3-7.5-10v-6z"/>
  <path id="hl" {HL} d="M12 5l-5 2v4.4c0 1.4.4 2.7 1 3.8l.4-.1c-.4-1.1-.6-2.3-.6-3.6V7.6L12 5.9z"/>""",
    # ■ Заморозка: снежинка.
    "freeze": """<g id="flake" fill="url(#fill)">
    <rect x="11" y="2" width="2" height="20" rx="1"/>
    <rect x="11" y="2" width="2" height="20" rx="1" transform="rotate(60 12 12)"/>
    <rect x="11" y="2" width="2" height="20" rx="1" transform="rotate(-60 12 12)"/>
    <path d="M9.6 3.6L12 6l2.4-2.4l1 1L12 8l-3.4-3.4zM9.6 20.4L12 18l2.4 2.4l1-1L12 16l-3.4 3.4z"/>
  </g>
  <circle id="hl" cx="12" cy="12" r="1.6" {HL}/>""",
    # ● Магнит: подкова.
    "magnet": """<path id="magnet" fill="url(#fill)" d="M5 3.5h4.2v8.8a2.8 2.8 0 0 0 5.6 0V3.5H19v8.8a7 7 0 0 1-14 0z"/>
  <rect id="tip1" x="5" y="3.5" width="4.2" height="3" fill="#FFFFFF"/>
  <rect id="tip2" x="14.8" y="3.5" width="4.2" height="3" fill="#FFFFFF"/>
  <path id="hl" {HL} d="M6.1 8h1v4.3a4.9 4.9 0 0 0 1.4 3.5l-.7.7a5.9 5.9 0 0 1-1.7-4.2z"/>""",
    # ● Ускорение: молния.
    "haste": """<path id="bolt" fill="url(#fill)" d="M13.5 1.5L5 13.2h5.3L9 22.5l9-12.4h-5.4z"/>
  <path id="hl" {HL} d="M12.2 4.4L7.2 11.6h1.6l3.9-5.4z"/>""",
    # ● Фокусная линза: кольцо линзы и четыре риски.
    "lens": """<path id="lens" fill-rule="evenodd" fill="url(#fill)" d="M12 4.5a7.5 7.5 0 1 1 0 15a7.5 7.5 0 1 1 0-15zm0 2.4a5.1 5.1 0 1 0 0 10.2a5.1 5.1 0 1 0 0-10.2z"/>
  <g id="ticks" fill="url(#fill)"><rect x="11.1" y=".8" width="1.8" height="3.2" rx=".9"/><rect x="11.1" y="20" width="1.8" height="3.2" rx=".9"/><rect x=".8" y="11.1" width="3.2" height="1.8" rx=".9"/><rect x="20" y="11.1" width="3.2" height="1.8" rx=".9"/></g>
  <path id="hl" {HL} d="M8.4 9.6a4.4 4.4 0 0 1 2.4-2.3l.3.8a3.5 3.5 0 0 0-1.9 1.8z"/>""",
    # ■ Перезарядка: песочные часы.
    "cooldown": """<path id="glass" fill="url(#fill)" d="M6 2.5h12v2.2c0 2.6-1.6 4.8-3.8 5.8v3c2.2 1 3.8 3.2 3.8 5.8v2.2H6v-2.2c0-2.6 1.6-4.8 3.8-5.8v-3C7.6 9.5 6 7.3 6 4.7z"/>
  <path id="sand" fill="#8F98AB" fill-opacity="0.6" d="M8.6 19.2c.4-1.9 1.8-3.3 3.4-3.6c1.6.3 3 1.7 3.4 3.6z"/>
  <path id="hl" {HL} d="M7.4 4h1.1v.7c0 1.7.9 3.2 2.3 4l-.5.9a5.6 5.6 0 0 1-2.9-4.9z"/>""",
    # Бонус: искры (четырёхлучевая звезда).
    "fallback_sparks": """<path id="spark" fill="url(#fill)" d="M12 2l2.2 7.8L22 12l-7.8 2.2L12 22l-2.2-7.8L2 12l7.8-2.2z"/>
  <circle id="hl" cx="11" cy="11" r="1.3" {HL}/>""",
    # Бонус: свет (капля).
    "fallback_light": """<path id="drop" fill="url(#fill)" d="M12 2.5c2.6 3.4 6 6.6 6 10.4a6 6 0 0 1-12 0c0-3.8 3.4-7 6-10.4z"/>
  <path id="hl" {HL} d="M9.2 11.2c.5-1.4 1.5-2.8 2.6-4.2l.6.5c-1 1.3-2 2.6-2.4 4z"/>""",
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, body in ICONS.items():
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" id="{name}" width="128" height="128" viewBox="0 0 24 24">\n  '
               f'{DEFS}\n  {body.replace("{HL}", HL)}\n</svg>\n')
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(svg)
        print("wrote", name)


if __name__ == "__main__":
    main()

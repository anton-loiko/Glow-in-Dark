# Спецификация ассетов V1

Производственный список (task_8 §1). Общие правила — `docs/GRAPHICS.md`; истина по цвету и форме — `docs/design/*.pdf` (Art Direction Reboot, Enemy DS §09, Gear DS, Meta DS). Вьюпорт 390×844 pt; растр — **2× от экранного размера**, Linear-фильтр, у освещаемых спрайтов normal map `<name>_n.png`.

Статус: ⬜ не начат · 🟨 рабочая версия (процедурная или черновая, заменяется) · ✅ финал.

## 1. Огонёк (`src/assets/hero/`)

| Файл | Размер | Содержание | Статус |
|---|---|---|---|
| `hero_body.png` + `hero_body_n.png` | 170×170 (85pt) | Капля с белым раскалённым ядром `hero.core #FFFDF5`, тело в цвете скина (белый — перекрашивается `modulate`/шейдером), мягкий край | 🟨 |
| `hero_eyes_{calm,focus,fear,joy}.png` | 170×170 | 4 эмоции глаз (два больших глаза), слой поверх тела | 🟨 |
| `hero_supernova_{aura,orbit,flame}.png` | 256×256 | Слои позднего забега «Сверхновая» (аура, орбиты, пламя на макушке) | ⬜ |
| `hero_lowlight_overlay.png` | 170×170 | Состояние HP < 25%: тусклый край, трещины света | ⬜ |

Дыхание, squash & stretch, кивок — движком (твины, шейдер). Грейскейл-тест: Огонёк — самое светлое пятно кадра.

## 2. Враги (`src/assets/enemies/<archetype>/`) — Enemy DS §09

| Архетип | Класс | Исходник | Кадры | Статус |
|---|---|---|---|---|
| Шёпот `whisper` | S | 72×72 | idle/move 6 · telegraph 4 | 🟨 |
| Жнец `reaper` | M | 128×128 | idle/move 6 · telegraph 6 · attack (рывок) 4 | 🟨 |
| Пожиратель `devourer` | L | 224×224 | idle/move 6 · telegraph 6 · attack (удар) 6 | 🟨 |
| Гаситель `extinguisher` | XL | 320×320 | idle/move 8 · telegraph (аура) 6 | 🟨 |
| Плакальщик `mourner` (за флагом) | M | 128×128 | idle/move 6 · telegraph 4 | ⬜ |

На архетип — атлас `<id>_sheet.png`, `<id>_sheet_n.png`, `<id>_mask.png` (R — глаза, G — трещины для dissolve). Тело темнее тьмы, глаза `threat #FF3B5C` (unshaded в шейдере), rim-свет — цветом скина игрока. ≤ 3 draw call на архетип (общий материал, MultiMesh при > 40 одинаковых).

## 3. Мир (`src/assets/world/<biome>/`)

Биомы: `flooded_city` (глава 1), `sleeping_forest` (2), `rusty_port` (3).

| Файл | Размер | Кол-во | Статус |
|---|---|---|---|
| `floor_{a,b,c,d}.png` + `_n` | 512×512 бесшовная | 4 общих, тон главы через modulate | 🟨 (`floor_1..4`, генератор) |
| `prop_<name>.png` + `_n` + полигон `LightOccluder2D` | 96–384 | 8–12 на биом | 🟨 (`prop_slab`, `prop_rubble`, окклюдер — прямоугольник) |
| `biolum_<name>.png` (грибы, светлячки, руны) | 64–128 | 4–6 на биом | ⬜ |
| `fog_layer` | шейдер `fog.gdshader` (fbm) | параллакс 0.8× | 🟨 |

Законы: окружение ≤ 60% яркости врагов в свете; биолюминесценция не красная и не янтарная; приглушённая насыщенность пола.

## 4. Маяк и хаб (`src/assets/beacon/`) — Meta DS §01

| Файл | Размер | Статус |
|---|---|---|
| `pedestal_{ruins,cracked,runes,armored,radiant}.png` (свет запечён) | 320×160 | 🟨 (генератор) |
| `crystal_{shards,dim,bright,white}.png` — 12 кадров вращения | 96×160 кадр | 🟨 (генератор) |
| `rune_{off,on}.png` | 24×24 | 🟨 |
| `hub_diorama_ch{1..3}.png` + маска `hub_light` | 780×1100 | ⬜ |
| `beam.png`, `aura.png`, `mote.png` | 64–256 | 🟨 |

## 5. Экипировка и сундуки (`src/assets/gear/`) — Gear DS

| Файл | Размер | Статус |
|---|---|---|
| `gear_frame_{common,uncommon,rare,epic,legendary}.png` 9-slice, `texture_margin` 24 | 96×96 | 🟨 (`GearCell` рисует процедурно) |
| `gear_glow.png` (blend add, `modulate` = цвет 500) | 128×128 | ⬜ |
| `src/assets/ui/gear/<base_id>.png` — иконки предметов, белые под `modulate` цветом редкости | 128×128 | 🟨 (4 базовые вещи, SVG-генератор) |
| `chest_{basic,premium,run,epic}_{closed,open}.png` (шов рисует код цветом лучшей редкости) | 320×240 | 🟨 (генератор) |
| `card_back.png` | 240×320 | 🟨 |

## 6. UI-иконки (`src/assets/ui/icons/*.svg`) — DS §02

SVG на сетке 24pt, мягкие формы, заливка + внутренний тёплый блик, без контура, белые/серые под `modulate`.

| Набор | Иконки | Статус |
|---|---|---|
| Вкладки | beacon, shop, skills (книга), gear (шлем) | 🟨 (рисуются кодом в `GlowTabBar`) |
| Валюты | spark (круг), crystal (ромб) | 🟨 |
| Навыки | 12 иконок навыков + 2 fallback (`src/assets/ui/skills`), 128px | 🟨 (SVG-генератор `tools/brand/make_skill_icons.py`) |
| Прочее | settings, close, info, play-ad ▶, lock, check, arrow | 🟨 |

## 7. Бренд и магазины (`src/assets/brand/`) — DS §07

| Файл | Размер | Статус |
|---|---|---|
| `mark.svg` — капля в тайле `ink.900`, r 28% | вектор | ✅ |
| `lockup_horizontal.svg`, варианты (основной / моно / на янтаре / инверсия) | вектор | ⬜ (надпись Unbounded: шрифт нужно установить для Inkscape; в игре надпись рисует S01) |
| `app_icon.png` (1024) — Огонёк с лицом (40% ширины, центр 52% Y), пара красных глаз слева вверху | 1024×1024 | ✅ |
| `app_icon_small.png` — без красных глаз (ниже 80px) | 1024×1024 | ✅ |
| Android adaptive: `android_fg.png`, `android_bg.png`, `android_mono.png` | 432×432 | ✅ |
| `splash.png` 1080×1920 (DS §07: знак на 36% высоты; надпись рисует S01) | 1080×1920 | ✅ |
| Скриншоты сторов: «1 против 1000», «Маяк: до/после» (Art Direction §01) | 1290×2796 / 1080×1920 | ⬜ |

## 8. VFX (`src/assets/vfx/`)

`ember.png`, `ash.png`, `spark_particle.png`, `droplet.png`, `shockwave_noise.png` (дисторсия Взрыва Света), `dissolve_noise.png` — 64–256px, серые под `modulate`. Статус: ⬜.

## 9. Аудио (`src/assets/audio/`) — DS §06

Звуки — `tools/audio/synth_sfx.py` (процедурный синтез, воспроизводимый), таблица событий — `configs/audio.json`. 21 SFX + 4 музыкальных слоя (хаб, база забега, ударные Напряжения, разрешение Награды). Статус: 🟨 — финальный звук от саунд-дизайнера заменяет `.ogg` с теми же именами.

## Чек-лист ревью ассета

1. **Силуэт в грейскейле:** читается на 50% размера; герой/Маяк — самое светлое пятно, враг — самое тёмное в своём радиусе.
2. **Цветовые законы:** тепло = жизнь и награда, красный = только угроза, голубой = только деньги (◆).
3. **Бюджет glow:** G1/G2/G3 по DS; не больше одного G3 на экране.
4. **Технически:** размер 2×, Linear, normal map у освещаемых, маска у врагов, имя по конвенции, импорт без mipmaps для UI.
5. **Никаких ассетов Kenney и пиксель-арта** (проверка: `grep -ri kenney src/` = 0).

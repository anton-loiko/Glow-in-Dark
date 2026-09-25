-- Генератор hi-res спрайтов Glow in the Dark для Aseprite (task_8 §1, docs/asset_specs.md).
-- Запуск через MCP aseprite run_script: dofile("<repo>/tools/art/gen_sprites.lua") с ROOT = путь к репо.
-- Каждый ассет: исходник .aseprite (кадры) в art/, горизонтальный лист альбедо, normal map (_n, OpenGL: X+ вправо,
-- Y+ вверх) из карты высот и маска (_mask: R — глаза, G — трещины/растворение) в src/assets/.
-- Формы задаются полями расстояний (SDF), поэтому ассеты воспроизводимы и масштабируемы.

local ROOT = ROOT or "."
local pc = app.pixelColor
-- Масштаб нормалей врагов: купол высотой 1 на 16–60 px даёт почти плоские нормали без усиления.
local ENEMY_NORMAL_STRENGTH = 28

-- ---------------------------------------------------------------- математика
local function clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end
local function smoothstep(a, b, x) local t = clamp((x - a) / (b - a), 0, 1) return t * t * (3 - 2 * t) end
local function lerp(a, b, t) return a + (b - a) * t end
local function len(x, y) return math.sqrt(x * x + y * y) end
local function smin(a, b, k) local h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1) return lerp(b, a, h) - k * h * (1 - h) end
local function sd_circle(x, y, cx, cy, r) return len(x - cx, y - cy) - r end
local function sd_ellipse(x, y, cx, cy, rx, ry) -- приближённое SDF эллипса
  local dx, dy = (x - cx) / rx, (y - cy) / ry
  local k = len(dx, dy)
  return (k - 1) * math.min(rx, ry)
end
-- детерминированный шум
local function hash(x, y, s) local n = math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453 return n - math.floor(n) end
local function vnoise(x, y, s)
  local ix, iy = math.floor(x), math.floor(y)
  local fx, fy = x - ix, y - iy
  local ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
  local a, b = hash(ix, iy, s), hash(ix + 1, iy, s)
  local c, d = hash(ix, iy + 1, s), hash(ix + 1, iy + 1, s)
  return lerp(lerp(a, b, ux), lerp(c, d, ux), uy)
end
local function fbm(x, y, s) local v, a = 0, 0.5 for i = 1, 4 do v = v + a * vnoise(x, y, s + i) x, y, a = x * 2, y * 2, a * 0.5 end return v end

-- ---------------------------------------------------------------- рендер
-- shape(x, y, frame) → sdf, extra; extra.eyes (0..1), extra.albedo {r,g,b} (0..1), extra.relief (0..1 доп. рельеф)
local function render(w, h, frames, shape)
  local sheet = Image(w * frames, h, ColorMode.RGB)
  local nmap = Image(w * frames, h, ColorMode.RGB)
  local mask = Image(w * frames, h, ColorMode.RGB)
  local frame_images = {}
  for f = 0, frames - 1 do
    local height = {}
    local cells = {}
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local d, e = shape(x + 0.5, y + 0.5, f)
        local a = clamp(0.5 - d, 0, 1)
        local hh = 0
        if e.height_override ~= nil then hh = e.height_override
        elseif d < 0 then hh = math.sqrt(clamp(-d / (e.dome or 20), 0, 1)) + (e.relief or 0) * 0.35 end
        height[y * w + x] = hh
        cells[y * w + x] = { a = a, e = e }
      end
    end
    local img = Image(w, h, ColorMode.RGB)
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local c = cells[y * w + x]
        local idx = y * w + x
        local ox = f * w + x
        if c.a > 0 then
          local col = c.e.albedo or { 0.05, 0.05, 0.08 }
          local px = pc.rgba(math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255), math.floor(c.a * 255))
          sheet:drawPixel(ox, y, px)
          img:drawPixel(x, y, px)
          local hl = height[idx - (x > 0 and 1 or 0)] or 0
          local hr = height[idx + (x < w - 1 and 1 or 0)] or 0
          local hu = height[idx - (y > 0 and w or 0)] or 0
          local hd = height[idx + (y < h - 1 and w or 0)] or 0
          local k = c.e.normal_strength or ENEMY_NORMAL_STRENGTH
          local nx, ny, nz = -(hr - hl) * k, (hd - hu) * k, 1
          local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
          nmap:drawPixel(ox, y, pc.rgba(math.floor((nx / nl * 0.5 + 0.5) * 255), math.floor((ny / nl * 0.5 + 0.5) * 255), math.floor((nz / nl * 0.5 + 0.5) * 255), math.floor(c.a * 255)))
          mask:drawPixel(ox, y, pc.rgba(math.floor(clamp(c.e.eyes or 0, 0, 1) * 255), math.floor(clamp(c.e.cracks or 0, 0, 1) * 255), 0, math.floor(c.a * 255)))
        end
      end
    end
    frame_images[f + 1] = img
  end
  return sheet, nmap, mask, frame_images
end

local function ensure_dir(path) app.fs.makeAllDirectories(path) end

local function save_asset(dir, name, w, h, frames, shape, with_mask)
  local sheet, nmap, mask, imgs = render(w, h, frames, shape)
  ensure_dir(ROOT .. "/" .. dir)
  ensure_dir(ROOT .. "/art")
  sheet:saveAs(ROOT .. "/" .. dir .. "/" .. name .. ".png")
  nmap:saveAs(ROOT .. "/" .. dir .. "/" .. name .. "_n.png")
  if with_mask then mask:saveAs(ROOT .. "/" .. dir .. "/" .. name .. "_mask.png") end
  -- Исходник с кадрами для ручной доработки художником.
  local spr = Sprite(w, h, ColorMode.RGB)
  for i = 2, frames do spr:newEmptyFrame() end
  for i = 1, frames do spr:newCel(spr.layers[1], spr.frames[i], imgs[i], Point(0, 0)) end
  spr:saveAs(ROOT .. "/art/" .. name .. ".aseprite")
  spr:close()
  print("wrote " .. dir .. "/" .. name .. " " .. (w * frames) .. "x" .. h)
end

-- ---------------------------------------------------------------- враги (Enemy DS §09)
-- Тело темнее тьмы: сине-фиолетовый почти чёрный, лёгкий холодный блик по рельефу; трещины — маска G.
local BODY = { 0.045, 0.04, 0.075 }
local function body_col(relief) local t = relief * 0.5 return { BODY[1] + t * 0.06, BODY[2] + t * 0.05, BODY[3] + t * 0.1 } end
local function cracks_at(x, y, s, scale)
  local n = fbm(x / scale, y / scale, s)
  return smoothstep(0.035, 0.0, math.abs(n - 0.5))
end

-- Шёпот S (72px): дымная капля с рваным хвостом; движение — колыхание хвоста.
local function whisper(x, y, f)
  local t = f / 6 * math.pi * 2
  local cx, cy = 36, 30
  local d = sd_circle(x, y, cx, cy, 20)
  for i = 0, 2 do
    local sway = math.sin(t + i * 1.7) * 4
    d = smin(d, sd_ellipse(x, y, cx - 10 + i * 10 + sway, cy + 22 + i % 2 * 3, 6, 12), 8)
  end
  local wobble = (fbm(x / 9 + f * 0.3, y / 9, 3) - 0.5) * 5
  d = d + wobble
  local relief = fbm(x / 7, y / 7, 5)
  return d, { albedo = body_col(relief), relief = relief * 0.3, dome = 16, cracks = cracks_at(x, y, 11, 14) * smoothstep(0, -6, d), eyes = 0 }
end

-- Жнец M (128px): капюшон с тёмным провалом лица, рваный подол, коса у бока; движение — волна по подолу.
local function reaper(x, y, f)
  local t = f / 6 * math.pi * 2
  local cx = 60
  local hood = sd_ellipse(x, y, cx, 44, 26, 30)
  local d = smin(hood, sd_ellipse(x, y, cx, 80, 32, 32), 16)
  local tatter = math.sin((x / 7) + t) * 6 + (fbm(x / 6, f, 9) - 0.5) * 10
  d = math.max(d, y - (110 + tatter))
  -- коса: древко и лезвие справа
  local shaft = math.max(math.abs((x - 96) + (y - 70) * 0.18) - 2.2, math.abs(y - 72) - 44)
  local blade = math.max(sd_circle(x, y, 104, 34, 20), -sd_circle(x, y, 110, 42, 19))
  blade = math.max(blade, x - 124)
  d = math.min(d, math.min(shaft, blade))
  local face = sd_ellipse(x, y, cx + 2, 46, 15, 17)
  local relief = fbm(x / 10, y / 10, 21)
  local col = body_col(relief)
  if face < 0 then col = { 0.012, 0.01, 0.02 } end
  return d, { albedo = col, relief = relief * 0.4 - smoothstep(4, -8, face) * 0.5, dome = 24, cracks = cracks_at(x, y, 23, 20) * smoothstep(0, -8, d), eyes = 0 }
end

-- Пожиратель L (224px): сгорбленная туша с пастью; движение — дыхание.
local function devourer(x, y, f)
  local breath = 1 + math.sin(f / 6 * math.pi * 2) * 0.03
  local cx, cy = 112, 120
  local d = sd_ellipse(x, y, cx, cy, 88 * breath, 72 * breath)
  d = smin(d, sd_ellipse(x, y, cx - 50, cy - 42, 34, 30), 24)
  d = smin(d, sd_ellipse(x, y, cx + 46, cy - 48, 30, 28), 24)
  d = smin(d, sd_ellipse(x, y, cx, cy + 58, 70, 30), 20)
  local maw = sd_ellipse(x, y, cx, cy + 22, 44, 14 * breath)
  local relief = fbm(x / 14, y / 14, 31)
  local maw_edge = smoothstep(6, 0, math.abs(maw))
  d = d + (fbm(x / 18, y / 18, 33) - 0.5) * 8
  local col = body_col(relief)
  if maw < 0 then col = { 0.02, 0.01, 0.03 } end
  return d, { albedo = col, relief = relief * 0.5 - maw_edge * 0.3, dome = 50, cracks = cracks_at(x, y, 37, 26) * smoothstep(0, -10, d), eyes = 0 }
end

-- Гаситель XL (320px): высокий плащ-колонна с венцом шипов; движение — медленный пульс венца.
local function extinguisher(x, y, f)
  local pulse = 1 + math.sin(f / 8 * math.pi * 2) * 0.04
  local cx = 160
  local d = sd_ellipse(x, y, cx, 190, 70, 118)
  d = smin(d, sd_ellipse(x, y, cx, 92, 46, 50), 30)
  -- венец шипов
  for i = 0, 8 do
    local a = math.pi * (0.1 + i * 0.1)
    local sx, sy = cx + math.cos(a + math.pi) * 64 * pulse, 88 - math.sin(a) * 64 * pulse
    local spike = sd_ellipse(x, y, sx, sy, 6, 22)
    d = smin(d, spike, 10)
  end
  -- рваный край плаща
  d = math.max(d, y - (300 + math.sin(x / 9) * 8 + (fbm(x / 7, 1, 41) - 0.5) * 14))
  d = d + (fbm(x / 20, y / 20, 43) - 0.5) * 6
  local relief = fbm(x / 16, y / 16, 45)
  return d, { albedo = body_col(relief * 1.2), relief = relief * 0.5, dome = 60, cracks = cracks_at(x, y, 47, 30) * smoothstep(0, -12, d), eyes = 0 }
end

-- Плакальщик M (за флагом): сгорбленная фигура с «слезой».
local function mourner(x, y, f)
  local t = f / 6 * math.pi * 2
  local cx = 64
  local d = sd_ellipse(x, y, cx, 70, 28, 44)
  d = smin(d, sd_circle(x, y, cx - 4, 36 + math.sin(t) * 2, 20), 12)
  d = math.max(d, y - (112 + math.sin(x / 6 + t) * 5))
  local relief = fbm(x / 9, y / 9, 51)
  return d, { albedo = body_col(relief), relief = relief * 0.3, dome = 24, cracks = cracks_at(x, y, 53, 18) * smoothstep(0, -8, d), eyes = 0 }
end

-- ---------------------------------------------------------------- Огонёк
-- Тело белое с мягкой светотенью: цвет скина даёт modulate. Ядро и глаза — отдельные слои.
local function hero_body(x, y, f)
  local cx, cy, r = 85, 104, 50
  local d = sd_circle(x, y, cx, cy, r)
  -- короткое мягкое острие капли
  local tip = math.max(sd_ellipse(x, y, cx, cy - 34, 22, 44), -(y - (cy - 76)))
  d = smin(d, tip, 16)
  local shade = 0.86 + 0.14 * smoothstep(40, -50, len(x - cx + 16, y - cy + 20) - 16)
  return d, { albedo = { shade, shade, shade }, relief = 0, dome = 40, normal_strength = 3 }
end

local function hero_core(x, y, f)
  local d = sd_ellipse(x, y, 85, 110, 24, 22)
  local glow = smoothstep(0, -18, d)
  local v = 0.92 + 0.08 * glow
  return d - 4, { albedo = { 1.0, 0.99 * v, 0.96 * v }, dome = 16, normal_strength = 0.5 }
end

-- Эмоции глаз: calm (овалы), focused (прищур), scared (большие), happy (дуги).
local function hero_eyes(kind)
  return function(x, y, f)
    local d = 99
    for _, sx in ipairs({ -1, 1 }) do
      local ex, ey = 85 + sx * 19, 106
      local e
      if kind == "calm" then e = sd_ellipse(x, y, ex, ey, 9, 12)
      elseif kind == "focused" then e = sd_ellipse(x, y, ex, ey + 2, 10, 5)
      elseif kind == "scared" then e = sd_ellipse(x, y, ex, ey, 12, 15)
      else e = math.max(math.abs(sd_circle(x, y, ex, ey + 8, 11)) - 3, -(ey + 6 - y)) end
      d = math.min(d, e)
    end
    local shine = 99
    if kind ~= "happy" then
      for _, sx in ipairs({ -1, 1 }) do shine = math.min(shine, sd_circle(x, y, 85 + sx * 19 + 3, 101, 3.2)) end
    end
    local col = { 0.027, 0.035, 0.06 }
    if shine < 0 then col = { 1, 0.99, 0.96 } end
    return d, { albedo = col, dome = 6, normal_strength = 0.2 }
  end
end


-- ---------------------------------------------------------------- мир (тонируется цветом главы через modulate)
-- Бесшовная брусчатка: ячейки Вороного на торе (координаты по модулю размера), камни — купола, швы — низины,
-- лужи — гладкие тёмные пятна. Серый альбедо ~0.4–0.6: цвет пола задаёт палитра главы.
local function voronoi_tile(size, cells, seed)
  local pts = {}
  for i = 1, cells do pts[i] = { hash(i, 1, seed) * size, hash(i, 2, seed) * size } end
  return function(x, y)
    local d1, d2, id = 1e9, 1e9, 0
    for i = 1, cells do
      for ox = -1, 1 do
        for oy = -1, 1 do
          local dx, dy = x - (pts[i][1] + ox * size), y - (pts[i][2] + oy * size)
          local d = dx * dx + dy * dy
          if d < d1 then d2 = d1 d1 = d id = i elseif d < d2 then d2 = d end
        end
      end
    end
    return math.sqrt(d2) - math.sqrt(d1), id
  end
end

local function floor_tile(seed)
  local size = 128
  local vor = voronoi_tile(size, 14, seed)
  return function(x, y, f)
    local edge, id = vor(x, y)
    local stone = smoothstep(1.5, 7, edge)
    local tone = 0.42 + hash(id, 7, seed) * 0.16 + (fbm(x / 6, y / 6, seed + 3) - 0.5) * 0.12
    local puddle = smoothstep(0.62, 0.7, fbm(x / 40 + seed, y / 40, seed + 9))
    local v = lerp(0.18, tone, stone)
    v = lerp(v, 0.14, puddle * 0.85)
    local relief = stone * (0.6 + 0.4 * fbm(x / 5, y / 5, seed + 5)) * (1 - puddle)
    return -1, { albedo = { v, v * 1.02, v * 1.06 }, relief = relief, dome = 1, normal_strength = 6, height_override = relief }
  end
end

-- Проп «плита»: скошенные края, трещины; «обломки»: груда камней.
local function prop_slab(x, y, f)
  local size, m = 256, 10
  local dx, dy = math.min(x, size - x), math.min(y, size - y)
  local bevel = smoothstep(0, 22, math.min(dx, dy))
  local crack = cracks_at(x, y, 61, 40)
  local v = 0.38 + (fbm(x / 9, y / 9, 63) - 0.5) * 0.14 - crack * 0.18
  return -1, { albedo = { v, v, v * 1.05 }, relief = bevel * (1 - crack * 0.6), normal_strength = 5, height_override = bevel * (1 - crack * 0.6) }
end

local rubble_vor = voronoi_tile(256, 9, 71)
local function prop_rubble(x, y, f)
  local edge, id = rubble_vor(x, y)
  local rock = smoothstep(2, 16, edge)
  local v = 0.30 + hash(id, 3, 71) * 0.18 + (fbm(x / 7, y / 7, 73) - 0.5) * 0.1
  return -1, { albedo = { v, v, v * 1.04 }, relief = rock, normal_strength = 7, height_override = rock }
end

-- ---------------------------------------------------------------- запуск
local only = ONLY
local function want(name) return only == nil or only == name end
if want("enemies") then
  save_asset("src/assets/enemies/whisper", "whisper", 72, 72, 6, whisper, true)
  save_asset("src/assets/enemies/reaper", "reaper", 128, 128, 6, reaper, true)
  save_asset("src/assets/enemies/devourer", "devourer", 224, 224, 6, devourer, true)
  save_asset("src/assets/enemies/extinguisher", "extinguisher", 320, 320, 8, extinguisher, true)
  save_asset("src/assets/enemies/mourner", "mourner", 128, 128, 6, mourner, true)
end
if want("world") then
  for i = 1, 4 do save_asset("src/assets/world/common", "floor_" .. i, 128, 128, 1, floor_tile(100 + i * 17), false) end
  save_asset("src/assets/world/common", "prop_slab", 256, 256, 1, prop_slab, false)
  save_asset("src/assets/world/common", "prop_rubble", 256, 256, 1, prop_rubble, false)
end
if want("hero") then
  save_asset("src/assets/hero", "hero_body", 170, 170, 1, hero_body, false)
  save_asset("src/assets/hero", "hero_core", 170, 170, 1, hero_core, false)
  for _, kind in ipairs({ "calm", "focused", "scared", "happy" }) do
    save_asset("src/assets/hero", "hero_eyes_" .. kind, 170, 170, 1, hero_eyes(kind), false)
  end
end

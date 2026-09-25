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
          local hl = height[idx - (x > 0 and 1 or 0)] or 0
          local hr = height[idx + (x < w - 1 and 1 or 0)] or 0
          local hu = height[idx - (y > 0 and w or 0)] or 0
          local hd = height[idx + (y < h - 1 and w or 0)] or 0
          local k = c.e.normal_strength or ENEMY_NORMAL_STRENGTH
          local nx, ny, nz = -(hr - hl) * k, (hd - hu) * k, 1
          local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
          if c.e.bake then
            -- UI-ассет: свет сверху-слева (OpenGL: Y+ вверх), мягкий спекуляр, эмиссия не затемняется.
            local lx, ly, lz = -0.45, 0.55, 0.7
            local ndl = math.max(0, (nx * lx + ny * ly + nz * lz) / nl)
            local spec = math.max(0, (nz / nl) * 0.2 + ndl - 0.85) * 1.6
            local em = c.e.emission or 0
            local k = lerp(0.35 + 0.8 * ndl, 1, em)
            col = { clamp(col[1] * k + spec * 0.25, 0, 1), clamp(col[2] * k + spec * 0.22, 0, 1), clamp(col[3] * k + spec * 0.18, 0, 1) }
          end
          local px = pc.rgba(math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255), math.floor(c.a * 255))
          sheet:drawPixel(ox, y, px)
          img:drawPixel(x, y, px)
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

local function save_asset(dir, name, w, h, frames, shape, with_mask, baked)
  local sheet, nmap, mask, imgs = render(w, h, frames, shape)
  ensure_dir(ROOT .. "/" .. dir)
  ensure_dir(ROOT .. "/art")
  sheet:saveAs(ROOT .. "/" .. dir .. "/" .. name .. ".png")
  if not baked then nmap:saveAs(ROOT .. "/" .. dir .. "/" .. name .. "_n.png") end -- UI с запечённым светом нормали не нужны
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


-- ---------------------------------------------------------------- Маяк (Meta DS §01), UI: свет запечён
local STONE = { 0.24, 0.26, 0.32 }
local RUNE = { 1.0, 0.906, 0.69 }
local GOLD = { 0.72, 0.38, 0.1 }
local function stone_col(x, y, s)
  local v = (fbm(x / 8, y / 8, s) - 0.5) * 0.1
  return { STONE[1] + v, STONE[2] + v, STONE[3] + v * 1.2 }
end

-- Постамент 320×160: ступенчатая плита; kind — ruins | cracked | runes | armored | radiant.
local function pedestal(kind)
  return function(x, y, f)
    local cx = 160
    local top = sd_ellipse(x, y, cx, 92, 108, 26)
    local body = math.max(math.abs(x - cx) - 120 + (y - 92) * 0.12, math.abs(y - 118) - 30)
    local d = smin(top, body, 8)
    local e = { albedo = stone_col(x, y, 81), dome = 30, normal_strength = 14, bake = true }
    if kind == "ruins" then
      -- груда обломков: несколько камней вместо плиты
      d = 99
      for i = 0, 6 do
        local rx, ry = 40 + i * 40 + (hash(i, 1, 83) - 0.5) * 20, 120 + (hash(i, 2, 83) - 0.5) * 18
        d = math.min(d, sd_ellipse(x, y, rx, ry, 22 + hash(i, 3, 83) * 14, 14 + hash(i, 4, 83) * 10))
      end
      d = d + (fbm(x / 6, y / 6, 85) - 0.5) * 6
      e.dome = 14
      return d, e
    end
    local crack = cracks_at(x, y, 87, 24) * smoothstep(0, -6, d)
    if kind == "cracked" then
      e.albedo = { e.albedo[1] * (1 - crack * 0.6), e.albedo[2] * (1 - crack * 0.6), e.albedo[3] * (1 - crack * 0.6) }
      e.relief = -crack
    end
    if kind == "runes" or kind == "armored" or kind == "radiant" then
      -- 4 гравированные руны на лицевой грани, светятся янтарно-белым
      for i = 0, 3 do
        local rd = sd_circle(x, y, cx - 66 + i * 44, 124, 7)
        if rd < 0 then e.albedo = RUNE e.emission = 1 end
      end
    end
    if kind == "armored" or kind == "radiant" then
      -- металлические пояса
      local band = math.min(math.abs(y - 104), math.abs(y - 140))
      if band < 3.5 and body < 0 then
        e.albedo = kind == "radiant" and GOLD or { 0.42, 0.45, 0.52 }
        e.relief = 0.4
      end
    end
    if kind == "radiant" and top < 0 and top > -5 then e.albedo = { 1.0, 0.82, 0.5 } e.emission = 0.8 end
    return d, e
  end
end

-- Кристалл 96×160: огранённый ромб; кадры — поворот вокруг оси (ширина по cos). shards — 3 осколка.
local function crystal(kind)
  local base = ({ dim = { 0.35, 0.3, 0.26 }, bright = { 1.0, 0.8, 0.45 }, white = { 1.0, 0.98, 0.92 } })[kind]
  local em = ({ dim = 0.15, bright = 0.85, white = 1.0 })[kind]
  return function(x, y, f)
    if kind == "shards" then
      -- три наклонённых осколка-ромба у подножия
      local d = 99
      local shards = { { 26, 132, 9, 22, -0.35 }, { 50, 124, 11, 30, 0.1 }, { 73, 134, 8, 19, 0.45 } }
      for _, sh in ipairs(shards) do
        local ca, sa = math.cos(sh[5]), math.sin(sh[5])
        local dx, dy = x - sh[1], y - sh[2]
        local rx, ry = dx * ca + dy * sa, -dx * sa + dy * ca
        d = math.min(d, (math.abs(rx) / sh[3] + math.abs(ry) / sh[4] - 1) * math.min(sh[3], sh[4]))
      end
      return d, { albedo = { 0.32, 0.29, 0.27 }, dome = 6, normal_strength = 8, bake = true }
    end
    local turn = math.cos(f / 12 * math.pi * 2)
    local w = 36 * (0.55 + 0.45 * math.abs(turn))
    local cx, top, mid, bot = 48, 8, 62, 152
    local d
    if y < mid then d = math.abs(x - cx) - w * (y - top) / (mid - top) else d = math.abs(x - cx) - w * (bot - y) / (bot - mid) end
    d = math.max(d, top - y, y - bot)
    -- грань: светлая сторона смещается с поворотом
    local facet = (x - cx) / math.max(1, w) * turn
    local k = 0.8 + 0.35 * facet
    local col = { clamp(base[1] * k, 0, 1), clamp(base[2] * k, 0, 1), clamp(base[3] * k, 0, 1) }
    return d, { albedo = col, dome = 18, normal_strength = 6, bake = true, emission = em }
  end
end

-- ---------------------------------------------------------------- Сундуки (Gear DS §03), 320×240
-- closed/open: у открытого крышка откинута назад и изнутри льётся свет (шов рисует код цветом лучшей редкости).
local CHESTS = {
  basic = { body = { 0.36, 0.22, 0.12 }, band = { 0.3, 0.32, 0.36 }, trim = { 1.0, 0.71, 0.28 } },
  premium = { body = { 0.08, 0.1, 0.16 }, band = { 0.2, 0.62, 0.7 }, trim = { 0.44, 0.89, 0.94 } },
  run = { body = { 0.22, 0.23, 0.26 }, band = { 0.32, 0.34, 0.38 }, trim = { 0.56, 0.6, 0.67 } },
  epic = { body = { 0.24, 0.12, 0.34 }, band = { 0.72, 0.38, 0.1 }, trim = { 0.83, 0.69, 1.0 } },
}
local function chest(kind, open)
  local c = CHESTS[kind]
  return function(x, y, f)
    local body = math.max(math.abs(x - 160) - 118, math.abs(y - 168) - 58)
    local lid
    if open then
      lid = math.max(math.abs(x - 160) - 112, math.abs(y - 62) - 18) -- откинута назад, видна тонкой полосой
    else
      lid = math.max(sd_ellipse(x, y, 160, 112, 124, 52), y - 112)
    end
    local d = math.min(body - 2, lid)
    local col = c.body
    local wood = (fbm(x / 30, y / 4, 91) - 0.5) * 0.12
    col = { col[1] + wood, col[2] + wood * 0.8, col[3] + wood * 0.6 }
    local e = { dome = 26, normal_strength = 10, bake = true }
    -- металлические пояса и уголки
    local band = math.min(math.abs(x - 90), math.abs(x - 230))
    if band < 9 then col = c.band e.relief = 0.3 end
    local corner = math.min(len(x - 46, y - 222), len(x - 274, y - 222))
    if corner < 14 then col = c.band end
    -- замок
    if math.abs(x - 160) < 14 and math.abs(y - 128) < 16 then col = c.trim e.emission = kind == "premium" and 0.9 or 0.3 end
    -- неоновые кромки премиума
    if kind == "premium" and d < 0 and d > -3 then col = c.trim e.emission = 1 end
    -- открытый: внутренность — тёплое свечение из проёма
    if open and body < 0 and y < 124 then col = { 1.0, 0.85, 0.55 } e.emission = 1 end
    e.albedo = { clamp(col[1], 0, 1), clamp(col[2], 0, 1), clamp(col[3], 0, 1) }
    return d, e
  end
end


-- ---------------------------------------------------------------- VFX и биолюминесценция (unshaded, белые под modulate)
-- Уголёк: мягкое ядро с ореолом. Пепел: рваная хлопья. Искра: четырёхлучевая звезда.
local function ember(x, y, f)
  local r = len(x - 16, y - 16)
  local a = smoothstep(16, 2, r)
  local core = smoothstep(6, 0, r)
  local v = 0.75 + 0.25 * core
  return 0.5 - a, { albedo = { v, v, v }, dome = 1, normal_strength = 0 } -- альфа = мягкий спад
end

local function ash(x, y, f)
  local d = sd_ellipse(x, y, 16, 16, 11, 7) + (fbm(x / 3, y / 3, 101) - 0.5) * 8
  local v = 0.55 + (fbm(x / 2, y / 2, 103) - 0.5) * 0.3
  return d, { albedo = { v, v, v }, dome = 3, normal_strength = 0 }
end

local function spark_star(x, y, f)
  local dx, dy = math.abs(x - 16), math.abs(y - 16)
  local d = math.min(dx * 3.2 + dy, dy * 3.2 + dx) - 14
  local core = smoothstep(5, 0, len(dx, dy))
  local v = 0.85 + 0.15 * core
  return d, { albedo = { v, v, v }, dome = 1, normal_strength = 0 }
end

-- Грибы биолюминесценции: 2–3 шляпки на ножках, светятся шляпки (цвет главы — modulate, не красный/янтарный).
local function mushrooms(seed)
  return function(x, y, f)
    local d, glow = 99, 0
    for i = 0, 2 do
      local mx = 20 + i * 12 + (hash(i, 1, seed) - 0.5) * 6
      local h = 18 + hash(i, 2, seed) * 16
      local cap_r = 7 + hash(i, 3, seed) * 5
      local stem = math.max(math.abs(x - mx) - 1.6, math.abs(y - (60 - h * 0.5)) - h * 0.5)
      local cap = math.max(sd_ellipse(x, y, mx, 60 - h, cap_r, cap_r * 0.6), y - (60 - h + 1))
      d = math.min(d, stem, cap)
      if cap < 0 then glow = 1 end
    end
    local v = glow > 0 and 1.0 or 0.55
    return d, { albedo = { v, v, v }, dome = 3, normal_strength = 0 }
  end
end

-- Руна: светящийся знак на камне (кольцо + засечки).
local function rune(x, y, f)
  local r = len(x - 24, y - 24)
  local ring = math.abs(r - 15) - 1.8
  local bar = math.max(math.abs(x - 24) - 1.6, math.abs(y - 24) - 11)
  local tick = math.max(math.abs(y - 16) - 1.6, math.abs(x - 24) - 7)
  local d = math.min(ring, bar, tick)
  return d, { albedo = { 1, 1, 1 }, dome = 2, normal_strength = 0 }
end


-- ---------------------------------------------------------------- Хаб-диорама главы 1 «Затопленный город» (780×1100)
-- Непрозрачный фон: небо → дальний и ближний кварталы с окнами → мост → вода с отражениями → островок Маяка.
-- Свет запечён мягко; проявление светом хаба делает шейдер hub_reveal (за радиусом — силуэты во тьме).
local function skyline(x, cell, base, span, seed)
  local i = math.floor(x / cell)
  local h = base - hash(i, 1, seed) * span
  local spire = hash(i, 2, seed) > 0.82 and 40 or 0
  local lx = x - i * cell
  local roof = h
  if spire > 0 and math.abs(lx - cell * 0.5) < cell * 0.12 then roof = h - spire end
  return roof, i, lx
end

local function hub_city(x, y, f)
  local sky = lerp(0.03, 0.075, y / 700)
  local col = { sky * 0.85, sky * 0.95, sky * 1.35 }
  -- дальний квартал
  local far_roof, fi, flx = skyline(x, 46, 470, 190, 201)
  if y > far_roof and y < 820 then
    local v = 0.085 + hash(fi, 3, 201) * 0.03
    col = { v * 0.9, v * 0.95, v * 1.2 }
    local wx, wy = flx % 12, (y - far_roof) % 18
    if wx > 4 and wx < 9 and wy > 6 and wy < 12 and hash(math.floor(x / 12), math.floor(y / 18), 205) > 0.78 then
      col = { 0.36, 0.48, 0.52 } -- редкие холодные окна (тёплый свет — только Маяк)
    end
  end
  -- ближний квартал
  local mid_roof, mi, mlx = skyline(x + 23, 104, 640, 170, 211)
  if y > mid_roof and y < 840 then
    local v = 0.055 + hash(mi, 3, 211) * 0.025
    col = { v * 0.9, v * 0.95, v * 1.15 }
    -- арки нижних этажей, залитых водой
    local ax = mlx % 52
    if y > 760 and math.abs(ax - 26) < 14 and y - 760 > (14 - math.abs(ax - 26)) * 0.4 then col = { 0.02, 0.025, 0.04 } end
    local wx, wy = mlx % 20, (y - mid_roof) % 26
    if wx > 7 and wx < 14 and wy > 8 and wy < 17 and hash(math.floor((x + 23) / 20), math.floor(y / 26), 215) > 0.8 then
      col = { 0.3, 0.42, 0.46 }
    end
  end
  -- мост через канал
  local deck = math.abs(y - 730) < 7 and x > 60 and x < 720
  local arch = y > 737 and y < 800 and math.abs(((x - 60) % 110) - 55) < 6
  if deck or arch then col = { 0.07, 0.075, 0.1 } end
  -- вода с рябью и отражением кварталов
  if y >= 820 then
    local ry = 820 - (y - 820) * 0.8
    local refl_roof = skyline(x + 23 + math.sin(y * 0.15) * 4, 104, 640, 170, 211)
    local ripple = (vnoise(x / 40, y / 3, 221) - 0.5) * 0.02
    local w = 0.035 + ripple
    col = { w * 0.8, w * 1.0, w * 1.4 }
    if ry > refl_roof then col = { col[1] + 0.02, col[2] + 0.022, col[3] + 0.03 } end
  end
  -- островок Маяка
  local island = sd_ellipse(x, y, 390, 880, 190, 46)
  if island < 0 then
    local v = 0.16 + (fbm(x / 10, y / 10, 231) - 0.5) * 0.06 + smoothstep(-20, -46, island) * 0.03
    col = { v * 0.95, v, v * 1.1 }
  end
  return -1, { albedo = { clamp(col[1], 0, 1), clamp(col[2], 0, 1), clamp(col[3], 0, 1) }, height_override = 0, normal_strength = 0 }
end


-- ---------------------------------------------------------------- Биомы глав 2–3 (серый альбедо, тон главы — modulate)
-- Спящий лес: земля, пятна мха, корни (гребни шума), опавшие листья.
-- Бесшовный fbm на тайле T: четыре выборки со сдвигом на период, билинейное смешивание.
local function tiled_fbm(x, y, T, sc, s)
  local wx, wy = x / T, y / T
  local a = fbm(x / sc, y / sc, s)
  local b = fbm((x + T) / sc, y / sc, s)
  local c = fbm(x / sc, (y + T) / sc, s)
  local d = fbm((x + T) / sc, (y + T) / sc, s)
  -- в точке x = 0 вес у выборки со сдвигом +T, при x = T — у несдвинутой: края совпадают
  return lerp(lerp(b, a, wx), lerp(d, c, wx), wy)
end

local function forest_floor(seed)
  return function(x, y, f)
    local T = 128
    local earth = 0.38 + (tiled_fbm(x, y, T, 9, seed) - 0.5) * 0.16
    local moss = smoothstep(0.52, 0.62, tiled_fbm(x, y, T, 22, seed + 5))
    local root = smoothstep(0.03, 0.0, math.abs(tiled_fbm(x, y, T, 30, seed + 9) - 0.5)) * (1 - moss)
    local leaf = hash(math.floor(x / 5) % 26, math.floor(y / 5) % 26, seed) > 0.93 and 1 or 0
    local v = lerp(earth, 0.5, moss * 0.6)
    v = lerp(v, 0.3, root * 0.7) + leaf * 0.08
    local relief = moss * 0.5 + root * 0.8 + leaf * 0.2
    return -1, { albedo = { v * 0.95, v * 1.05, v * 0.9 }, height_override = relief, normal_strength = 6 }
  end
end

-- Ржавый порт: клёпаные стальные листы 2×2 на тайл, швы, пятна ржавчины.
local function port_floor(seed)
  return function(x, y, f)
    local px, py = x % 64, y % 64
    local seam = math.min(px, 64 - px, py, 64 - py)
    local plate = smoothstep(0.5, 3, seam)
    local rivet = 0
    for _, c in ipairs({ { 6, 6 }, { 58, 6 }, { 6, 58 }, { 58, 58 } }) do
      if len(px - c[1], py - c[2]) < 2.6 then rivet = 1 end
    end
    local rust = smoothstep(0.55, 0.7, tiled_fbm(x, y, 128, 18, seed + 3))
    local scratches = smoothstep(0.02, 0.0, math.abs(tiled_fbm(x, y, 128, 6, seed + 7) - 0.5)) * 0.4
    local v = 0.44 + (tiled_fbm(x, y, 128, 7, seed) - 0.5) * 0.08 - scratches * 0.1
    local col = { v, v * 1.01, v * 1.05 }
    if rust > 0 then col = { lerp(col[1], 0.5, rust), lerp(col[2], 0.33, rust), lerp(col[3], 0.24, rust) } end
    local relief = plate * 0.5 + rivet * 0.9 - rust * 0.1
    return -1, { albedo = col, height_override = relief, normal_strength = 7 }
  end
end

local function prop_stump(x, y, f)
  local r = len(x - 128, y - 128)
  local ring = 0.5 + 0.5 * math.sin(r * 0.55 + fbm(x / 20, y / 20, 301) * 4)
  local bark = smoothstep(96, 112, r)
  local v = lerp(0.42 + ring * 0.08, 0.26, bark)
  return r - 120, { albedo = { v * 1.05, v * 0.95, v * 0.8 }, height_override = smoothstep(122, 90, r) * (0.8 + ring * 0.1), normal_strength = 6 }
end

local function prop_boulder(x, y, f)
  local d = sd_ellipse(x, y, 128, 132, 116, 102) + (fbm(x / 14, y / 14, 311) - 0.5) * 30
  local moss = smoothstep(0.5, 0.6, fbm(x / 18, y / 18, 313)) * smoothstep(40, -60, y - 128)
  local v = 0.36 + (fbm(x / 8, y / 8, 317) - 0.5) * 0.1
  return d, { albedo = { v * (1 - moss * 0.1), v * (1 + moss * 0.25), v * (1 - moss * 0.15) }, height_override = math.sqrt(clamp(-d / 90, 0, 1)), normal_strength = 7 }
end

local function prop_crate(x, y, f)
  local px, py = math.abs(x - 128), math.abs(y - 128)
  local frame = (px > 104 or py > 104) and 1 or 0
  local diag = smoothstep(9, 5, math.abs((x - 128) - (y - 128)) / 1.414) * (1 - frame)
  local plank = (math.floor(y / 32) % 2) * 0.04
  local v = 0.44 + plank + (fbm(x / 40, y / 4, 321) - 0.5) * 0.1 + frame * 0.05 + diag * 0.05
  return math.max(px, py) - 124, { albedo = { v * 1.05, v * 0.92, v * 0.75 }, height_override = 0.4 + frame * 0.4 + diag * 0.3, normal_strength = 6 }
end

local function prop_container(x, y, f)
  local rib = 0.5 + 0.5 * math.cos(x / 256 * math.pi * 2 * 12)
  local rust = smoothstep(0.55, 0.72, fbm(x / 24, y / 24, 331))
  local v = 0.4 + rib * 0.06
  local col = { lerp(v, 0.5, rust), lerp(v * 1.02, 0.32, rust), lerp(v * 1.08, 0.22, rust) }
  local edge = math.min(x, 256 - x, y, 256 - y)
  return 4 - edge, { albedo = col, height_override = rib * 0.6 + smoothstep(4, 18, edge) * 0.4, normal_strength = 6 }
end


-- Хаб главы 2 «Спящий лес»: стволы-великаны, кроны, туман между деревьями, пруд с островком Маяка.
local function hub_forest(x, y, f)
  local sky = lerp(0.03, 0.06, y / 700)
  local col = { sky * 0.8, sky * 1.1, sky * 0.95 }
  -- дальние стволы
  local fi = math.floor(x / 60)
  local fx = x - fi * 60
  local fw = 8 + hash(fi, 1, 401) * 10
  if math.abs(fx - 30) < fw and y > 200 and y < 830 then local v = 0.07 col = { v * 0.8, v * 1.05, v * 0.9 } end
  -- ближние стволы-великаны с корнями
  local ni = math.floor((x + 40) / 150)
  local nx = x + 40 - ni * 150
  local nw = 16 + hash(ni, 2, 403) * 18 + math.max(0, (y - 700) * 0.25)
  if math.abs(nx - 75) < nw and y > 120 and y < 840 then local v = 0.05 col = { v * 0.8, v, v * 0.85 } end
  -- кроны
  local canopy = fbm(x / 90, y / 60, 405)
  if y < 420 and canopy > 0.5 - (420 - y) / 900 then
    local v = 0.05 + (canopy - 0.5) * 0.06
    col = { v * 0.75, v * 1.15, v * 0.85 }
  end
  -- светлячки в тумане
  if hash(math.floor(x / 7), math.floor(y / 7), 407) > 0.996 and y > 300 and y < 800 then col = { 0.5, 0.65, 0.35 } end
  -- пруд
  if y >= 820 then
    local w = 0.03 + (vnoise(x / 40, y / 3, 409) - 0.5) * 0.015
    col = { w * 0.8, w * 1.15, w }
  end
  local island = sd_ellipse(x, y, 390, 880, 190, 46)
  if island < 0 then
    local moss = smoothstep(0.5, 0.6, fbm(x / 12, y / 12, 411))
    local v = 0.15 + (fbm(x / 10, y / 10, 413) - 0.5) * 0.05
    col = { v * 0.9, v * (1 + moss * 0.25), v * 0.85 }
  end
  return -1, { albedo = { clamp(col[1], 0, 1), clamp(col[2], 0, 1), clamp(col[3], 0, 1) }, height_override = 0, normal_strength = 0 }
end

-- Хаб главы 3 «Ржавый порт»: склады, штабеля контейнеров, портовые краны, корпус корабля у причала.
local function hub_port(x, y, f)
  local sky = lerp(0.035, 0.07, y / 700)
  local col = { sky * 1.1, sky * 0.95, sky }
  -- склады (широкие низкие коробки)
  local wi = math.floor(x / 130)
  local roof = 560 - hash(wi, 1, 501) * 90
  if y > roof and y < 830 then local v = 0.075 col = { v * 1.05, v * 0.95, v * 0.95 } end
  -- штабеля контейнеров
  local ci = math.floor(x / 34)
  local stack = 700 - math.floor(hash(ci, 2, 503) * 4) * 26
  if y > stack and y < 830 and (x % 34) > 2 then
    local tone = hash(ci, math.floor(y / 26), 505)
    local rib = (x % 5 < 1) and -0.008 or 0
    local seam = ((y - stack) % 26 < 2) and -0.012 or 0
    local v = 0.058 + tone * 0.012 + rib + seam
    col = { v * (1.02 + tone * 0.12), v * 0.95, v * 0.92 }
  end
  -- краны: мачта + стрела
  for k = 0, 1 do
    local mx = 150 + k * 440
    if math.abs(x - mx) < 6 and y > 220 and y < 830 then col = { 0.05, 0.048, 0.05 } end
    local boom_y = 230 + (x - mx) * 0.08
    if math.abs(y - boom_y) < 4 and x > mx - 60 and x < mx + 230 then col = { 0.05, 0.048, 0.05 } end
    if math.abs(x - (mx + 180)) < 1.2 and y > boom_y and y < 520 then col = { 0.06, 0.058, 0.06 } end
  end
  -- корабль у причала
  local hull = math.max(math.abs(x - 600) - 170 + (y - 800) * 0.6, math.abs(y - 800) - 30)
  if hull < 0 then col = { 0.045, 0.04, 0.042 } end
  -- вода
  if y >= 830 then
    local w = 0.032 + (vnoise(x / 40, y / 3, 507) - 0.5) * 0.015
    col = { w * 1.05, w, w * 1.1 }
  end
  local island = sd_ellipse(x, y, 390, 880, 190, 46)
  if island < 0 then
    -- причал: доски
    local v = 0.15 + (math.floor(x / 16) % 2) * 0.012 + (fbm(x / 30, y / 4, 509) - 0.5) * 0.04
    col = { v * 1.05, v * 0.95, v * 0.85 }
  end
  return -1, { albedo = { clamp(col[1], 0, 1), clamp(col[2], 0, 1), clamp(col[3], 0, 1) }, height_override = 0, normal_strength = 0 }
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
if want("beacon") then
  for _, kind in ipairs({ "ruins", "cracked", "runes", "armored", "radiant" }) do
    save_asset("src/assets/beacon", "pedestal_" .. kind, 320, 160, 1, pedestal(kind), false, true)
  end
  save_asset("src/assets/beacon", "crystal_shards", 96, 160, 1, crystal("shards"), false, true)
  for _, kind in ipairs({ "dim", "bright", "white" }) do
    save_asset("src/assets/beacon", "crystal_" .. kind, 96, 160, 12, crystal(kind), false, true)
  end
end
if want("chests") then
  for _, kind in ipairs({ "basic", "premium", "run", "epic" }) do
    save_asset("src/assets/chests", "chest_" .. kind .. "_closed", 320, 240, 1, chest(kind, false), false, true)
    save_asset("src/assets/chests", "chest_" .. kind .. "_open", 320, 240, 1, chest(kind, true), false, true)
  end
end
if want("vfx") then
  save_asset("src/assets/vfx", "ember", 32, 32, 1, ember, false, true)
  save_asset("src/assets/vfx", "ash", 32, 32, 1, ash, false, true)
  save_asset("src/assets/vfx", "spark", 32, 32, 1, spark_star, false, true)
  save_asset("src/assets/world/common", "biolum_mushrooms_1", 64, 64, 1, mushrooms(111), false, true)
  save_asset("src/assets/world/common", "biolum_mushrooms_2", 64, 64, 1, mushrooms(131), false, true)
  save_asset("src/assets/world/common", "biolum_rune", 48, 48, 1, rune, false, true)
end
if want("biomes") then
  for i = 1, 4 do
    save_asset("src/assets/world/sleeping_forest", "floor_" .. i, 128, 128, 1, forest_floor(400 + i * 13), false)
    save_asset("src/assets/world/rusty_port", "floor_" .. i, 128, 128, 1, port_floor(500 + i * 13), false)
  end
  save_asset("src/assets/world/sleeping_forest", "prop_stump", 256, 256, 1, prop_stump, false)
  save_asset("src/assets/world/sleeping_forest", "prop_boulder", 256, 256, 1, prop_boulder, false)
  save_asset("src/assets/world/rusty_port", "prop_crate", 256, 256, 1, prop_crate, false)
  save_asset("src/assets/world/rusty_port", "prop_container", 256, 256, 1, prop_container, false)
end
if want("hub") then
  if ONLY_HUB == nil or ONLY_HUB == 1 then save_asset("src/assets/beacon", "hub_diorama_ch1", 780, 1100, 1, hub_city, false, true) end
  if ONLY_HUB == nil or ONLY_HUB == 2 then save_asset("src/assets/beacon", "hub_diorama_ch2", 780, 1100, 1, hub_forest, false, true) end
  if ONLY_HUB == nil or ONLY_HUB == 3 then save_asset("src/assets/beacon", "hub_diorama_ch3", 780, 1100, 1, hub_port, false, true) end
end
if want("hero") then
  save_asset("src/assets/hero", "hero_body", 170, 170, 1, hero_body, false)
  save_asset("src/assets/hero", "hero_core", 170, 170, 1, hero_core, false)
  for _, kind in ipairs({ "calm", "focused", "scared", "happy" }) do
    save_asset("src/assets/hero", "hero_eyes_" .. kind, 170, 170, 1, hero_eyes(kind), false)
  end
end

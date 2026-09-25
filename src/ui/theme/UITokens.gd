class_name UITokens
extends RefCounted
## Дизайн-токены «Тёплый свет на чернилах» (Design System §01). Единственное место hex-цветов UI.

# Поверхности и текст
const INK_900: Color = Color("#07090F")
const INK_800: Color = Color("#0B0E17")
const INK_700: Color = Color("#0E1320")
const INK_600: Color = Color("#161D2E")
const LINE: Color = Color("#1B2335")
const LINE_STRONG: Color = Color("#2A3244")
const TEXT_PRIMARY: Color = Color("#EDE8DF")
const TEXT_SECONDARY: Color = Color("#C9C4BA")
const TEXT_MUTED: Color = Color("#8F98AB")
const TEXT_DISABLED: Color = Color("#5A6378")
const TEXT_ON_LIGHT: Color = Color("#2A1606")
const TEXT_ON_CRYSTAL: Color = Color("#04222C")
const TEXT_SECONDARY_BUTTON: Color = Color("#FFE7C2")

# Смысловые
const LIGHT_300: Color = Color("#FFD08A")
const LIGHT_500: Color = Color("#FFB547")
const LIGHT_700: Color = Color("#E08A1E")
const LIGHT_900: Color = Color("#8A4A0A")
const SPARK: Color = Color("#FFD166")
const SPARK_FLASH: Color = Color("#FFF1C8")
const CRYSTAL_300: Color = Color("#B5F3FA")
const CRYSTAL_500: Color = Color("#6FE3F0")
const CRYSTAL_700: Color = Color("#2FA9B8")
const THREAT: Color = Color("#FF3B5C")
const COLD: Color = Color("#8FA3C0")
const GAIN: Color = Color("#7FD68A")
const EPIC: Color = Color("#B07CFF")
const GOLD_300: Color = Color("#FFF1C8")
const GOLD_700: Color = Color("#B8621A")
const HERO_CORE: Color = Color("#FFFDF5") ## раскалённое ядро Огонька

## Категории навыков (Skills DS §00): 300 метка · 500 иконка · 700 низ рамки · bg фон карты · глиф.
const CATEGORY: Dictionary = {
	&"attack": {"300": Color("#FFB08A"), "500": Color("#FF7A3D"), "700": Color("#C2461A"), "bg": Color("#1E120C"), "glyph": "▲", "name": "АТАКА"},
	&"defense": {"300": Color("#C8DAFF"), "500": Color("#8FB8FF"), "700": Color("#3F5FA8"), "bg": Color("#0F1422"), "glyph": "■", "name": "ЗАЩИТА"},
	&"utility": {"300": Color("#B8F0C0"), "500": Color("#7FD68A"), "700": Color("#3F8A4E"), "bg": Color("#0F1A14"), "glyph": "●", "name": "УТИЛИТА"},
}

# Отступы (сетка 4pt)
const S1: int = 4
const S2: int = 8
const S3: int = 12
const S4: int = 16
const S5: int = 20
const S6: int = 24
const S8: int = 32

# Скругления
const R8: int = 8
const R14: int = 14
const R16: int = 16
const R22: int = 22
const R_PILL: int = 999

# Свечение вместо теней: радиус размытия
const G1: int = 12
const G2: int = 30
const G3: int = 50

# Размеры
const BUTTON_PRIMARY_H: float = 54.0
const BUTTON_H: float = 48.0
const TOUCH_MIN: float = 44.0
const EMBER_HUB: float = 78.0
const EMBER_TAB: float = 62.0
const TAB_BAR_H: float = 88.0
const SAFE_TOP: int = 44
const SAFE_BOTTOM: int = 34

# Моушен (DS §05), секунды
const T_PRESS_S: float = 0.09
const T_FAST_S: float = 0.16
const T_BASE_S: float = 0.24
const T_SLOW_S: float = 0.4
const T_BREATH_S: float = 1.2
const T_CINEMATIC_S: float = 3.0

class_name UITokens
extends RefCounted
## Дизайн-токены (Design System §01). Единственное место hex-цветов UI; полный набор — task_5.

const INK_900: Color = Color("#07090F")
const INK_800: Color = Color("#0B0E17")
const INK_600: Color = Color("#161D2E")
const LINE_STRONG: Color = Color("#2A3244")
const TEXT_PRIMARY: Color = Color("#EDE8DF")
const TEXT_SECONDARY: Color = Color("#C9C4BA")
const TEXT_MUTED: Color = Color("#8F98AB")
const LIGHT_500: Color = Color("#FFB547")
const SPARK: Color = Color("#FFD166")
const SPARK_FLASH: Color = Color("#FFF1C8")
const THREAT: Color = Color("#FF3B5C")
const COLD: Color = Color("#8FA3C0")

const GOLD_300: Color = Color("#FFF1C8")
const GOLD_700: Color = Color("#B8621A")
const CRYSTAL_500: Color = Color("#6FE3F0")
const TEXT_DISABLED: Color = Color("#5A6378")

## Категории навыков (Skills DS §00): 300 метка · 500 иконка · 700 низ рамки · bg фон карты · глиф.
const CATEGORY: Dictionary = {
	&"attack": {"300": Color("#FFB08A"), "500": Color("#FF7A3D"), "700": Color("#C2461A"), "bg": Color("#1E120C"), "glyph": "▲", "name": "АТАКА"},
	&"defense": {"300": Color("#C8DAFF"), "500": Color("#8FB8FF"), "700": Color("#3F5FA8"), "bg": Color("#0F1422"), "glyph": "■", "name": "ЗАЩИТА"},
	&"utility": {"300": Color("#B8F0C0"), "500": Color("#7FD68A"), "700": Color("#3F8A4E"), "bg": Color("#0F1A14"), "glyph": "●", "name": "УТИЛИТА"},
}

const S2: int = 8
const S4: int = 16
const S5: int = 20
const R14: int = 14

const T_PRESS_S: float = 0.09
const T_FAST_S: float = 0.16
const T_BASE_S: float = 0.24

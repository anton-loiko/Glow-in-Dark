extends Node

# --- Параметры баланса игры ---
const BASE_CHUNKS_TO_WIN: int = 5
const CHUNKS_PER_LEVEL_STEP: int = 2
const CHUNK_SIZE_Y: float = 480.0

const BASE_FUEL_CHANCE: float = 0.15
const BASE_SPARK_CHANCE: float = 0.65  # Увеличено с 0.3 (теперь 65% шанс спавна на точке)
const BASE_ENEMY_CHANCE: float = 0.4  # Увеличено с 0.1 (теперь 40% шанс спавна на точке)



func get_chunks_to_win() -> int:
	return BASE_CHUNKS_TO_WIN + (GameManager.current_level * CHUNKS_PER_LEVEL_STEP)

func get_enemy_spawn_chance() -> float:
	# Шанс врагов растет на 4% с каждым уровнем (максимум 85%)
	return min(BASE_ENEMY_CHANCE + (GameManager.current_level * 0.04), 0.85)

func get_fuel_spawn_chance() -> float:
	# Шанс топлива падает с ростом уровня (минимум 5%)
	return max(BASE_FUEL_CHANCE - (GameManager.current_level * 0.005), 0.05)

func get_spark_spawn_chance() -> float:
	return BASE_SPARK_CHANCE
# ------------------------------

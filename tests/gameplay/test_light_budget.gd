extends GdUnitTestSuite
## task_8 §2, §5: бюджет света боя и замер систем.


func _light() -> PointLight2D:
	return auto_free(PointLight2D.new())


func test_budget_caps_and_priority_evicts_weakest() -> void:
	var budget: LightBudget = LightBudget.new(2)
	var fuel_a: PointLight2D = _light()
	var fuel_b: PointLight2D = _light()
	var burst: PointLight2D = _light()
	assert_bool(budget.acquire(fuel_a, 1)).is_true()
	assert_bool(budget.acquire(fuel_b, 1)).is_true()
	assert_bool(budget.acquire(_light(), 1)).is_false() # равный приоритет не вытесняет
	assert_bool(budget.acquire(burst, 3)).is_true()
	assert_int(budget.active_count()).is_equal(2)
	assert_bool(burst.enabled).is_true()
	assert_bool(fuel_a.enabled and fuel_b.enabled).is_false()


func test_release_frees_slot() -> void:
	var budget: LightBudget = LightBudget.new(1)
	var a: PointLight2D = _light()
	budget.acquire(a, 1)
	budget.release(a)
	assert_bool(a.enabled).is_false()
	assert_bool(budget.acquire(_light(), 1)).is_true()


func test_perf_stats_average() -> void:
	PerfStats.reset()
	PerfStats.begin(&"x")
	PerfStats.end(&"x")
	assert_bool(PerfStats.systems().has(&"x")).is_true()
	assert_float(PerfStats.avg_ms(&"x")).is_greater_equal(0.0)

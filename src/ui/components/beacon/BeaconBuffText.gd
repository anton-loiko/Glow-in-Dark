class_name BeaconBuffText
extends RefCounted
## Тексты баффов и наград Маяка для карточек (Meta DS §00).


static func buff(buff_dict: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in buff_dict:
		var v: float = float(buff_dict[key])
		match key:
			"max_light":
				parts.append(TranslationServer.translate("+%d макс. яркости") % int(v))
			"fuel_efficiency_pct":
				parts.append(TranslationServer.translate("+%d%% эффективности Топлива") % int(v))
			"decay_rate_pct":
				parts.append(TranslationServer.translate("%d%% скорости затухания") % int(v))
			"magnet_radius_pct":
				parts.append(TranslationServer.translate("+%d%% радиуса магнита") % int(v))
			"spark_income_pct":
				parts.append(TranslationServer.translate("+%d%% дохода Искр") % int(v))
			"all_stats_pct":
				parts.append(TranslationServer.translate("+%d%% ко всем статам") % int(v))
	return " · ".join(parts)


static func reward(reward_dict: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in reward_dict:
		if key.begins_with("_"):
			continue
		var value: Variant = reward_dict[key]
		match key:
			"skin":
				parts.append(TranslationServer.translate("Новый Огонёк: %s") % TranslationServer.translate(SkinService.display_name(StringName(str(value)))))
			"crystals":
				parts.append("+%d ◆" % int(value))
			"gear_slot":
				parts.append(TranslationServer.translate("+1 слот экипировки"))
			"chest":
				parts.append(TranslationServer.translate("Эпический сундук"))
			"chapter_unlock":
				parts.append(TranslationServer.translate("Глава %d открыта") % int(value))
	return " · ".join(parts)

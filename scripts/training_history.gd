class_name TrainingHistory

static func load_training_history(countries_map: Dictionary) -> Dictionary:
	var parsed = FileManager.load_json(FilePaths.TRAINING_HISTORY, {})
	if parsed is Dictionary:
		return normalize_training_history(parsed, countries_map)
	return {}

static func save_training_history(history: Dictionary) -> bool:
	return FileManager.save_json(FilePaths.TRAINING_HISTORY, history)

static func normalize_training_history(history: Dictionary, countries_map: Dictionary) -> Dictionary:
	var normalized := {}
	for key in history.keys():
		var country_code := ""
		if key.length() <= 3:
			country_code = key.to_upper()
		else:
			for code in countries_map.keys():
				if countries_map[code] == key:
					country_code = code.to_upper()
					break
		if country_code == "":
			push_warning("Unknown country in training history: " + key)
			continue
		if not normalized.has(country_code):
			normalized[country_code] = {}
		for module_name in history[key].keys():
			if not normalized[country_code].has(module_name):
				normalized[country_code][module_name] = history[key][module_name]
			else:
				var existing_date = normalized[country_code][module_name]["last_training_date"]
				var new_date = history[key][module_name]["last_training_date"]
				if new_date > existing_date:
					normalized[country_code][module_name] = history[key][module_name]
	return normalized

static func update_training_entry(country_code: String, resource_name: String, duration_minutes: int, completed: bool, countries_map: Dictionary):
	var history = load_training_history(countries_map)
	var current_date = Time.get_unix_time_from_system()
	var normalized_code = country_code.to_upper()

	if not history.has(normalized_code):
		history[normalized_code] = {}

	if history[normalized_code].has(resource_name):
		var entry = history[normalized_code][resource_name]
		entry["last_training_date"] = current_date
		entry["total_time_minutes"] += duration_minutes
		entry["completed"] = completed
	else:
		history[normalized_code][resource_name] = {
			"last_training_date": current_date,
			"total_time_minutes": duration_minutes,
			"completed": completed
		}

	if save_training_history(history):
		print("Training history updated for ", normalized_code, " - ", resource_name)
	else:
		push_error("Failed to save training history")

static func get_incomplete_modules(history: Dictionary) -> Array:
	var incomplete = []
	for country_code in history.keys():
		for resource_name in history[country_code].keys():
			var entry = history[country_code][resource_name]
			if not entry["completed"]:
				incomplete.append({
					"country": country_code.to_upper(),
					"resource_name": resource_name,
					"last_date": entry["last_training_date"]
				})
	incomplete.sort_custom(func(a, b): return a["last_date"] > b["last_date"])
	return incomplete

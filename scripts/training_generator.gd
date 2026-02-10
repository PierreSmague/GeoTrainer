class_name TrainingGenerator

class TrainingTile:
	var type: String
	var duration_minutes: int
	var training_type: String
	var country: String
	var url: String

	func _init(p_type: String, p_duration: int, p_training_type: String = "", p_country: String = "", p_url: String = ""):
		type = p_type
		duration_minutes = p_duration
		training_type = p_training_type
		country = p_country
		url = p_url

class TrainingModule:
	var theory_tile: TrainingTile
	var practice_tile: TrainingTile
	var total_duration: int

	func _init(p_theory: TrainingTile, p_practice: TrainingTile):
		theory_tile = p_theory
		practice_tile = p_practice
		total_duration = theory_tile.duration_minutes + practice_tile.duration_minutes

static func get_player_elo() -> float:
	var duels_data = FileManager.load_json(FilePaths.DUELS_FILTERED)
	if duels_data == null or not duels_data is Array or duels_data.is_empty():
		return 1000.0
	var first_duel = duels_data[0]
	if first_duel.has("playerRatingAfter"):
		return float(first_duel["playerRatingAfter"])
	return 1000.0

static func get_difficulty_range_from_elo(elo: float) -> Dictionary:
	var difficulty_range := {}
	if elo < 1000:
		difficulty_range["min"] = 1
		difficulty_range["max"] = 2
	elif elo >= 1000 and elo < 1300:
		difficulty_range["min"] = 1
		difficulty_range["max"] = 3
	elif elo >= 1300 and elo < 1600:
		difficulty_range["min"] = 2
		difficulty_range["max"] = 4
	else:
		difficulty_range["min"] = 3
		difficulty_range["max"] = 5
	return difficulty_range

static func generate_training_program(total_time_minutes: int) -> Array[TrainingModule]:
	var modules: Array[TrainingModule] = []
	total_time_minutes = clampi(total_time_minutes, 10, 240)
	var num_modules = max(1, int(total_time_minutes / 60) + 1)
	var module_duration = total_time_minutes / num_modules
	var tile_duration = module_duration / 2

	for i in range(num_modules):
		var theory_tile = TrainingTile.new("theory", tile_duration)
		var practice_tile = TrainingTile.new("practice", tile_duration)
		var module = TrainingModule.new(theory_tile, practice_tile)
		modules.append(module)

	return modules

static func select_country_by_probability(priorities: Array) -> String:
	var total_score = 0
	for priority in priorities:
		total_score += priority["score"] * priority["score"]
	if total_score == 0:
		return priorities[randi() % priorities.size()]["country"]
	var random_value = randf() * total_score
	var cumulative = 0
	for priority in priorities:
		cumulative += priority["score"] * priority["score"]
		if random_value <= cumulative:
			return priority["country"]
	return priorities[0]["country"]

static func get_best_module_for_country(country_code: String, difficulty_range: Dictionary, resources: Dictionary, countries_map: Dictionary, history: Dictionary) -> Dictionary:
	var country_name = countries_map.get(country_code.to_lower(), "")
	if country_name == "":
		return {}
	if not resources.has(country_name):
		return {}

	var country_modules = resources[country_name]
	var valid_modules = []

	var completed_modules = []
	var normalized_code = country_code.to_upper()
	if history.has(normalized_code):
		for resource_name in history[normalized_code].keys():
			if history[normalized_code][resource_name]["completed"]:
				completed_modules.append(resource_name)

	for module in country_modules:
		var is_completed = module["title"] in completed_modules
		var in_difficulty_range = module["difficulty"] >= difficulty_range["min"] and module["difficulty"] <= difficulty_range["max"]
		if not is_completed and in_difficulty_range:
			valid_modules.append(module)

	if valid_modules.is_empty():
		for module in country_modules:
			var is_completed = module["title"] in completed_modules
			if not is_completed and module["difficulty"] < difficulty_range["min"]:
				valid_modules.append(module)
		if valid_modules.is_empty():
			return {}

	valid_modules.sort_custom(func(a, b): return a["usefulness"] > b["usefulness"])
	return valid_modules[0]

static func populate_training_modules(
	modules: Array[TrainingModule],
	difficulty_range: Dictionary,
	selected_country_code: String,
	priorities: Array,
	countries_map: Dictionary,
	history: Dictionary
) -> void:
	var resources = FileManager.load_json(FilePaths.RESOURCES, {})
	if resources.is_empty():
		push_error("Cannot load training resources")
		return

	var use_selected_country_first := (selected_country_code != "")
	var incomplete_modules := TrainingHistory.get_incomplete_modules(history)
	var used_module_keys := {}
	var incomplete_index := 0

	for i in range(modules.size()):
		var module = modules[i]
		var country_code := ""

		if i == 0 and use_selected_country_first:
			country_code = selected_country_code
		elif incomplete_index < incomplete_modules.size():
			country_code = incomplete_modules[incomplete_index]["country"]
			incomplete_index += 1
		else:
			country_code = select_country_by_probability(priorities)

		if country_code == "":
			push_warning("Empty country code, skipping module " + str(i + 1))
			continue

		var training_module := {}
		var attempts := 0
		const MAX_ATTEMPTS := 6

		while attempts < MAX_ATTEMPTS:
			training_module = get_best_module_for_country(
				country_code, difficulty_range, resources, countries_map, history
			)
			if training_module.is_empty():
				break
			var module_key = country_code + "::" + training_module.get("title", "")
			if not used_module_keys.has(module_key):
				used_module_keys[module_key] = true
				break
			country_code = select_country_by_probability(priorities)
			attempts += 1

		if training_module.is_empty() or attempts == MAX_ATTEMPTS:
			push_warning("Skipping module " + str(i + 1) + " (no unique content)")
			continue

		module.theory_tile.training_type = training_module.get("title", "")
		module.theory_tile.country = country_code
		module.theory_tile.url = training_module.get("url", "")
		module.practice_tile.training_type = training_module.get("title", "")
		module.practice_tile.country = country_code
		module.practice_tile.url = training_module.get("map", "")

		print("Module ", i + 1, " assigned: ", country_code, " - ", training_module.get("title", ""))

static func print_program_summary(modules: Array[TrainingModule], total_time: int):
	print("\n=== Training Program ===")
	print("Total requested time: ", total_time, " minutes")
	print("Number of modules: ", modules.size())
	print()
	var actual_total = 0
	for i in range(modules.size()):
		var module = modules[i]
		actual_total += module.total_duration
		print("Module ", i + 1, ": ", module.theory_tile.country, " - ", module.theory_tile.training_type)
		print("  - Theory: ", module.theory_tile.duration_minutes, " min")
		print("    URL: ", module.theory_tile.url)
		print("  - Practice: ", module.practice_tile.duration_minutes, " min")
		print("    URL: ", module.practice_tile.url)
		print("  - Total: ", module.total_duration, " min")
		print()
	print("Actual total time: ", actual_total, " minutes")

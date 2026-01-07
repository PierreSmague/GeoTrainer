extends PanelContainer

@onready var time_slider: HSlider = $RootVBox/MarginContainerTime/TimeSelection/TimeSliderRow/TimeSlider
@onready var time_value_label: Label = $RootVBox/MarginContainerTime/TimeSelection/TimeTitle
@onready var mode_option: OptionButton = $RootVBox/MarginContainerTime/TimeSelection/Selector/ModeSelector/ModeOption
@onready var country_option: OptionButton = $RootVBox/MarginContainerTime/TimeSelection/Selector/CountrySelector/CountryOption
@onready var priority_engine := DeterminePriorities.new()
@onready var modules_container = $RootVBox/TrainingOutput/Margins/ScrollContainer/ModulesContainer

# Store current training data

const COUNTRIES_FILE := "res://misc/countries.json"

var selected_mode: String = "Move"
var selected_country_code: String = ""  # "us", "fr", etc
var selected_country_name: String = ""  # "United States"
var country_code_by_index := {}
var countries_map: Dictionary = {}
var current_training_data = null
# Confirmation popup reference
var confirmation_popup: ConfirmationDialog = null
var pending_validation_data = {}  # Store data while waiting for confirmation

func _ready():
	# --- Time slider ---
	_update_time_label(time_slider.value)
	time_slider.value_changed.connect(_update_time_label)
	countries_map = _load_countries_mapping()
	
	# --- Mode selector ---
	_setup_mode_option()
	
	# --- Country selector ---
	_setup_country_option()
	
	# --- Confirmation popup for training completion ---
	_setup_confirmation_popup()

func _update_time_label(value: float):
	if value <= 0:
		time_value_label.text = "Selected time: no training today"
	else:
		time_value_label.text = "Selected time: %d minutes" % int(value)
		
func _load_countries_mapping() -> Dictionary:
	if not FileAccess.file_exists(COUNTRIES_FILE):
		push_error("Countries file not found: " + COUNTRIES_FILE)
		return {}
	
	var file = FileAccess.open(COUNTRIES_FILE, FileAccess.READ)
	if file == null:
		push_error("Cannot open countries file")
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JSON parse error in countries file: " + json.get_error_message())
		return {}
	
	return json.data

# ============================================================
# MODE SELECTION
# ============================================================
func _setup_mode_option():
	mode_option.clear()

	var modes = ["Move", "NM", "NMPZ"]
	for mode in modes:
		mode_option.add_item(mode)

	# Default selection
	mode_option.select(0)
	selected_mode = modes[0]

	mode_option.item_selected.connect(_on_mode_selected)

func _on_mode_selected(index: int):
	selected_mode = mode_option.get_item_text(index)
	print("Selected mode:", selected_mode)

# ============================================================
# COUNTRY SELECTION
# ============================================================

func _setup_country_option():
	country_option.clear()
	country_code_by_index.clear()

	# Option par défaut
	country_option.add_item("Let the module decide (recommended)", 0)
	country_code_by_index[0] = null

	if not FileAccess.file_exists(COUNTRIES_FILE):
		push_error("countries.json not found")
		return

	var file = FileAccess.open(COUNTRIES_FILE, FileAccess.READ)
	var countries: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()

	# Tri alphabétique par nom
	var sorted := []
	for code in countries.keys():
		sorted.append({
			"code": code,
			"name": countries[code]
		})

	sorted.sort_custom(func(a, b):
		return a.name < b.name
	)

	var index := 1
	for c in sorted:
		country_option.add_item(c.name, index)
		country_code_by_index[index] = c.code
		index += 1
		
		
	# Default selection
	country_option.select(0)
	selected_country_code = ""
	selected_country_name = "Let the module decide (recommended)"

	country_option.item_selected.connect(_on_country_selected)
		
func _on_country_selected(index: int):
	var code = country_code_by_index[index]
	selected_country_code = code if code != null else ""


	if selected_country_code == null:
		selected_country_name = "Let the module decide (recommended)"
	else:
		selected_country_name = country_option.get_item_text(index)

	print("Selected country:", selected_country_name, "(", selected_country_code, ")")

# ============================================================
# GENERATE TRAINING
# ============================================================

func _on_generate_training_pressed():
	# 1. Determine player priorities
	var priorities := priority_engine.load_and_compute()
	print(priorities)
	if priorities.is_empty():
		push_warning("No priorities found")
		return
		
	# 2. Extract player's ELO
	var player_elo = get_player_elo()
	print("Player ELO: ", player_elo)
	
	# 3. Determine difficulty range
	var difficulty_range = get_difficulty_range_from_elo(player_elo)
	print("Difficulty Range: min=", difficulty_range["min"], " max=", difficulty_range["max"])
	
	# 4. Create training module structures
	var total_time = int(time_slider.value)
	var training_modules = generate_training_program(total_time)
	
	# 5. Get selected country
	var selected_country = selected_country_name  # Your dropdown variable
	
	# 6. Populate modules with actual content
	populate_training_modules(training_modules, difficulty_range, selected_country, priorities)
	
	# 7. Print summary for debugging
	print_program_summary(training_modules, total_time)
	
	# 8. Create training data object
	var training_data = {
		"difficulty_range": difficulty_range,
		"modules": training_modules,
		"total_time": total_time
	}
	
	# 9. Display the training program in UI
	if training_data and training_data["modules"].size() > 0:
		display_training_modules(training_data)
		print("Training program displayed successfully!")
	else:
		push_error("Failed to generate training program")
	

# Setup confirmation popup
func _setup_confirmation_popup():
	confirmation_popup = ConfirmationDialog.new()
	confirmation_popup.dialog_text = "Did you study the whole document? If you just partially did it (some docs are long), you'll be proposed this module in priority next time."
	confirmation_popup.ok_button_text = "Yes"
	confirmation_popup.cancel_button_text = "No"
	confirmation_popup.confirmed.connect(_on_validation_confirmed)
	confirmation_popup.canceled.connect(_on_validation_partial)
	add_child(confirmation_popup)

func get_player_elo() -> float:
	var file_path = "user://duels_filtered.json"
	
	if not FileAccess.file_exists(file_path):
		push_warning("duels_filtered.json file doesn't exist")
		return 1000.0  # Default ELO
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Impossible to open duels_filtered.json")
		return 1000.0
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JSON parsing error: " + json.get_error_message())
		return 1000.0
	
	var duels_data = json.data
	
	# Check if table is not empty
	if typeof(duels_data) != TYPE_ARRAY or duels_data.is_empty():
		push_warning("JSON file has no duels")
		return 1000.0
	
	# Récupérer l'ELO du premier duel
	var first_duel = duels_data[0]
	if first_duel.has("playerRatingAfter"):
		return float(first_duel["playerRatingAfter"])
	else:
		push_warning("First duel doesn't have playerRatingAfter")
		return 1000.0

# Fonction pour déterminer la plage de difficulté basée sur l'ELO
func get_difficulty_range_from_elo(elo: float) -> Dictionary:
	var difficulty_range := {}
	
	if elo < 1000:
		# Que des modules de difficulté inférieure à 2 étoiles
		difficulty_range["min"] = 1
		difficulty_range["max"] = 2
	elif elo >= 1000 and elo < 1300:
		# Modules jusqu'à 3 étoiles
		difficulty_range["min"] = 1
		difficulty_range["max"] = 3
	elif elo >= 1300 and elo < 1600:
		# Privilégier les modules de 2 à 4 étoiles
		difficulty_range["min"] = 2
		difficulty_range["max"] = 4
	else:  # elo >= 1600
		# Privilégier les modules de 3 à 5 étoiles
		difficulty_range["min"] = 3
		difficulty_range["max"] = 5
	
	return difficulty_range

# Updated TrainingTile class to include URL
class TrainingTile:
	var type: String  # "theory" or "practice"
	var duration_minutes: int
	var training_type: String  # e.g., "Plonk It - Regionguess"
	var country: String  # e.g., "Albania"
	var url: String  # URL for document or map
	
	func _init(p_type: String, p_duration: int, p_training_type: String = "", p_country: String = "", p_url: String = ""):
		type = p_type
		duration_minutes = p_duration
		training_type = p_training_type
		country = p_country
		url = p_url

# Structure to represent a training module (theory + practice)
class TrainingModule:
	var theory_tile: TrainingTile
	var practice_tile: TrainingTile
	var total_duration: int
	
	func _init(p_theory: TrainingTile, p_practice: TrainingTile):
		theory_tile = p_theory
		practice_tile = p_practice
		total_duration = theory_tile.duration_minutes + practice_tile.duration_minutes

# Generate training program based on time slider value
func generate_training_program(total_time_minutes: int) -> Array[TrainingModule]:
	var modules: Array[TrainingModule] = []
	
	# Clamp total time between 10 and 240 minutes
	total_time_minutes = clampi(total_time_minutes, 10, 240)
	
	# Calculate number of modules based on truncated hours
	var num_modules = max(1, int(total_time_minutes / 60) + 1)
	
	# Calculate duration per module (equal distribution)
	var module_duration = total_time_minutes / num_modules
	
	# Each tile gets half the module duration
	var tile_duration = module_duration / 2
	
	# Create all modules with equal duration
	for i in range(num_modules):
		# Create theory and practice tiles (will be populated later with actual content)
		var theory_tile = TrainingTile.new("theory", tile_duration)
		var practice_tile = TrainingTile.new("practice", tile_duration)
		
		# Create module with both tiles
		var module = TrainingModule.new(theory_tile, practice_tile)
		modules.append(module)
	
	return modules


# Display program summary for debugging
func print_program_summary(modules: Array[TrainingModule], total_time: int):
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

# Load resources from JSON file
func load_training_resources() -> Dictionary:
	var file_path = "res://misc/resources.json"
	
	if not FileAccess.file_exists(file_path):
		push_error("File resources.json not found")
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open resources.json")
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JSON parse error: " + json.get_error_message())
		return {}
	
	return json.data

# Get best module for a country within difficulty range
func get_best_module_for_country(country: String, difficulty_range: Dictionary, resources: Dictionary) -> Dictionary:
	var history = load_training_history()
	var country_name: String = ""
	
	if len(country) == 2:
		country_name = countries_map[country.to_lower()]
	else:
		country_name = country
	
	if not resources.has(country_name):
		push_warning("No resources found for country: " + country_name)
		return {}
	
	var country_modules = resources[country_name]
	var valid_modules = []
	
	# Get list of completed modules for this country
	var completed_modules = []
	if history.has(country_name):
		for resource_name in history[country_name].keys():
			if history[country_name][resource_name]["completed"]:
				completed_modules.append(resource_name)
	
	# Filter modules within difficulty range AND not completed
	for module in country_modules:
		var is_completed = module["title"] in completed_modules
		var in_difficulty_range = module["difficulty"] >= difficulty_range["min"] and module["difficulty"] <= difficulty_range["max"]
		
		if not is_completed and in_difficulty_range:
			valid_modules.append(module)
	
	# If no valid modules in range, try to fallback to lower difficulties (still excluding completed)
	if valid_modules.is_empty():
		for module in country_modules:
			var is_completed = module["title"] in completed_modules
			
			if not is_completed and module["difficulty"] < difficulty_range["min"]:
				valid_modules.append(module)
		
		if valid_modules.is_empty():
			push_warning("No suitable uncompleted modules found for " + country_name)
			return {}
	
	# Sort by usefulness (descending) to get highest usefulness first
	valid_modules.sort_custom(func(a, b): return a["usefulness"] > b["usefulness"])
	
	# Return the module with highest usefulness
	return valid_modules[0]

# Populate modules with actual training content
func populate_training_modules(modules: Array[TrainingModule], difficulty_range: Dictionary, selected_country: String, priorities: Array) -> void:
	var resources = load_training_resources()
	
	if resources.is_empty():
		push_error("Cannot load training resources")
		return
	
	var use_selected_country_first = (selected_country != "Let the module decide (recommended)")
	var incomplete_modules = get_incomplete_modules()
	var used_module_keys := {}  # clé unique = country + title
	
	
	var country_index = 0
	var incomplete_index = 0
	
	for i in range(modules.size()):
		var module = modules[i]
		var country_to_use = ""
		
		# Module 1: use selected country if specified
		if i == 0 and use_selected_country_first:
			country_to_use = selected_country
		# Module 2 (or 1 if no selected country): use incomplete module if available
		elif ((i == 1 and use_selected_country_first) or (i == 0 and not use_selected_country_first)) and incomplete_modules.size() > 0:
			if incomplete_index < incomplete_modules.size():
				country_to_use = incomplete_modules[incomplete_index]["country"]
				incomplete_index += 1
			else:
				# No incomplete modules, use priorities
				country_to_use = select_country_by_probability(priorities)
		else:
			country_to_use = select_country_by_probability(priorities)
		
		# Get best module for this country
		var training_module := {}
		var attempts := 0
		const MAX_ATTEMPTS := 5

		while attempts < MAX_ATTEMPTS:
			training_module = get_best_module_for_country(country_to_use, difficulty_range, resources)

			if training_module.is_empty():
				break

			var module_key = country_to_use + "::" + training_module.get("title", "")

			if not used_module_keys.has(module_key):
				used_module_keys[module_key] = true
				break  # module valide et unique

			# Sinon, on retente avec un autre pays
			country_to_use = select_country_by_probability(priorities)
			attempts += 1

		if training_module.is_empty() or attempts == MAX_ATTEMPTS:
			push_warning("Skipping module " + str(i + 1) + " - no unique content available")
			continue
		
		# Populate theory tile (document URL)
		module.theory_tile.training_type = training_module.get("title", "")
		module.theory_tile.country = country_to_use
		module.theory_tile.url = training_module.get("url", "")
		
		# Populate practice tile (map URL)
		module.practice_tile.training_type = training_module.get("title", "")
		module.practice_tile.country = country_to_use
		module.practice_tile.url = training_module.get("map", "")
		
		print("Module ", i + 1, " assigned: ", country_to_use, " - ", training_module["title"])

# Select country probabilistically based on scores
func select_country_by_probability(priorities: Array) -> String:
	# Calculate total score (squared)
	var total_score = 0
	for priority in priorities:
		total_score += priority["score"] * priority["score"]
	
	# If total score is 0, return random country
	if total_score == 0:
		push_warning("All priorities have score 0, selecting random country")
		return priorities[randi() % priorities.size()]["country"]
	
	# Generate random number between 0 and total_score
	var random_value = randf() * total_score
	
	# Select country based on cumulative probability
	var cumulative = 0
	for priority in priorities:
		cumulative += priority["score"] * priority["score"]
		if random_value <= cumulative:
			return priority["country"]
	
	# Fallback (should never reach here)
	return priorities[0]["country"]

# Clear all existing modules from UI
func clear_training_display():
	for child in modules_container.get_children():
		child.queue_free()


# Display training modules in UI with two columns
func display_training_modules(training_data: Dictionary):
	current_training_data = training_data
	clear_training_display()
	
	var modules = training_data["modules"]
	
	# Create rows with 2 columns each
	var current_row = null
	
	for i in range(modules.size()):
		var module = modules[i]
		
		# Create a new row every 2 modules
		if i % 2 == 0:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 20)
			modules_container.add_child(current_row)
		
		# Create module card
		var module_card = create_module_card(module, i)
		module_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(module_card)
		
		# If it's an odd number of modules, add a spacer to balance the last row
		if i == modules.size() - 1 and i % 2 == 0:
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_child(spacer)
		
		# Add spacing between rows
		if i % 2 == 1 and i < modules.size() - 1:
			var row_spacer = Control.new()
			row_spacer.custom_minimum_size = Vector2(0, 15)
			modules_container.add_child(row_spacer)


# Create a single module card with two tiles
func create_module_card(module: TrainingModule, index: int) -> PanelContainer:
	# Main card container
	var card = PanelContainer.new()
	card.name = "ModuleCard" + str(index)
	
	# Add custom theme/style (optional)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.4, 0.6, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Module content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	card.add_child(content)
	
	# Header with module info and validate button
	var header = HBoxContainer.new()
	content.add_child(header)
	
	var country_label = Label.new()
	country_label.text = "Module " + str(index + 1) + ": " + module.theory_tile.country + " - " + module.theory_tile.training_type
	country_label.add_theme_font_size_override("font_size", 20)
	country_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(country_label)
	
	var validate_btn = Button.new()
	validate_btn.text = "✓ Complete Module"
	validate_btn.custom_minimum_size = Vector2(150, 40)
	validate_btn.pressed.connect(_on_module_validated.bind(index, card))
	header.add_child(validate_btn)
	
	# Tiles container (theory + practice side by side)
	var tiles_container = HBoxContainer.new()
	tiles_container.add_theme_constant_override("separation", 100)
	content.add_child(tiles_container)
	
	# Theory tile
	var theory_tile = create_tile(module.theory_tile, "📚 Theory")
	tiles_container.add_child(theory_tile)
	
	# Practice tile
	var practice_tile = create_tile(module.practice_tile, "🎮 Practice")
	tiles_container.add_child(practice_tile)
	
	return card


# Create a single tile (theory or practice)
func create_tile(tile: TrainingTile, header_text: String) -> PanelContainer:
	var tile_panel = PanelContainer.new()
	tile_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Tile styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	tile_panel.add_theme_stylebox_override("panel", style)
	
	var tile_content = VBoxContainer.new()
	tile_content.add_theme_constant_override("separation", 10)
	tile_panel.add_child(tile_content)
	
	# Tile header
	var header = Label.new()
	header.text = header_text
	header.add_theme_font_size_override("font_size", 18)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile_content.add_child(header)
	
	# Duration label
	var duration = Label.new()
	duration.text = str(tile.duration_minutes) + " minutes"
	duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile_content.add_child(duration)
	
	# Open button
	var open_btn = Button.new()
	if tile.type == "theory":
		open_btn.text = "📖 Open Document"
	else:
		open_btn.text = "🗺️ Open Map"
	
	open_btn.custom_minimum_size = Vector2(0, 35)
	open_btn.pressed.connect(_on_tile_opened.bind(tile))
	tile_content.add_child(open_btn)
	
	return tile_panel


# Called when a tile is opened
func _on_tile_opened(tile: TrainingTile):
	if tile.url != "":
		OS.shell_open(tile.url)
		print("Opening ", tile.type, " URL: ", tile.url)
	else:
		push_warning("No URL available for this tile")


# Called when a module is validated - show confirmation popup
func _on_module_validated(module_index: int, card: PanelContainer):
	var module = current_training_data["modules"][module_index]
	
	# Store data for later use after confirmation
	pending_validation_data = {
		"module_index": module_index,
		"card": card,
		"module": module
	}
	
	# Show confirmation popup
	confirmation_popup.popup_centered()


# Called when user confirms they studied the whole document (Yes)
func _on_validation_confirmed():
	var module = pending_validation_data["module"]
	var card = pending_validation_data["card"]
	var module_index = pending_validation_data["module_index"]
	
	print("Module ", module_index + 1, " completed FULLY!")
	
	# Update training history with completed = true
	update_training_entry(
		countries_map[module.theory_tile.country.to_lower()],
		module.theory_tile.training_type,
		module.total_duration,
		true  # Completed fully
	)
	
	# Visual feedback - green
	mark_module_as_completed(card, true)


# Called when user says they only partially studied (No)
func _on_validation_partial():
	var module = pending_validation_data["module"]
	var card = pending_validation_data["card"]
	var module_index = pending_validation_data["module_index"]
	
	print("Module ", module_index + 1, " completed PARTIALLY")
	
	# Update training history with completed = false
	update_training_entry(
		countries_map[module.theory_tile.country.to_lower()],
		module.theory_tile.training_type,
		module.total_duration,
		false  # Not fully completed
	)
	
	# Visual feedback - orange/yellow
	mark_module_as_completed(card, false)


# Apply visual feedback to completed module
func mark_module_as_completed(card: PanelContainer, fully_completed: bool):
	var style = StyleBoxFlat.new()
	
	if fully_completed:
		# Green for fully completed
		style.bg_color = Color(0.2, 0.3, 0.2)
		style.border_color = Color(0.3, 0.7, 0.3)
	else:
		# Orange/yellow for partially completed
		style.bg_color = Color(0.3, 0.25, 0.15)
		style.border_color = Color(0.8, 0.6, 0.2)
	
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Update button text and disable it
	var header = card.get_child(0).get_child(0)  # content -> header
	var validate_btn = header.get_child(1)
	validate_btn.disabled = true
	
	if fully_completed:
		validate_btn.text = "✓ Completed"
	else:
		validate_btn.text = "⚠ Partially Done"

# Update or create training entry with new structure
func update_training_entry(country: String, resource_name: String, duration_minutes: int, completed: bool):
	var history = load_training_history()
	
	# Get current date as Unix timestamp
	var current_date = Time.get_unix_time_from_system()
	
	# Ensure country exists in history
	if not history.has(country):
		history[country] = {}
	
	# Check if resource exists for this country
	if history[country].has(resource_name):
		var entry = history[country][resource_name]
		entry["last_training_date"] = current_date
		entry["total_time_minutes"] += duration_minutes
		entry["completed"] = completed
	else:
		# Create new resource entry
		history[country][resource_name] = {
			"last_training_date": current_date,
			"total_time_minutes": duration_minutes,
			"completed": completed
		}
	
	# Save to file
	if save_training_history(history):
		print("Training history updated for ", country, " - ", resource_name)
	else:
		push_error("Failed to save training history")
		
# Find incomplete modules from training history
func get_incomplete_modules() -> Array:
	var history = load_training_history()
	var incomplete = []
	
	for country in history.keys():
		for resource_name in history[country].keys():
			var entry = history[country][resource_name]
			if not entry["completed"]:
				incomplete.append({
					"country": country,
					"resource_name": resource_name,
					"last_date": entry["last_training_date"]
				})
	
	# Sort by most recent first (to prioritize recently attempted modules)
	incomplete.sort_custom(func(a, b): return a["last_date"] > b["last_date"])
	
	return incomplete
	
# Load training history from file
func load_training_history() -> Dictionary:
	var file_path = "user://training_history.json"
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open training_history.json")
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JSON parse error in training_history: " + json.get_error_message())
		return {}
	
	return json.data


# Save training history to file
func save_training_history(history: Dictionary) -> bool:
	var file_path = "user://training_history.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		push_error("Cannot write to training_history.json")
		return false
	
	var json_string = JSON.stringify(history, "\t")
	file.store_string(json_string)
	file.close()
	
	return true

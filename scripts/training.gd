extends PanelContainer

@onready var time_slider: HSlider = $RootVBox/MarginContainerTime/TimeSelection/TimeSliderRow/TimeSlider
@onready var time_value_label: Label = $RootVBox/MarginContainerTime/TimeSelection/TimeTitle
@onready var mode_option: OptionButton = $RootVBox/MarginContainerTime/TimeSelection/Selector/ModeSelector/ModeOption
@onready var country_option: OptionButton = $RootVBox/MarginContainerTime/TimeSelection/Selector/CountrySelector/CountryOption
@onready var priority_engine := DeterminePriorities.new()
@onready var modules_container = $RootVBox/TrainingOutput/Margins/ScrollContainer/ModulesContainer

var selected_mode: String = "Move"
var selected_country_code: String = ""
var selected_country_name: String = ""
var country_code_by_index := {}
var countries_map: Dictionary = {}
var current_training_data = null
var confirmation_popup: ConfirmationDialog = null
var pending_validation_data = {}
var country_name_to_code := {}

func _ready():
	_update_time_label(time_slider.value)
	time_slider.value_changed.connect(_update_time_label)

	countries_map = FileManager.load_json(FilePaths.COUNTRIES, {})
	_build_country_reverse_map()

	_setup_mode_option()
	_setup_country_option()
	_setup_confirmation_popup()


func _build_country_reverse_map():
	country_name_to_code.clear()
	for code in countries_map.keys():
		country_name_to_code[countries_map[code]] = code

func _update_time_label(value: float):
	if value <= 0:
		time_value_label.text = "Selected time: no training today"
	else:
		time_value_label.text = "Selected time: %d minutes" % int(value)

# ============================================================
# MODE SELECTION
# ============================================================
func _setup_mode_option():
	mode_option.clear()
	var modes = ["Move", "NM", "NMPZ"]
	for mode in modes:
		mode_option.add_item(mode)
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

	country_option.add_item("Let the module decide (recommended)", 0)
	country_code_by_index[0] = null

	var countries = FileManager.load_json(FilePaths.COUNTRIES, {})

	var sorted := []
	for code in countries.keys():
		sorted.append({"code": code, "name": countries[code]})

	sorted.sort_custom(func(a, b): return a.name < b.name)

	var index := 1
	for c in sorted:
		country_option.add_item(c.name, index)
		country_code_by_index[index] = c.code
		index += 1

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
	var priorities := priority_engine.load_and_compute()
	if priorities.is_empty():
		push_warning("No priorities found")
		return

	var player_elo = TrainingGenerator.get_player_elo()
	var difficulty_range = TrainingGenerator.get_difficulty_range_from_elo(player_elo)
	var total_time = int(time_slider.value)
	var training_modules = TrainingGenerator.generate_training_program(total_time)

	var sel_country := ""
	if selected_country_name != "Let the module decide (recommended)":
		sel_country = country_name_to_code.get(selected_country_name, "")

	var history = TrainingHistory.load_training_history(countries_map)
	TrainingGenerator.populate_training_modules(training_modules, difficulty_range, sel_country, priorities, countries_map, history)
	TrainingGenerator.print_program_summary(training_modules, total_time)

	var training_data = {
		"difficulty_range": difficulty_range,
		"modules": training_modules,
		"total_time": total_time
	}

	if training_data and training_data["modules"].size() > 0:
		display_training_modules(training_data)
		print("Training program displayed successfully!")
	else:
		push_error("Failed to generate training program")

func _setup_confirmation_popup():
	confirmation_popup = ConfirmationDialog.new()
	confirmation_popup.dialog_text = "Did you study the whole document? If you just partially did it (some docs are long), you'll be proposed this module in priority next time."
	confirmation_popup.ok_button_text = "Yes"
	confirmation_popup.cancel_button_text = "No"
	confirmation_popup.confirmed.connect(_on_validation_confirmed)
	confirmation_popup.canceled.connect(_on_validation_partial)
	add_child(confirmation_popup)

# ============================================================
# DISPLAY
# ============================================================
func clear_training_display():
	for child in modules_container.get_children():
		child.queue_free()

func display_training_modules(training_data: Dictionary):
	current_training_data = training_data
	clear_training_display()
	var modules = training_data["modules"]
	var current_row = null

	for i in range(modules.size()):
		var module = modules[i]
		if i % 2 == 0:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 20)
			modules_container.add_child(current_row)

		var module_card = create_module_card(module, i)
		module_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(module_card)

		if i == modules.size() - 1 and i % 2 == 0:
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_child(spacer)

		if i % 2 == 1 and i < modules.size() - 1:
			var row_spacer = Control.new()
			row_spacer.custom_minimum_size = Vector2(0, 15)
			modules_container.add_child(row_spacer)

func create_module_card(module: TrainingGenerator.TrainingModule, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.name = "ModuleCard" + str(index)
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

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	card.add_child(content)

	var header = HBoxContainer.new()
	content.add_child(header)

	var flag = GeoUtils.create_flag_icon(module.theory_tile.country, 24.0)
	if flag:
		header.add_child(flag)

	var country_display_name = countries_map.get(module.theory_tile.country.to_lower(), module.theory_tile.country)
	var country_label = Label.new()
	country_label.text = "Module " + str(index + 1) + ": " + country_display_name + " - " + module.theory_tile.training_type
	country_label.add_theme_font_size_override("font_size", 20)
	country_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(country_label)

	var validate_btn = Button.new()
	validate_btn.text = "✓ Complete Module"
	validate_btn.custom_minimum_size = Vector2(150, 40)
	validate_btn.pressed.connect(_on_module_validated.bind(index, card))
	header.add_child(validate_btn)

	var tiles_container = HBoxContainer.new()
	tiles_container.add_theme_constant_override("separation", 100)
	content.add_child(tiles_container)

	var theory_tile = create_tile(module.theory_tile, "📚 Theory")
	tiles_container.add_child(theory_tile)
	var practice_tile = create_tile(module.practice_tile, "🎮 Practice")
	tiles_container.add_child(practice_tile)

	return card

func create_tile(tile: TrainingGenerator.TrainingTile, header_text: String) -> PanelContainer:
	var tile_panel = PanelContainer.new()
	tile_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var header = Label.new()
	header.text = header_text
	header.add_theme_font_size_override("font_size", 18)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile_content.add_child(header)

	var duration = Label.new()
	duration.text = str(tile.duration_minutes) + " minutes"
	duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile_content.add_child(duration)

	var open_btn = Button.new()
	if tile.type == "theory":
		open_btn.text = "📖 Open Document"
	else:
		open_btn.text = "🗺️ Open Map"
	open_btn.custom_minimum_size = Vector2(0, 35)
	open_btn.pressed.connect(_on_tile_opened.bind(tile))
	tile_content.add_child(open_btn)

	return tile_panel

func _on_tile_opened(tile: TrainingGenerator.TrainingTile):
	if tile.url != "":
		OS.shell_open(tile.url)
		print("Opening ", tile.type, " URL: ", tile.url)
	else:
		push_warning("No URL available for this tile")

# ============================================================
# VALIDATION
# ============================================================
func _on_module_validated(module_index: int, card: PanelContainer):
	var module = current_training_data["modules"][module_index]
	pending_validation_data = {
		"module_index": module_index,
		"card": card,
		"module": module
	}
	confirmation_popup.popup_centered()

func _on_validation_confirmed():
	var module = pending_validation_data["module"]
	var card = pending_validation_data["card"]
	var module_index = pending_validation_data["module_index"]
	print("Module ", module_index + 1, " completed FULLY!")
	TrainingHistory.update_training_entry(
		module.theory_tile.country, module.theory_tile.training_type,
		module.total_duration, true, countries_map
	)
	mark_module_as_completed(card, true)

func _on_validation_partial():
	var module = pending_validation_data["module"]
	var card = pending_validation_data["card"]
	var module_index = pending_validation_data["module_index"]
	print("Module ", module_index + 1, " completed PARTIALLY")
	TrainingHistory.update_training_entry(
		module.theory_tile.country, module.theory_tile.training_type,
		module.total_duration, false, countries_map
	)
	mark_module_as_completed(card, false)

func mark_module_as_completed(card: PanelContainer, fully_completed: bool):
	var style = StyleBoxFlat.new()
	if fully_completed:
		style.bg_color = Color(0.2, 0.3, 0.2)
		style.border_color = Color(0.3, 0.7, 0.3)
	else:
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

	var header = card.get_child(0).get_child(0)
	var validate_btn = header.get_child(1)
	validate_btn.disabled = true
	if fully_completed:
		validate_btn.text = "✓ Completed"
	else:
		validate_btn.text = "⚠ Partially Done"

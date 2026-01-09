extends TabContainer

const duels_detailed := "user://duels_detailed.json"
const profile := "user://profile.json"
const duels_filtered := "user://duels_filtered.json"
const MODE_MAP := {
	"Move": "StandardDuels",
	"NM": "NoMoveDuels",
	"NMPZ": "NMPZDuels"
}

@onready var duels_elo_chart = $ELO
@onready var date_start_slider: HSlider = get_parent().get_node("FilterModeAndDate/FiltersPanel/FiltersVBox/DateRange/DateStart/DateStartSlider")
@onready var date_end_slider: HSlider   = get_parent().get_node("FilterModeAndDate/FiltersPanel/FiltersVBox/DateRange/DateEnd/DateEndSlider")
@onready var date_start_label: Label = get_parent().get_node("FilterModeAndDate/FiltersPanel/FiltersVBox/DateRange/DateStart/DateStartLabel")
@onready var date_end_label: Label   = get_parent().get_node("FilterModeAndDate/FiltersPanel/FiltersVBox/DateRange/DateEnd/DateEndLabel")
@onready var move_btn: Button  = get_parent().get_node("FilterModeAndDate/FiltersPanel/FiltersVBox/ModeSelector/Move")
@onready var nm_btn: Button    = get_parent().get_node("FilterModeAndDate/FiltersPanel/FiltersVBox/ModeSelector/NM")
@onready var nmpz_btn: Button  = get_parent().get_node("FilterModeAndDate/FiltersPanel/FiltersVBox/ModeSelector/NMPZ")

var player_id: String = ""
var all_duels: Array = []
var filter_date_start: int = 0
var filter_date_end: int = 0
var filter_mode: String = "NM"
var is_first_init: bool = true  # Track if it's the first initialization

func _ready():
	_load_player_id()
	_load_duels_stats()
	
func _refresh():
	_load_player_id()
	_load_duels_stats()

func _load_player_id():
	var file = FileAccess.open(profile, FileAccess.READ)
	if file:
		var profile_data = JSON.parse_string(file.get_as_text())
		file.close()
		if profile_data and profile_data["user"].has("id"):
			player_id = profile_data["user"]["id"]
			print("Player ID loaded: ", player_id)

func _load_duels_stats():
	# Check if file exists
	if not FileAccess.file_exists(duels_detailed):
		print("duels_detailed.json file not found")
		duels_elo_chart.visible = false
		return
	
	# Load data
	var file = FileAccess.open(duels_detailed, FileAccess.READ)
	if not file:
		push_error("Cannot open duels_detailed.json")
		duels_elo_chart.visible = false
		return
	
	all_duels = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not all_duels or all_duels.size() == 0:
		print("No duels found in duels_detailed.json")
		duels_elo_chart.visible = false
		return
		
	_init_date_range()
	
func _init_date_range():
	# Get min/max dates from duels (sorted from most recent to oldest)
	var min_date = all_duels[-1]["date"]
	var max_date = all_duels[0]["date"]
	
	# Only reset to full range on first initialization
	if is_first_init:
		filter_date_start = min_date
		filter_date_end = max_date
		is_first_init = false
	
	# Update slider ranges (always update these)
	date_start_slider.min_value = min_date
	date_start_slider.max_value = max_date
	date_start_slider.step = 86400
	date_start_slider.value = filter_date_start  # Keep user's choice

	date_end_slider.min_value = min_date
	date_end_slider.max_value = max_date
	date_end_slider.step = 86400
	date_end_slider.value = filter_date_end  # Keep user's choice

	# Update labels
	date_start_label.text = format_unix_to_ymd(filter_date_start)
	date_end_label.text = format_unix_to_ymd(filter_date_end)

	print("Date range:", min_date, "→", max_date)
	print("Current filter:", filter_date_start, "→", filter_date_end)
	
func _on_move_pressed():
	filter_mode = "Move"
	_update_mode_button_colors()

func _on_nm_pressed():
	filter_mode = "NM"
	_update_mode_button_colors()

func _on_nmpz_pressed():
	filter_mode = "NMPZ"
	_update_mode_button_colors()

func _on_filter_pressed():
	if all_duels.is_empty():
		return

	var filtered_duels := []
	var wanted_mode :String = MODE_MAP[filter_mode]

	for duel in all_duels:
		var duel_date: int = duel["date"]
		var duel_mode: String = duel["mode"]

		if duel_date < filter_date_start or duel_date > filter_date_end:
			continue

		if duel_mode != wanted_mode:
			continue

		filtered_duels.append(duel)

	_write_filtered_file(filtered_duels)
	_refresh_stats_display()
	
func _write_filtered_file(duels: Array):
	var file = FileAccess.open(duels_filtered, FileAccess.WRITE)
	if not file:
		push_error("Cannot write duels_filtered.json")
		return

	file.store_string(JSON.stringify(duels, "\t"))
	file.close()

	print("Filtered duels written: %d" % duels.size())
	
func _on_date_start_changed(value: float):
	filter_date_start = int(value)
	if filter_date_start > filter_date_end:
		date_end_slider.value = filter_date_start
	date_start_label.text = format_unix_to_ymd(filter_date_start)

func _on_date_end_changed(value: float):
	filter_date_end = int(value)
	if filter_date_end < filter_date_start:
		date_start_slider.value = filter_date_end
	date_end_label.text   = format_unix_to_ymd(filter_date_end)
		
func format_unix_to_ymd(timestamp: int) -> String:
	var dt = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
	
func _update_mode_button_colors():
	# All buttons gray by default
	var inactive_color = Color(0.6, 0.6, 0.6)
	move_btn.self_modulate = inactive_color
	nm_btn.self_modulate = inactive_color
	nmpz_btn.self_modulate = inactive_color

	# Active button in blue
	var active_color = Color(0.2, 0.5, 1.0)
	match filter_mode:
		"Move":
			move_btn.self_modulate = active_color
		"NM":
			nm_btn.self_modulate = active_color
		"NMPZ":
			nmpz_btn.self_modulate = active_color

func _refresh_stats_display():
	var root = get_tree().root
	var country_tab = _find_node_by_name(root, "Country_Precision")
	var stats_tab = _find_node_by_name(root, "Tabs")
	if stats_tab:
		_refresh_node_recursive(country_tab)
		_refresh_node_recursive(stats_tab)
		print("Duels - Stats display refreshed")

func _refresh_node_recursive(node: Node) -> void:
	if node.has_method("_refresh"):
		node._refresh()
	
	for child in node.get_children():
		_refresh_node_recursive(child)

func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, node_name)
		if result:
			return result
	return null

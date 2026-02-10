extends TabContainer

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
var is_first_init: bool = true

func _ready():
	player_id = FileManager.load_player_id()
	_load_duels_stats()

func _refresh():
	player_id = FileManager.load_player_id()
	_load_duels_stats()

func _load_duels_stats():
	var duels_data = FileManager.load_json(FilePaths.DUELS_DETAILED)
	if duels_data == null or not duels_data is Array or duels_data.size() == 0:
		print("No duels found in duels_detailed.json")
		duels_elo_chart.visible = false
		return

	all_duels = duels_data
	_init_date_range()

func _init_date_range():
	var min_date = all_duels[-1]["date"]
	var max_date = all_duels[0]["date"]

	if is_first_init:
		filter_date_start = min_date
		filter_date_end = max_date
		is_first_init = false

	date_start_slider.min_value = min_date
	date_start_slider.max_value = max_date
	date_start_slider.step = 86400
	date_start_slider.value = filter_date_start

	date_end_slider.min_value = min_date
	date_end_slider.max_value = max_date
	date_end_slider.step = 86400
	date_end_slider.value = filter_date_end

	date_start_label.text = FileManager.unix_to_ymd(filter_date_start)
	date_end_label.text = FileManager.unix_to_ymd(filter_date_end)

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

	FileManager.save_json(FilePaths.DUELS_FILTERED, filtered_duels)
	print("Filtered duels written: %d" % filtered_duels.size())
	_refresh_stats_display()

func _on_date_start_changed(value: float):
	filter_date_start = int(value)
	if filter_date_start > filter_date_end:
		date_end_slider.value = filter_date_start
	date_start_label.text = FileManager.unix_to_ymd(filter_date_start)

func _on_date_end_changed(value: float):
	filter_date_end = int(value)
	if filter_date_end < filter_date_start:
		date_start_slider.value = filter_date_end
	date_end_label.text = FileManager.unix_to_ymd(filter_date_end)

func _update_mode_button_colors():
	var inactive_color = Color(0.6, 0.6, 0.6)
	move_btn.self_modulate = inactive_color
	nm_btn.self_modulate = inactive_color
	nmpz_btn.self_modulate = inactive_color

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
	var country_tab = NodeUtils.find_by_name(root, "Country_Precision")
	var stats_tab = NodeUtils.find_by_name(root, "Tabs")
	if stats_tab:
		NodeUtils.refresh_recursive(country_tab)
		NodeUtils.refresh_recursive(stats_tab)
		print("Duels - Stats display refreshed")

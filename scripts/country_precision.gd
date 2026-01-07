extends Control

const duels_detailed := "user://duels_filtered.json"
const profile := "user://profile.json"
const countries_polygons := "res://misc/countries_polygon.json"
const stats_detailed := "user://stats_detailed.json"

@onready var stats_container = $ScrollContainer/VBoxContainer
@onready var grid_container = GridContainer.new()

var player_id: String = ""
var country_geometries: Dictionary = {}
var exported_stats: Dictionary = {}

# Alpha-2 to country name mapping
var country_names = {
	"us": "United States", "ca": "Canada", "mx": "Mexico", "br": "Brazil", "ar": "Argentina",
	"cl": "Chile", "pe": "Peru", "co": "Colombia", "ec": "Ecuador", "bo": "Bolivia",
	"gb": "United Kingdom", "fr": "France", "de": "Germany", "es": "Spain", "it": "Italy",
	"nl": "Netherlands", "be": "Belgium", "ch": "Switzerland", "at": "Austria", "pl": "Poland",
	"cz": "Czech Republic", "se": "Sweden", "no": "Norway", "fi": "Finland", "dk": "Denmark",
	"ru": "Russia", "ua": "Ukraine", "ro": "Romania", "gr": "Greece", "pt": "Portugal",
	"au": "Australia", "nz": "New Zealand", "jp": "Japan", "cn": "China", "kr": "South Korea",
	"th": "Thailand", "vn": "Vietnam", "my": "Malaysia", "sg": "Singapore", "id": "Indonesia",
	"ph": "Philippines", "in": "India", "bd": "Bangladesh", "pk": "Pakistan", "lk": "Sri Lanka",
	"za": "South Africa", "ke": "Kenya", "ma": "Morocco", "eg": "Egypt", "tn": "Tunisia",
	"tr": "Turkey", "il": "Israel", "jo": "Jordan", "ae": "UAE", "sa": "Saudi Arabia",
	"is": "Iceland", "ie": "Ireland", "rs": "Serbia", "hr": "Croatia", "si": "Slovenia",
	"sk": "Slovakia", "hu": "Hungary", "bg": "Bulgaria", "ee": "Estonia", "lv": "Latvia",
	"lt": "Lithuania", "by": "Belarus", "md": "Moldova", "al": "Albania", "mk": "North Macedonia",
	"ba": "Bosnia and Herzegovina", "me": "Montenegro", "xk": "Kosovo", "cy": "Cyprus",
	"mt": "Malta", "tw": "Taiwan", "hk": "Hong Kong", "mo": "Macau", "mn": "Mongolia",
	"kz": "Kazakhstan", "uz": "Uzbekistan", "kg": "Kyrgyzstan", "tj": "Tajikistan",
	"tm": "Turkmenistan", "af": "Afghanistan", "ir": "Iran", "iq": "Iraq", "sy": "Syria",
	"lb": "Lebanon", "ye": "Yemen", "om": "Oman", "kw": "Kuwait", "bh": "Bahrain", "qa": "Qatar",
	"np": "Nepal", "bt": "Bhutan", "mm": "Myanmar", "la": "Laos", "kh": "Cambodia", "bn": "Brunei",
	"tl": "Timor-Leste", "pg": "Papua New Guinea", "sn": "Senegal", "gh": "Ghana", "ng": "Nigeria",
	"ug": "Uganda", "tz": "Tanzania", "rw": "Rwanda", "et": "Ethiopia", "so": "Somalia",
	"dj": "Djibouti", "mw": "Malawi", "zm": "Zambia", "zw": "Zimbabwe", "bw": "Botswana",
	"na": "Namibia", "ao": "Angola", "mz": "Mozambique", "mg": "Madagascar", "uy": "Uruguay",
	"py": "Paraguay", "ve": "Venezuela", "sr": "Suriname", "gy": "Guyana", "gf": "French Guiana",
	"gt": "Guatemala", "hn": "Honduras", "sv": "El Salvador", "ni": "Nicaragua", "cr": "Costa Rica",
	"pa": "Panama", "cu": "Cuba", "do": "Dominican Republic", "jm": "Jamaica", "bs": "Bahamas",
	"ls": "Laos", "lu": "Luxemburg", "sz": "Eswatini", "cw": "Curaçao", "pr": "Puerto Rico"
}

func _ready():
	_load_country_geometries()
	_load_player_id()
	_load_country_stats()

func _refresh():
	_load_country_geometries()
	_load_player_id()
	_load_country_stats()

func _load_country_geometries():
	var file = FileAccess.open(countries_polygons, FileAccess.READ)
	if not file:
		push_error("Cannot open countries.polygon.json")
		return
	
	country_geometries = JSON.parse_string(file.get_as_text())
	file.close()
	print("Loaded %d country geometries" % country_geometries.size())

func _load_player_id():
	var file = FileAccess.open(profile, FileAccess.READ)
	if file:
		var profile_data = JSON.parse_string(file.get_as_text())
		file.close()
		if profile_data and profile_data["user"].has("id"):
			player_id = profile_data["user"]["id"]
	print("Player ID loaded")

func _load_country_stats():
	exported_stats.clear()
	
	if not FileAccess.file_exists(duels_detailed):
		print("duels_detailed.json file not found")
		_display_no_data()
		return
		

	var file = FileAccess.open(duels_detailed, FileAccess.READ)
	if not file:
		push_error("Cannot open duels_detailed.json")
		_display_no_data()
		return

	var duels_data = JSON.parse_string(file.get_as_text())
	file.close()

	if not duels_data or duels_data.size() == 0:
		print("No duels found")
		_display_no_data()
		return

	# Analyze all duels
	var player_stats = {}
	var opponent_stats = {}

	for duel in duels_data:
		_analyze_duel(duel, player_stats, opponent_stats)

	# Display results
	_display_country_stats(player_stats, opponent_stats)

func _analyze_duel(duel, player_stats: Dictionary, opponent_stats: Dictionary):
	if not duel.has("rounds"):
		return

	# Process each round with optimized structure
	for round in duel["rounds"]:
		var correct_country = round["actualCountry"]
		
		# Player stats
		if round.has("player") and round["player"].size() > 0:
			var guessed_country = round["player"]["guessedCountry"]
			var distance = round["player"]["distance"]
			var score = round["player"]["score"]
			_update_stats(player_stats, correct_country, guessed_country, distance, score)
		
		# Opponent stats
		if round.has("opponent") and round["opponent"].size() > 0:
			var guessed_country = round["opponent"]["guessedCountry"]
			var distance = round["opponent"]["distance"]
			var score = round["opponent"]["score"]
			_update_stats(opponent_stats, correct_country, guessed_country, distance, score)

func _update_stats(stats: Dictionary, correct_country: String, guessed_country: String, distance: float, score: int):
	if not stats.has(correct_country):
		stats[correct_country] = {
			"correct": 0,
			"total": 0,
			"correct_distance": 0.0,
			"total_score": 0,
			"correct_score": 0
		}
	
	stats[correct_country]["total"] += 1
	stats[correct_country]["total_score"] += score
	
	if guessed_country == correct_country:
		stats[correct_country]["correct"] += 1
		stats[correct_country]["correct_distance"] += distance
		stats[correct_country]["correct_score"] += score

func _display_country_stats(player_stats: Dictionary, opponent_stats: Dictionary):
	# Clear existing children
	for child in stats_container.get_children():
		child.queue_free()
	
	# Title
	var title_container = CenterContainer.new()
	var title = Label.new()
	title.text = "Country Performance Analysis"
	title.add_theme_font_size_override("font_size", 22)
	title_container.add_child(title)
	stats_container.add_child(title_container)
	
	var separator = HSeparator.new()
	stats_container.add_child(separator)
	
	# Create NEW GridContainer each time (don't reuse the member variable)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 25)
	stats_container.add_child(grid)
	
	# Update the member variable reference
	grid_container = grid
	
	# Collect all countries and sort by rounds played
	var country_list = []
	for country in player_stats.keys():
		var count = player_stats[country]["total"]
		country_list.append({"code": country, "count": count})
	
	country_list.sort_custom(func(a, b): return a["count"] > b["count"])
	
	# Display each country
	for item in country_list:
		var country = item["code"]
		_create_country_box(country, player_stats, opponent_stats)

	_save_stats_to_file()
	
	print("Saved detailed stats to stats_detailed.json")

func _create_country_box(country: String, player_stats: Dictionary, opponent_stats: Dictionary):
	var country_box = PanelContainer.new()
	country_box.custom_minimum_size = Vector2(650, 280)

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.15, 0.25, 0.4, 0.3)  # Bleu transparent
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	stylebox.content_margin_left = 15
	stylebox.content_margin_right = 15
	stylebox.content_margin_top = 15
	stylebox.content_margin_bottom = 15
	country_box.add_theme_stylebox_override("panel", stylebox)

	var box_vbox = VBoxContainer.new()
	box_vbox.add_theme_constant_override("separation", 10)
	country_box.add_child(box_vbox)

	# Header
	var header_hbox = HBoxContainer.new()
	var country_name = country_names[country.to_lower()] if country_names.has(country.to_lower()) else country
	var name_label = Label.new()
	name_label.text = country_name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(name_label)

	var rounds_label = Label.new()
	rounds_label.text = "%d rounds" % player_stats[country]["total"]
	rounds_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	rounds_label.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(rounds_label)
	box_vbox.add_child(header_hbox)

	# Calculate stats
	var player_correct = player_stats[country]["correct"]
	var player_total = player_stats[country]["total"]
	var player_accuracy = (float(player_correct) / player_total) * 100.0 if player_total > 0 else 0.0
	
	var opp_correct = opponent_stats[country]["correct"] if opponent_stats.has(country) else 0
	var opp_total = opponent_stats[country]["total"] if opponent_stats.has(country) else 0
	var opp_accuracy = (float(opp_correct) / opp_total) * 100.0 if opp_total > 0 else 0.0
	
	# Average distance when correct (in km)
	var player_avg_dist_km = 0.0
	var player_avg_score_correct = 0.0
	var player_avg_score_incorrect = 0.0
	if player_correct > 0:
		player_avg_dist_km = (player_stats[country]["correct_distance"] / player_correct) / 1000.0
		player_avg_score_correct = player_stats[country]["correct_score"] / player_correct
	if player_total - player_correct > 0:
		player_avg_score_incorrect = (player_stats[country]["total_score"] - player_stats[country]["correct_score"]) / (player_total - player_correct)
	else:
		player_avg_score_incorrect = player_avg_score_correct
	
	var opp_avg_dist_km = 0.0
	var opp_avg_score_correct = 0.0
	var opp_avg_score_incorrect = 0.0
	if opponent_stats.has(country) and opp_correct > 0:
		opp_avg_dist_km = (opponent_stats[country]["correct_distance"] / opp_correct) / 1000.0
		opp_avg_score_correct = opponent_stats[country]["correct_score"] / opp_correct
	if opp_total - opp_correct > 0:
		opp_avg_score_incorrect = (opponent_stats[country]["total_score"] - opponent_stats[country]["correct_score"]) / (opp_total - opp_correct)
	else:
		opp_avg_score_incorrect = opp_avg_score_correct
	
	# Score stats
	var player_avg_score = float(player_stats[country]["total_score"]) / player_total if player_total > 0 else 0.0
	var opp_avg_score = float(opponent_stats[country]["total_score"]) / opp_total if opp_total > 0 and opponent_stats.has(country) else 0.0
	var score_delta = player_avg_score - opp_avg_score
	var total_score_diff = score_delta * player_total

	# Accuracy section
	var acc_section = Label.new()
	acc_section.text = "Country Identification Accuracy"
	acc_section.add_theme_font_size_override("font_size", 15)
	acc_section.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	box_vbox.add_child(acc_section)

	_add_stat_bar(box_vbox, "You:", player_accuracy, Color.CYAN, "%.1f%% (%d/%d)" % [player_accuracy, player_correct, player_total])
	_add_stat_bar(box_vbox, "Opponent:", opp_accuracy, Color.ORANGE_RED, "%.1f%% (%d/%d)" % [opp_accuracy, opp_correct, opp_total])

	# Average distance section
	var dist_section = Label.new()
	dist_section.text = "Average Distance and scores (when country found)"
	dist_section.add_theme_font_size_override("font_size", 15)
	dist_section.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	box_vbox.add_child(dist_section)

	var dist_hbox = HBoxContainer.new()
	dist_hbox.add_theme_constant_override("separation", 30)
	
	var player_dist_label = Label.new()
	player_dist_label.text = "You: %.1f km" % player_avg_dist_km
	player_dist_label.add_theme_color_override("font_color", Color.CYAN)
	player_dist_label.add_theme_font_size_override("font_size", 14)
	dist_hbox.add_child(player_dist_label)
	
	var opp_dist_label = Label.new()
	opp_dist_label.text = "Opponent: %.1f km" % opp_avg_dist_km
	opp_dist_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	opp_dist_label.add_theme_font_size_override("font_size", 14)
	dist_hbox.add_child(opp_dist_label)
	
	box_vbox.add_child(dist_hbox)

	# Score difference section
	var score_section = Label.new()
	score_section.text = "Score Performance"
	score_section.add_theme_font_size_override("font_size", 15)
	score_section.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	box_vbox.add_child(score_section)

	var score_avg_hbox = HBoxContainer.new()
	score_avg_hbox.add_theme_constant_override("separation", 30)
	
	var player_score_label = Label.new()
	player_score_label.text = "You: %.1f points" % player_avg_score
	player_score_label.add_theme_color_override("font_color", Color.CYAN)
	player_score_label.add_theme_font_size_override("font_size", 14)
	score_avg_hbox.add_child(player_score_label)
	
	box_vbox.add_child(score_avg_hbox)
	
	var opp_score_label = Label.new()
	opp_score_label.text = "Opponent: %.1f points" % opp_avg_score
	opp_score_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	opp_score_label.add_theme_font_size_override("font_size", 14)
	score_avg_hbox.add_child(opp_score_label)
	
	var score_hbox = HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 30)
	
	var delta_label = Label.new()
	delta_label.text = "Avg delta: %+.0f pts/round" % score_delta
	delta_label.add_theme_font_size_override("font_size", 14)
	delta_label.add_theme_color_override("font_color", Color.GREEN if score_delta >= 0 else Color.RED)
	score_hbox.add_child(delta_label)
	
	var total_label = Label.new()
	total_label.text = "Total difference: %+.0f pts" % total_score_diff
	total_label.add_theme_font_size_override("font_size", 14)
	total_label.add_theme_color_override("font_color", Color.GREEN if total_score_diff >= 0 else Color.RED)
	score_hbox.add_child(total_label)
	
	box_vbox.add_child(score_hbox)

# --- EXPORT STATS ---
	var country_code := country

	exported_stats[country_code] = {
		"precision": {
			"player": player_accuracy,
			"opponent": opp_accuracy
		},
		"avg_region_km": {
			"player": player_avg_dist_km,
			"opponent": opp_avg_dist_km
		},
		"avg_score": {
			"player": player_avg_score,
			"opponent": opp_avg_score
		},
		"avg_score_correct": {
			"player": player_avg_score_correct,
			"opponent": opp_avg_score_correct
		},
		"avg_score_incorrect": {
			"player": player_avg_score_incorrect,
			"opponent": opp_avg_score_incorrect
		},
		"score_delta": {
			"avg": score_delta,
			"total": total_score_diff
		}
	}

	grid_container.add_child(country_box)

func _add_stat_bar(parent: VBoxContainer, label_text: String, value: float, bar_color: Color, score_text: String):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90, 0)
	label.add_theme_color_override("font_color", bar_color)
	hbox.add_child(label)
	
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = value
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(300, 20)
	bar.self_modulate = bar_color
	hbox.add_child(bar)
	
	var score_label = Label.new()
	score_label.text = score_text
	score_label.custom_minimum_size = Vector2(130, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(score_label)
	
	parent.add_child(hbox)

func _display_no_data():
	for child in stats_container.get_children():
		child.queue_free()

	var label = Label.new()
	label.text = "No data available.\nLoad duels from the Games tab."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	stats_container.add_child(label)
	
func _save_stats_to_file():
	var file = FileAccess.open(stats_detailed, FileAccess.WRITE)
	if not file:
		push_error("Cannot write stats_detailed.json")
		return

	file.store_string(JSON.stringify(exported_stats, "\t"))
	file.close()

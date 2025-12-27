extends Control

const duels_detailed := "user://duels_detailed.json"
const profile := "user://profile.json"

@onready var stats_container = $ScrollContainer/VBoxContainer
@onready var grid_container = GridContainer.new()  # Conteneur pour les colonnes

var player_id: String = ""

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
	"pa": "Panama", "cu": "Cuba", "do": "Dominican Republic", "jm": "Jamaica"
}

func _ready():
	_load_player_id()
	_load_country_stats()

func _refresh():
	_load_player_id()
	_load_country_stats()

func _load_player_id():
	var file = FileAccess.open(profile, FileAccess.READ)
	if file:
		var profile_data = JSON.parse_string(file.get_as_text())
		file.close()
		if profile_data and profile_data["user"].has("id"):
			player_id = profile_data["user"]["id"]

func _load_country_stats():
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
	var player_stats = {}  # {country: {total_score: X, count: Y}}
	var opponent_stats = {}

	for duel in duels_data:
		_analyze_duel(duel, player_stats, opponent_stats)

	# Display results
	_display_country_stats(player_stats, opponent_stats)

func _analyze_duel(duel, player_stats: Dictionary, opponent_stats: Dictionary):
	if not duel.has("rounds") or not duel.has("teams"):
		return

	# Find player and opponent
	var player_guesses = []
	var opponent_guesses = []

	for team in duel["teams"]:
		for player in team["players"]:
			if player["playerId"] == player_id:
				player_guesses = player["guesses"] if player.has("guesses") else []
			else:
				opponent_guesses = player["guesses"] if player.has("guesses") else []

	# Analyze each round
	for round in duel["rounds"]:
		if not round.has("panorama") or not round["panorama"].has("countryCode"):
			continue

		var country = round["panorama"]["countryCode"].to_lower()
		var round_num = round["roundNumber"]

		# Find player's score for this round
		for guess in player_guesses:
			if guess["roundNumber"] == round_num and guess.has("score"):
				if not player_stats.has(country):
					player_stats[country] = {"total_score": 0, "count": 0}
				player_stats[country]["total_score"] += guess["score"]
				player_stats[country]["count"] += 1
				break

		# Find opponent's score for this round
		for guess in opponent_guesses:
			if guess["roundNumber"] == round_num and guess.has("score"):
				if not opponent_stats.has(country):
					opponent_stats[country] = {"total_score": 0, "count": 0}
				opponent_stats[country]["total_score"] += guess["score"]
				opponent_stats[country]["count"] += 1
				break

func _display_country_stats(player_stats: Dictionary, opponent_stats: Dictionary):
	# Clear existing children
	for child in stats_container.get_children():
		child.queue_free()

	# Titre centré
	var title_container = CenterContainer.new()
	var title = Label.new()
	title.text = "Average Score by Country"
	title.add_theme_font_size_override("font_size", 20)
	title_container.add_child(title)
	stats_container.add_child(title_container)

	var separator = HSeparator.new()
	stats_container.add_child(separator)

	# GridContainer pour les colonnes
	grid_container.columns = 2
	grid_container.add_theme_constant_override("h_separation", 20)
	grid_container.add_theme_constant_override("v_separation", 20)
	stats_container.add_child(grid_container)

	# Collect all countries and sort by rounds played
	var country_list = []
	for country in player_stats.keys():
		var count = player_stats[country]["count"]
		country_list.append({"code": country, "count": count})

	country_list.sort_custom(func(a, b): return a["count"] > b["count"])

	# Display each country
	for item in country_list:
		var country = item["code"]
		_create_country_box(country, player_stats, opponent_stats)

func _create_country_box(country: String, player_stats: Dictionary, opponent_stats: Dictionary):
	# Country container
	var country_box = PanelContainer.new()
	country_box.custom_minimum_size = Vector2(625, 200)

	# Style: fond semi-transparent
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0.25)
	stylebox.corner_radius_top_left = 10
	stylebox.corner_radius_top_right = 10
	stylebox.corner_radius_bottom_left = 10
	stylebox.corner_radius_bottom_right = 10
	stylebox.content_margin_left = 10
	stylebox.content_margin_right = 10
	stylebox.content_margin_top = 10
	stylebox.content_margin_bottom = 10
	country_box.add_theme_stylebox_override("panel", stylebox)

	var box_vbox = VBoxContainer.new()
	box_vbox.add_theme_constant_override("separation", 5)
	country_box.add_child(box_vbox)

	# Header: Country name and rounds count
	var header_hbox = HBoxContainer.new()
	var country_name = country_names[country] if country_names.has(country) else country.to_upper()
	var name_label = Label.new()
	name_label.text = country_name
	name_label.add_theme_font_size_override("font_size", 25)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(name_label)

	var rounds_label = Label.new()
	rounds_label.text = "%d rounds" % player_stats[country]["count"]
	rounds_label.add_theme_color_override("font_color", Color.GRAY)
	header_hbox.add_child(rounds_label)
	box_vbox.add_child(header_hbox)

	# Ajouter un espace vertical
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box_vbox.add_child(spacer)

	# Calculate averages
	var player_avg = float(player_stats[country]["total_score"]) / player_stats[country]["count"]
	var opp_count = opponent_stats[country]["count"] if opponent_stats.has(country) else 0
	var opp_avg = 0.0
	if opp_count > 0:
		opp_avg = float(opponent_stats[country]["total_score"]) / opp_count
	var difference = player_avg - opp_avg

	# Player score bar
	var player_hbox = HBoxContainer.new()
	player_hbox.add_theme_constant_override("separation", 10)
	var player_label = Label.new()
	player_label.text = "You:"
	player_label.custom_minimum_size = Vector2(80, 0)
	player_label.add_theme_color_override("font_color", Color.CYAN)
	player_hbox.add_child(player_label)

	var player_bar = ProgressBar.new()
	player_bar.min_value = 0
	player_bar.max_value = 5000
	player_bar.value = player_avg
	player_bar.show_percentage = false
	player_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_bar.custom_minimum_size = Vector2(300, 20)
	player_bar.self_modulate = Color.CYAN
	player_bar.add_theme_constant_override("margin_left", 10)  # Abscisse fixe
	player_hbox.add_child(player_bar)

	var player_score_label = Label.new()
	player_score_label.text = "%d pts" % int(player_avg)
	player_score_label.custom_minimum_size = Vector2(70, 0)
	player_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_hbox.add_child(player_score_label)
	box_vbox.add_child(player_hbox)

	# Opponent score bar
	var opp_hbox = HBoxContainer.new()
	opp_hbox.add_theme_constant_override("separation", 10)
	var opp_label = Label.new()
	opp_label.text = "Opponent:"
	opp_label.custom_minimum_size = Vector2(80, 0)
	opp_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	opp_hbox.add_child(opp_label)

	var opp_bar = ProgressBar.new()
	opp_bar.min_value = 0
	opp_bar.max_value = 5000
	opp_bar.value = opp_avg
	opp_bar.show_percentage = false
	opp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_bar.custom_minimum_size = Vector2(300, 20)
	opp_bar.self_modulate=  Color.ORANGE_RED  # Couleur rouge
	opp_bar.add_theme_constant_override("margin_left", 10)  # Abscisse fixe
	opp_hbox.add_child(opp_bar)

	var opp_score_label = Label.new()
	opp_score_label.text = "%d pts" % int(opp_avg)
	opp_score_label.custom_minimum_size = Vector2(70, 0)
	opp_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opp_hbox.add_child(opp_score_label)
	box_vbox.add_child(opp_hbox)

	# Difference line
	var diff_label = Label.new()
	diff_label.text = "Difference: %+d pts" % int(difference)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 14)
	if difference > 0:
		diff_label.add_theme_color_override("font_color", Color.GREEN)
	elif difference < 0:
		diff_label.add_theme_color_override("font_color", Color.RED)
	else:
		diff_label.add_theme_color_override("font_color", Color.GRAY)
	box_vbox.add_child(diff_label)

	# Add to grid
	grid_container.add_child(country_box)

func _display_no_data():
	for child in stats_container.get_children():
		child.queue_free()

	var label = Label.new()
	label.text = "No data available.\nLoad duels from the Games tab."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	stats_container.add_child(label)

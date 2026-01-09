extends Control

const duels_detailed := "user://duels_filtered.json"
const profile := "user://profile.json"
const countries_polygons := "res://misc/countries_polygon.json"
const stats_detailed := "user://stats_detailed.json"
const countries_names_path := "res://misc/countries.json"

# UI References
@onready var map_container = $MapContainer
@onready var metric_selector = $MetricSelector

# Data
var player_id: String = ""
var country_geometries: Dictionary = {}
var country_stats: Dictionary = {}
var current_metric: String = "global_relative_score"
var hovered_country: String = ""
var global_min_score := 0.0
var global_max_score := 0.0
var country_names: Dictionary = {}


# Map rendering
var map_offset: Vector2 = Vector2.ZERO
var map_scale: float = 1.0
var min_lon: float = -180.0
var max_lon: float = 180.0
var min_lat: float = -90.0
var max_lat: float = 90.0

# Colors
var color_bad = Color(0.8, 0.2, 0.2)      # Red
var color_neutral = Color(0.6, 0.6, 0.6)  # Gray
var color_good = Color(0.2, 0.8, 0.2)     # Green


func _ready():
	_setup_ui()
	_load_country_names()
	_load_country_geometries()
	_load_player_id()
	_load_country_stats()

func _refresh():
	_setup_ui()
	_load_country_names()
	_load_country_geometries()
	_load_player_id()
	_load_country_stats()

func _setup_ui():
	# Create metric selector panel
	var selector_panel = PanelContainer.new()
	selector_panel.anchor_left = 0.0
	selector_panel.anchor_right = 0.0
	selector_panel.anchor_top = 1.0
	selector_panel.anchor_bottom = 1.0
	selector_panel.position = Vector2(20, -300)
	selector_panel.custom_minimum_size = Vector2(200, 140)


	
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	selector_panel.add_theme_stylebox_override("panel", stylebox)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	selector_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Select Metric"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Metric buttons
	_create_metric_button(vbox, "precision", "Your Precision Score")
	_create_metric_button(vbox, "relative_precision", "Precision vs Opponent")
	_create_metric_button(vbox, "regionguess", "Regionguess Performance")
	_create_metric_button(vbox, "global_absolute_score", "Total Score Difference")
	_create_metric_button(vbox, "global_relative_score", "Score Diff per Round")
	
	add_child(selector_panel)

func _load_country_names():
	var file = FileAccess.open(countries_names_path, FileAccess.READ)
	if not file:
		push_error("Cannot open countries.json")
		return

	country_names = JSON.parse_string(file.get_as_text())
	file.close()


func _create_metric_button(parent: VBoxContainer, metric_id: String, label_text: String):
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 24)
	btn.add_theme_font_size_override("font_size", 12)
	
	# Style du bouton actif
	btn.modulate = Color(1,1,1,0.5)  # semi-transparent par défaut
	btn.pressed.connect(_on_metric_changed.bind(metric_id))
	parent.add_child(btn)
	
	# Stocker le bouton pour mettre à jour son style plus tard
	if not has_meta("metric_buttons"):
		set_meta("metric_buttons", [])
	get_meta("metric_buttons").append({"id": metric_id, "btn": btn})

	# Mettre à jour l'état visuel
	_update_metric_buttons()

func _update_metric_buttons():
	var buttons = get_meta("metric_buttons")
	if buttons == null:
		return
	for entry in buttons:
		var btn = entry["btn"]
		if entry["id"] == current_metric:
			btn.modulate = Color(1,1,1,0.9)  # fond plus clair pour actif
		else:
			btn.modulate = Color(1,1,1,0.5)  # fond par défaut


func _on_metric_changed(metric_id: String):
	current_metric = metric_id
	_update_metric_buttons()
	queue_redraw()
	print("Metric changed to: ", metric_id)

func _load_country_geometries():
	var file = FileAccess.open(countries_polygons, FileAccess.READ)
	if not file:
		push_error("Cannot open countries_polygon.json")
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

func _load_country_stats():
	country_stats.clear()
	
	if not FileAccess.file_exists(duels_detailed):
		print("duels_detailed.json file not found")
		return

	var file = FileAccess.open(duels_detailed, FileAccess.READ)
	if not file:
		push_error("Cannot open duels_detailed.json")
		return

	var duels_data = JSON.parse_string(file.get_as_text())
	file.close()

	if not duels_data or duels_data.size() == 0:
		print("No duels found")
		return

	# Analyze all duels
	var player_stats = {}
	var opponent_stats = {}

	for duel in duels_data:
		_analyze_duel(duel, player_stats, opponent_stats)

	# Process stats for each country
	for country in player_stats.keys():
		_process_country_stats(country, player_stats, opponent_stats)
		
	global_min_score = INF
	global_max_score = -INF

	for c in country_stats.values():
		global_min_score = min(global_min_score, c["global_absolute_score"])
		global_max_score = max(global_max_score, c["global_absolute_score"])


	queue_redraw()
	print("Country stats loaded for %d countries" % country_stats.size())

func _analyze_duel(duel, player_stats: Dictionary, opponent_stats: Dictionary):
	if not duel.has("rounds"):
		return

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

func _process_country_stats(country: String, player_stats: Dictionary, opponent_stats: Dictionary):
	var player_correct = player_stats[country]["correct"]
	var player_total = player_stats[country]["total"]
	var player_accuracy = (float(player_correct) / player_total) * 100.0 if player_total > 0 else 0.0
	
	var opp_correct = opponent_stats[country]["correct"] if opponent_stats.has(country) else 0
	var opp_total = opponent_stats[country]["total"] if opponent_stats.has(country) else 0
	var opp_accuracy = (float(opp_correct) / opp_total) * 100.0 if opp_total > 0 else 0.0
	
	# Average scores
	var player_avg_score = float(player_stats[country]["total_score"]) / player_total if player_total > 0 else 0.0
	var opp_avg_score = float(opponent_stats[country]["total_score"]) / opp_total if opp_total > 0 and opponent_stats.has(country) else 0.0
	
	# Regionguess performance (when country found)
	var player_avg_score_correct = 0.0
	var opp_avg_score_correct = 0.0
	if player_correct > 0:
		player_avg_score_correct = float(player_stats[country]["correct_score"]) / player_correct
	if opp_correct > 0 and opponent_stats.has(country):
		opp_avg_score_correct = float(opponent_stats[country]["correct_score"]) / opp_correct
	
	var mean_score_correct = (player_avg_score_correct + opp_avg_score_correct) / 2.0 if (player_correct + opp_correct) > 0 else 1.0
	var regionguess_performance = (player_avg_score_correct - opp_avg_score_correct) / mean_score_correct if mean_score_correct > 0 else 0.0
	var regionguess_diff = 0.0
	if player_correct > 0 and opp_correct > 0:
		regionguess_diff = player_avg_score_correct - opp_avg_score_correct
	
	# Score deltas
	var score_delta = player_avg_score - opp_avg_score
	var total_score_diff = score_delta * player_total
	
	country_stats[country] = {
		"precision": player_accuracy,
		"relative_precision": player_accuracy - opp_accuracy,
		"regionguess_perf": regionguess_performance * 100.0,  # As percentage
		"regionguess": regionguess_diff,
		"global_absolute_score": total_score_diff,
		"global_relative_score": score_delta,
		"player_accuracy": player_accuracy,
		"opponent_accuracy": opp_accuracy,
		"player_avg_score": player_avg_score,
		"opponent_avg_score": opp_avg_score,
		"player_avg_score_correct": player_avg_score_correct,
		"opponent_avg_score_correct": opp_avg_score_correct,
		"total_rounds": player_total
	}

func _input(event):
	if event is InputEventMouseMotion:
		var local_pos = get_global_mouse_position() - global_position
		_check_country_hover(local_pos)

func _check_country_hover(mouse_pos: Vector2):
	var old_hovered = hovered_country
	hovered_country = ""
	
	# Check each country polygon
	for country_code in country_geometries.keys():
		if not country_stats.has(country_code):
			continue
			
		var geometry = country_geometries[country_code]
		if _point_in_country(mouse_pos, geometry):
			hovered_country = country_code
			break
	
	if old_hovered != hovered_country:
		queue_redraw()

func _point_in_country(point: Vector2, geometry) -> bool:
	return _point_in_geometry_recursive(point, geometry)
	
func _point_in_geometry_recursive(point: Vector2, data) -> bool:
	if data is Array and data.size() > 0:
		# Cas final : liste de coordonnées [lon, lat]
		if data[0] is Array and data[0].size() == 2 and typeof(data[0][0]) == TYPE_FLOAT:
			return _point_in_polygon(point, data)
		# Sinon : continuer à descendre (MultiPolygon, trous, etc.)
		for sub in data:
			if _point_in_geometry_recursive(point, sub):
				return true
	elif data is Dictionary and data.has("coordinates"):
		return _point_in_geometry_recursive(point, data["coordinates"])

	return false


func _point_in_polygon(point: Vector2, polygon) -> bool:
	if typeof(polygon) != TYPE_ARRAY or polygon.size() < 3:
		return false
	
	# Ray casting algorithm
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		var coord = polygon[i]
		if typeof(coord) != TYPE_ARRAY or coord.size() < 2:
			continue
			
		var lonlat_i = _extract_lon_lat(polygon[i])
		var lonlat_j = _extract_lon_lat(polygon[j])

		if lonlat_i == null or lonlat_j == null:
			j = i
			continue

		var xi = _lon_to_x(lonlat_i.x)
		var yi = _lat_to_y(lonlat_i.y)
		var xj = _lon_to_x(lonlat_j.x)
		var yj = _lat_to_y(lonlat_j.y)

		
		if ((yi > point.y) != (yj > point.y)) and (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi):
			inside = !inside
		
		j = i
	
	return inside

func _lon_to_x(lon: float) -> float:
	var map_width = size.x
	return ((lon - min_lon) / (max_lon - min_lon)) * map_width

func _lat_to_y(lat: float) -> float:
	var map_height = size.y
	return map_height - ((lat - min_lat) / (max_lat - min_lat)) * map_height

func _get_country_color(country_code: String) -> Color:
	# Si le pays n'est pas dans country_names, on ne le colore pas
	if not country_names.has(country_code.to_lower()):
		return Color(0.2, 0.2, 0.2) # Gris pour pays non considérés

	if not country_stats.has(country_code):
		return Color(0.2, 0.2, 0.2) # Gris pour pays sans stats

	var v = country_stats[country_code][current_metric]
	var t := 0.5

	match current_metric:
		"precision":
			t = clamp((v - 50.0) / 50.0, 0.0, 1.0)

		"relative_precision":
			t = clamp((v + 20.0) / 40.0, 0.0, 1.0)

		"regionguess":
			t = clamp((v + 200.0) / 400.0, 0.0, 1.0)

		"global_absolute_score":
			var m = max(abs(global_min_score), abs(global_max_score))
			t = clamp((v + m) / (2.0 * m), 0.0, 1.0)

		"global_relative_score":
			t = clamp((v + 500.0) / 1000.0, 0.0, 1.0)

	return color_bad.lerp(color_good, t)


func _draw():
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.1))
	
	# Draw all countries
	for country_code in country_geometries.keys():
		var color = _get_country_color(country_code)
		var is_hovered = (country_code == hovered_country)
		
		if is_hovered:
			color = color.lightened(0.3)
		
		_draw_country(country_code, color)
	
	# Draw tooltip for hovered country
	if hovered_country != "" and country_stats.has(hovered_country):
		_draw_tooltip()

func _draw_country(country_code: String, color: Color):
	var geometry = country_geometries[country_code]

	if geometry is Array:
		for poly in geometry:
			_draw_polygon_recursive(poly, color)
	elif geometry is Dictionary and geometry.has("coordinates"):
		_draw_polygon_recursive(geometry["coordinates"], color)

func _draw_polygon_recursive(data, color: Color):
	if data is Array and data.size() > 0:
		if data[0] is Array and data[0].size() == 2 and typeof(data[0][0]) == TYPE_FLOAT:
			_draw_polygon_data(data, color)
		else:
			for sub in data:
				_draw_polygon_recursive(sub, color)


func _draw_polygon_data(polygon_data, color: Color):
	if typeof(polygon_data) != TYPE_ARRAY:
		return
	
	var points = PackedVector2Array()
	for coord in polygon_data:
		var lonlat = _extract_lon_lat(coord)
		if lonlat == null:
			continue

		var x = _lon_to_x(lonlat.x)
		var y = _lat_to_y(lonlat.y)
		points.append(Vector2(x, y))

	
	if points.size() >= 3:
		draw_colored_polygon(points, color)
		draw_polyline(points, Color.BLACK, 0.5, true)

func _draw_tooltip():
	if not country_names.has(hovered_country.to_lower()):
		return # no tooltip for non-streetviewe countries
		
	var mouse_pos = get_local_mouse_position()
	var stats = country_stats[hovered_country]
	var country_name = country_names[hovered_country.to_lower()] if country_names.has(hovered_country.to_lower()) else hovered_country

	var lines = [
		{ "text": country_name, "color": Color.WHITE, "underline": false },
		{ "text": "Rounds: %d" % stats["total_rounds"], "color": Color.WHITE, "underline": false },
		{ "text": "", "color": Color.WHITE, "underline": false },

		{ "text": "Precision", "color": Color.WHITE, "underline": true },
		{ "text": "Your precision: %.1f%%" % stats["player_accuracy"], "color": Color.WHITE, "underline": false },
		{ "text": "Opp precision: %.1f%%" % stats["opponent_accuracy"], "color": Color.WHITE, "underline": false },
		{
			"text": "Precision diff: %+.1f%%" % stats["relative_precision"],
			"color": Color.GREEN if stats["relative_precision"] > 0 else Color.RED if stats["relative_precision"] < 0 else Color.WHITE,
			"underline": false
		},

		{ "text": "", "color": Color.WHITE, "underline": false },

		{ "text": "Regionguess", "color": Color.WHITE, "underline": true },
		{ "text": "Your avg score (found): %.1f" % stats["player_avg_score_correct"], "color": Color.WHITE, "underline": false },
		{ "text": "Opp avg score (found): %.1f" % stats["opponent_avg_score_correct"], "color": Color.WHITE, "underline": false },
		{
			"text": "Diff avg score (found): %+.1f" % stats["regionguess"],
			"color": Color.GREEN if stats["regionguess"] > 0 else Color.RED if stats["regionguess"] < 0 else Color.WHITE,
			"underline": false
		},

		{ "text": "", "color": Color.WHITE, "underline": false },

		{ "text": "Global", "color": Color.WHITE, "underline": true },
		{ "text": "Your avg score: %.1f" % stats["player_avg_score"], "color": Color.WHITE, "underline": false },
		{ "text": "Opp avg score: %.1f" % stats["opponent_avg_score"], "color": Color.WHITE, "underline": false },
		{
			"text": "Score diff / round: %+.1f" % stats["global_relative_score"],
			"color": Color.GREEN if stats["global_relative_score"] > 0 else Color.RED if stats["global_relative_score"] < 0 else Color.WHITE,
			"underline": false
		},
		{
			"text": "Total score diff: %+.0f" % stats["global_absolute_score"],
			"color": Color.GREEN if stats["global_absolute_score"] > 0 else Color.RED if stats["global_absolute_score"] < 0 else Color.WHITE,
			"underline": false
		}
	]

	# --- Layout ---
	var font = ThemeDB.fallback_font
	var font_size = 14
	var line_height = 18
	var padding = 10
	var max_width = 0.0

	for l in lines:
		var w = font.get_string_size(l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		max_width = max(max_width, w)

	var tooltip_size = Vector2(max_width + padding * 2, lines.size() * line_height + padding * 2)
	var tooltip_pos = mouse_pos + Vector2(15, -tooltip_size.y / 2)

	if tooltip_pos.x + tooltip_size.x > size.x:
		tooltip_pos.x = mouse_pos.x - tooltip_size.x - 15
	tooltip_pos.y = clamp(tooltip_pos.y, 0, size.y - tooltip_size.y)

	var rect = Rect2(tooltip_pos, tooltip_size)
	draw_rect(rect, Color(0.1, 0.1, 0.15, 0.95))
	draw_rect(rect, Color.WHITE, false, 2)

	# --- Text ---
	var y = tooltip_pos.y + padding + font_size
	for l in lines:
		draw_string(font, Vector2(tooltip_pos.x + padding, y), l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, l["color"])
		if l["underline"] and l["text"] != "":
			var text_width = font.get_string_size(l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_line(
				Vector2(tooltip_pos.x + padding, y + 2),
				Vector2(tooltip_pos.x + padding + text_width, y + 2),
				l["color"],
				1.0
			)
		y += line_height

		
func _extract_lon_lat(coord):
	# Gère [lon, lat] ou [[lon, lat], ...]
	if typeof(coord) == TYPE_ARRAY and coord.size() > 0:
		if typeof(coord[0]) == TYPE_ARRAY:
			return _extract_lon_lat(coord[0])
		elif coord.size() >= 2:
			return Vector2(coord[0], coord[1])
	return null

extends Button

const duels := "user://duels.json"
const solo := "user://solo.json"
const duels_detailed := "user://duels_detailed.json"
const duels_filtered := "user://duels_filtered.json"
const solo_detailed := "user://solo_detailed.json"
const ncfa_path := "user://ncfa.txt"
const profile := "user://profile.json"
const countries_polygons := "res://misc/countries_polygon.json"

var http_request: HTTPRequest
var games_to_analyze: Array = []
var current_index: int = 0
var detailed_data: Array = []
var ncfa_token: String = ""
var player_id: String = ""
var is_analyzing_duels: bool = true

# Queue system for loading both types
var duels_queue: Array = []
var solos_queue: Array = []
var total_games: int = 0

# Country detection
var country_geometries: Dictionary = {}

@onready var progress_popup = $ProgressPopup
@onready var progress_bar = $ProgressPopup/VBoxContainer/ProgressBar
@onready var progress_label = $ProgressPopup/VBoxContainer/ProgressLabel
@onready var confirm_popup = $ConfirmPopup
@onready var confirm_label = $ConfirmPopup/VBoxContainer/ConfirmLabel

func _ready():
	self.pressed.connect(_on_button_pressed)
	_load_country_geometries()
	_load_player_id()
	
func _refresh():
	_load_country_geometries()
	_load_player_id()

func _load_country_geometries():
	var file = FileAccess.open(countries_polygons, FileAccess.READ)
	if not file:
		push_error("Cannot open countries.polygon.json")
		return
	
	country_geometries = JSON.parse_string(file.get_as_text())
	file.close()
	print("Loaded %d country geometries for detection" % country_geometries.size())

func _load_player_id():
	var file = FileAccess.open(profile, FileAccess.READ)
	if file:
		var profile_data = JSON.parse_string(file.get_as_text())
		file.close()
		if profile_data and profile_data["user"].has("id"):
			player_id = profile_data["user"]["id"]
			print("Player ID loaded: ", player_id)

func _on_button_pressed():
	var popup = $Popup_analyze
	popup.popup_centered()

func _analyze_all_games(n_duels: int, n_solos: int):
	# Load NCFA token
	var file := FileAccess.open(ncfa_path, FileAccess.READ)
	ncfa_token = file.get_as_text().strip_edges()
	file.close()
	
	# Prepare queues
	duels_queue = _load_first_n_games(duels, n_duels) if n_duels > 0 else []
	solos_queue = _load_first_n_games(solo, n_solos) if n_solos > 0 else []
	total_games = duels_queue.size() + solos_queue.size()
	
	if total_games == 0:
		print("No games to analyze")
		return
	
	# Setup HTTP request
	if http_request == null:
		http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.request_completed.connect(_on_request_completed)
	
	# Show progress popup
	current_index = 0
	progress_bar.value = 0
	progress_bar.max_value = total_games
	progress_label.text = "Loading games: 0/%d (0%%)" % total_games
	progress_popup.popup_centered()
	
	# Start with duels if any
	if duels_queue.size() > 0:
		is_analyzing_duels = true
		games_to_analyze = duels_queue.duplicate()
		detailed_data.clear()
		_fetch_next_game()
	elif solos_queue.size() > 0:
		is_analyzing_duels = false
		games_to_analyze = solos_queue.duplicate()
		detailed_data.clear()
		_fetch_next_game()

func _fetch_next_game():
	if games_to_analyze.size() == 0:
		# Finished current type, save and move to next
		_save_current_type()
		
		# Check if we need to process the other type
		if is_analyzing_duels and solos_queue.size() > 0:
			# Switch to solos
			is_analyzing_duels = false
			games_to_analyze = solos_queue.duplicate()
			detailed_data.clear()
			_fetch_next_game()
		else:
			# All done
			_show_completion_message()
		return
	
	var game_id = games_to_analyze.pop_front()
	var url = ""
	
	if is_analyzing_duels:
		url = "https://game-server.geoguessr.com/api/duels/" + game_id
	else:
		url = "https://www.geoguessr.com/api/v3/games/" + game_id
	
	var headers := ["Cookie: _ncfa=" + ncfa_token]
	
	var game_type = "duel" if is_analyzing_duels else "solo"
	print("Récupération %s %d/%d: %s" % [game_type, current_index + 1, total_games, game_id])
	
	var error = http_request.request(url, headers)
	
	if error != OK:
		push_error("Erreur lors de la requête HTTP: " + str(error))
		current_index += 1
		_update_progress()
		call_deferred("_fetch_next_game")

func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		var game_type = "duel" if is_analyzing_duels else "solo"
		push_warning("Erreur HTTP %d pour le %s" % [response_code, game_type])
		current_index += 1
		_update_progress()
		call_deferred("_fetch_next_game")
		return
	
	var json_string = body.get_string_from_utf8()
	var game_data = JSON.parse_string(json_string)
	
	if game_data:
		if is_analyzing_duels:
			var optimized = _optimize_duel_data(game_data)
			if optimized:
				detailed_data.append(optimized)
		else:
			# For solo games, keep for now (to be optimized later if needed)
			detailed_data.append(game_data)
	else:
		var game_type = "duel" if is_analyzing_duels else "solo"
		push_warning("Impossible de parser le JSON du %s" % game_type)
	
	current_index += 1
	_update_progress()
	call_deferred("_fetch_next_game")

func _optimize_duel_data(duel: Dictionary) -> Dictionary:
	var raw_date: String = duel["rounds"][0]["startTime"]
	var dt := Time.get_datetime_dict_from_datetime_string(raw_date, false)
	dt.hour = 0
	dt.minute = 0
	dt.second = 0

	var day_timestamp := Time.get_unix_time_from_datetime_dict(dt)
	
	# Extract only essential information
	var optimized = {
		"gameId": duel["gameId"],
		"mapName": duel["options"]["map"]["name"] if duel.has("options") and duel["options"].has("map") and duel["options"]["map"] != null else "Unknown",
		"isRated": duel["options"]["isRated"] if duel.has("options") else false,
		"rounds": [],
		"mode": duel["options"]["competitiveGameMode"],
		"date": day_timestamp
	}
	
	# Find player and opponent guesses
	var player_guesses = []
	var opponent_guesses = []
	var player_rating_after = null
	
	if duel.has("teams"):
		for team in duel["teams"]:
			if team.has("players"):
				for player in team["players"]:
					if player["playerId"] == player_id:
						player_guesses = player["guesses"] if player.has("guesses") else []
						# Extract ELO
						if player.has("progressChange") and player["progressChange"] != null:
							var progress = player["progressChange"]
							if progress.has("rankedSystemProgress") and progress["rankedSystemProgress"] != null:
								var ranked = progress["rankedSystemProgress"]
								if ranked.has("ratingAfter"):
									player_rating_after = ranked["ratingAfter"]
					else:
						opponent_guesses = player["guesses"] if player.has("guesses") else []
	
	# Add rating if available
	if player_rating_after != null:
		optimized["playerRatingAfter"] = player_rating_after
	
	# Process each round
	if duel.has("rounds"):
		for round in duel["rounds"]:
			if not round.has("panorama"):
				continue
				
			if round["panorama"]["countryCode"] == "":
				continue
			
			var round_num = round["roundNumber"]
			var actual_country = round["panorama"]["countryCode"].to_upper()
			var actual_lat = round["panorama"]["lat"]
			var actual_lng = round["panorama"]["lng"]
			
			var round_data = {
				"roundNumber": round_num,
				"actualCountry": actual_country,
				"actualLat": actual_lat,
				"actualLng": actual_lng,
				"player": {},
				"opponent": {}
			}
			
			# Find player's guess for this round
			for guess in player_guesses:
				if guess["roundNumber"] == round_num:
					var guessed_country = _detect_country_from_coords(guess["lat"], guess["lng"])
					var distance = _haversine_distance(actual_lat, actual_lng, guess["lat"], guess["lng"])
					
					round_data["player"] = {
						"guessedCountry": guessed_country,
						"score": guess["score"] if guess.has("score") else 0,
						"distance": distance,
						"lat": guess["lat"],
						"lng": guess["lng"]
					}
					break
			
			# Find opponent's guess for this round
			for guess in opponent_guesses:
				if guess["roundNumber"] == round_num:
					var guessed_country = _detect_country_from_coords(guess["lat"], guess["lng"])
					var distance = _haversine_distance(actual_lat, actual_lng, guess["lat"], guess["lng"])
					
					round_data["opponent"] = {
						"guessedCountry": guessed_country,
						"score": guess["score"] if guess.has("score") else 0,
						"distance": distance,
						"lat": guess["lat"],
						"lng": guess["lng"]
					}
					break
			
			optimized["rounds"].append(round_data)
	
	return optimized

func _detect_country_from_coords(lat: float, lng: float) -> String:
	# Check each country's geometry
	for country_code in country_geometries.keys():
		var geometry = country_geometries[country_code]
		
		if geometry["type"] == "Polygon":
			if _point_in_polygon(lat, lng, geometry["coordinates"][0]):
				return country_code
		elif geometry["type"] == "MultiPolygon":
			for polygon in geometry["coordinates"]:
				if _point_in_polygon(lat, lng, polygon[0]):
					return country_code
	
	return "UNKNOWN"

func _point_in_polygon(lat: float, lng: float, polygon: Array) -> bool:
	# Ray casting algorithm
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		var xi = polygon[i][0]
		var yi = polygon[i][1]
		var xj = polygon[j][0]
		var yj = polygon[j][1]
		
		var intersect = ((yi > lat) != (yj > lat)) and (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
		if intersect:
			inside = !inside
		
		j = i
	
	return inside

func _haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
	# Calculate distance in meters using Haversine formula
	var R = 6371000.0  # Earth radius in meters
	var phi1 = deg_to_rad(lat1)
	var phi2 = deg_to_rad(lat2)
	var delta_phi = deg_to_rad(lat2 - lat1)
	var delta_lambda = deg_to_rad(lng2 - lng1)
	
	var a = sin(delta_phi / 2.0) * sin(delta_phi / 2.0) + \
			cos(phi1) * cos(phi2) * \
			sin(delta_lambda / 2.0) * sin(delta_lambda / 2.0)
	var c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	
	return R * c

func _update_progress():
	progress_bar.value = current_index
	var percentage = int((float(current_index) / total_games) * 100)
	progress_label.text = "Loading games: %d/%d (%d%%)" % [current_index, total_games, percentage]

func _save_current_type():
	if detailed_data.is_empty():
		return

	var output_file = duels_detailed if is_analyzing_duels else solo_detailed
	var existing: Array = []

	if is_analyzing_duels and FileAccess.file_exists(output_file):
		var f = FileAccess.open(output_file, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		existing = parsed if parsed is Array else []

	# Préfixe : nouveaux en premier
	var final_data = detailed_data + existing

	var file = FileAccess.open(output_file, FileAccess.WRITE)
	if not file:
		push_error("Impossible d'ouvrir %s" % output_file)
		return

	file.store_string(JSON.stringify(final_data, "\t"))
	file.close()

	# duels_filtered reste un snapshot
	if is_analyzing_duels:
		var f2 = FileAccess.open(duels_filtered, FileAccess.WRITE)
		f2.store_string(JSON.stringify(final_data, "\t"))
		f2.close()

	print("✓ %d %s ajoutés" % [
		detailed_data.size(),
		"duels" if is_analyzing_duels else "solos"
	])


func _show_completion_message():
	progress_popup.hide()
	
	var message = "✓ Loading complete!\n\n"
	if duels_queue.size() > 0:
		message += "%d duels loaded\n" % duels_queue.size()
	if solos_queue.size() > 0:
		message += "%d solos loaded" % solos_queue.size()
	
	confirm_label.text = message
	confirm_popup.popup_centered()
	
	get_parent().get_parent()._refresh_ui()

func _refresh_stats_display():
	var root = get_tree().root
	var stats_tab = _find_node_by_name(root, "Tabs")
	var dashboard_tab = _find_node_by_name(root, "Dashboard")
	if stats_tab:
		_refresh_node_recursive(stats_tab)
		print("Analyzer - Stats display refreshed")
	if dashboard_tab:
		_refresh_node_recursive(dashboard_tab)
		print("Analyzer - Dashboard display refreshed")

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

func _on_popup_validate():
	var n_duels = $Popup_analyze.get_n_duels()
	var n_solos = $Popup_analyze.get_n_solos()
	print("Analyzing %d duels and %d solos" % [n_duels, n_solos])
	_analyze_all_games(n_duels, n_solos)
	$Popup_analyze.hide()

func _load_first_n_games(file_path: String, n: int):
	if n <= 0:
		return []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Impossible d'ouvrir %s" % file_path)
		return []
	
	var all_games = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not all_games:
		push_error("Impossible de parser %s" % file_path)
		return []
	
	return all_games.slice(0, n)

func _on_confirm_ok_pressed():
	confirm_popup.hide()
	_refresh_stats_display()

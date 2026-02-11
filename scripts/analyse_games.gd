extends Button

var http_request: HTTPRequest
var games_to_analyze: Array = []
var current_index: int = 0
var detailed_data: Array = []
var ncfa_token: String = ""
var player_id: String = ""
var is_analyzing_duels: bool = true

var duels_queue: Array = []
var solos_queue: Array = []
var total_games: int = 0

var country_geometries: Dictionary = {}
var is_incremental: bool = false

@onready var progress_popup = $ProgressPopup
@onready var progress_bar = $ProgressPopup/VBoxContainer/ProgressBar
@onready var progress_label = $ProgressPopup/VBoxContainer/ProgressLabel
@onready var confirm_popup = $ConfirmPopup
@onready var confirm_label = $ConfirmPopup/VBoxContainer/ConfirmLabel

func _ready():
	self.pressed.connect(_on_button_pressed)
	_load_country_geometries()
	player_id = FileManager.load_player_id()

func _refresh():
	_load_country_geometries()
	player_id = FileManager.load_player_id()

func _load_country_geometries():
	country_geometries = FileManager.load_json(FilePaths.COUNTRIES_POLYGON, {})
	print("Loaded %d country geometries for detection" % country_geometries.size())

func _on_button_pressed():
	var popup = $Popup_analyze
	popup.popup_centered()

func _analyze_all_games(n_duels: int, n_solos: int, incremental: bool = false):
	is_incremental = incremental
	ncfa_token = FileManager.load_text(FilePaths.NCFA).strip_edges()

	duels_queue = _load_first_n_games(FilePaths.DUELS, n_duels) if n_duels > 0 else []
	solos_queue = _load_first_n_games(FilePaths.SOLO, n_solos) if n_solos > 0 else []
	total_games = duels_queue.size() + solos_queue.size()

	if total_games == 0:
		print("No games to analyze")
		return

	if http_request == null:
		http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.request_completed.connect(_on_request_completed)

	current_index = 0
	progress_bar.value = 0
	progress_bar.max_value = total_games
	progress_label.text = "Loading games: 0/%d (0%%)" % total_games
	progress_popup.popup_centered()

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
		_save_current_type()
		if is_analyzing_duels and solos_queue.size() > 0:
			is_analyzing_duels = false
			games_to_analyze = solos_queue.duplicate()
			detailed_data.clear()
			_fetch_next_game()
		else:
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

	var optimized = {
		"gameId": duel["gameId"],
		"mapName": duel["options"]["map"]["name"] if duel.has("options") and duel["options"].has("map") and duel["options"]["map"] != null else "Unknown",
		"isRated": duel["options"]["isRated"] if duel.has("options") else false,
		"rounds": [],
		"mode": duel["options"]["competitiveGameMode"],
		"date": day_timestamp
	}

	var player_guesses = []
	var opponent_guesses = []
	var player_rating_after = null

	if duel.has("teams"):
		for team in duel["teams"]:
			if team.has("players"):
				for player in team["players"]:
					if player["playerId"] == player_id:
						player_guesses = player["guesses"] if player.has("guesses") else []
						if player.has("progressChange") and player["progressChange"] != null:
							var progress = player["progressChange"]
							if progress.has("rankedSystemProgress") and progress["rankedSystemProgress"] != null:
								var ranked = progress["rankedSystemProgress"]
								if ranked.has("ratingAfter"):
									player_rating_after = ranked["ratingAfter"]
					else:
						opponent_guesses = player["guesses"] if player.has("guesses") else []

	if player_rating_after != null:
		optimized["playerRatingAfter"] = player_rating_after

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

			for guess in player_guesses:
				if guess["roundNumber"] == round_num:
					var guessed_country = GeoUtils.detect_country(guess["lat"], guess["lng"], country_geometries)
					var distance = GeoUtils.haversine_distance(actual_lat, actual_lng, guess["lat"], guess["lng"])
					round_data["player"] = {
						"guessedCountry": guessed_country,
						"score": guess["score"] if guess.has("score") else 0,
						"distance": distance,
						"lat": guess["lat"],
						"lng": guess["lng"]
					}
					break

			for guess in opponent_guesses:
				if guess["roundNumber"] == round_num:
					var guessed_country = GeoUtils.detect_country(guess["lat"], guess["lng"], country_geometries)
					var distance = GeoUtils.haversine_distance(actual_lat, actual_lng, guess["lat"], guess["lng"])
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

func _update_progress():
	progress_bar.value = current_index
	var percentage = int((float(current_index) / total_games) * 100)
	progress_label.text = "Loading games: %d/%d (%d%%)" % [current_index, total_games, percentage]

func _save_current_type():
	if detailed_data.is_empty():
		return

	var output_file = FilePaths.DUELS_DETAILED if is_analyzing_duels else FilePaths.SOLO_DETAILED

	if is_incremental:
		var existing = FileManager.load_json(output_file, [])
		if existing is Array:
			detailed_data = detailed_data + existing
		FileManager.save_json(output_file, detailed_data)
		if is_analyzing_duels:
			FileManager.save_json(FilePaths.DUELS_FILTERED, detailed_data)
	else:
		FileManager.save_json(output_file, detailed_data)
		if is_analyzing_duels:
			FileManager.save_json(FilePaths.DUELS_FILTERED, detailed_data)

	print("✓ %d %s sauvegardés" % [
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

	var api_node = NodeUtils.find_by_name(get_tree().root, "Connection API")
	if api_node and api_node.has_method("_refresh_ui"):
		api_node._refresh_ui()

func _refresh_stats_display():
	var root = get_tree().root
	var stats_tab = NodeUtils.find_by_name(root, "Tabs")
	var dashboard_tab = NodeUtils.find_by_name(root, "Dashboard")
	if stats_tab:
		NodeUtils.refresh_recursive(stats_tab)
		print("Analyzer - Stats display refreshed")
	if dashboard_tab:
		NodeUtils.refresh_recursive(dashboard_tab)
		print("Analyzer - Dashboard display refreshed")

func _on_popup_validate():
	var n_duels = $Popup_analyze.get_n_duels()
	var n_solos = $Popup_analyze.get_n_solos()
	print("Analyzing %d duels and %d solos" % [n_duels, n_solos])
	_analyze_all_games(n_duels, n_solos)
	$Popup_analyze.hide()

func _load_first_n_games(file_path: String, n: int):
	if n <= 0:
		return []
	var all_games = FileManager.load_json(file_path)
	if not all_games:
		push_error("Impossible de parser %s" % file_path)
		return []
	return all_games.slice(0, n)

func _on_confirm_ok_pressed():
	confirm_popup.hide()
	_refresh_stats_display()

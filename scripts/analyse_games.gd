extends Button

const duels := "user://duels.json"
const solo := "user://solo.json"
const duels_detailed := "user://duels_detailed.json"
const solo_detailed := "user://solo_detailed.json"
const ncfa_path := "user://ncfa.txt"

var http_request: HTTPRequest
var games_to_analyze: Array = []
var current_index: int = 0
var detailed_data: Array = []
var ncfa_token: String = ""
var is_analyzing_duels: bool = true

# Queue system for loading both types
var duels_queue: Array = []
var solos_queue: Array = []
var total_games: int = 0

@onready var progress_popup = $ProgressPopup
@onready var progress_bar = $ProgressPopup/VBoxContainer/ProgressBar
@onready var progress_label = $ProgressPopup/VBoxContainer/ProgressLabel
@onready var confirm_popup = $ConfirmPopup
@onready var confirm_label = $ConfirmPopup/VBoxContainer/ConfirmLabel

func _ready():
	self.pressed.connect(_on_button_pressed)

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
		detailed_data.append(game_data)
	else:
		var game_type = "duel" if is_analyzing_duels else "solo"
		push_warning("Impossible de parser le JSON du %s" % game_type)
	
	current_index += 1
	_update_progress()
	call_deferred("_fetch_next_game")

func _update_progress():
	progress_bar.value = current_index
	var percentage = int((float(current_index) / total_games) * 100)
	progress_label.text = "Loading games: %d/%d (%d%%)" % [current_index, total_games, percentage]

func _save_current_type():
	if detailed_data.size() == 0:
		return
	
	print("========================================================")
	var game_type = "duels" if is_analyzing_duels else "solo games"
	print("Sauvegarde de %d %s..." % [detailed_data.size(), game_type])
	
	var output_file = duels_detailed if is_analyzing_duels else solo_detailed
	var file = FileAccess.open(output_file, FileAccess.WRITE)
	if not file:
		push_error("Impossible d'ouvrir le fichier %s pour écriture" % output_file)
		return
	
	var json_string = JSON.stringify(detailed_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("✓ Données sauvegardées dans: %s" % output_file)
	print("✓ Nombre de %s sauvegardés: %d" % [game_type, detailed_data.size()])
	print("========================================================")

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
	var stats_tab = _find_node_by_name(root, "Stats")
	if stats_tab:
		_refresh_node_recursive(stats_tab)
		print("Stats display refreshed")


func _refresh_node_recursive(node: Node) -> void:
	# Si le node sait se rafraîchir, on le fait
	if node.has_method("_refresh"):
		node._refresh()

	# Parcours récursif
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
	# Refresh stats to display updated graphs
	_refresh_stats_display()

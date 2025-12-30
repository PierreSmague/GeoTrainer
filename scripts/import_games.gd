extends Button

const BASE_URL := "https://www.geoguessr.com/api/v4/"
const NCFA_PATH := "user://ncfa.txt"
const DUELS_FILE_PATH := "user://duels.json"
const SOLO_FILE_PATH := "user://solo.json"

var game_tokens_duels: Array = []
var game_tokens_solo: Array = []
var pagination_token: String = ""

@onready var http_request: HTTPRequest = get_parent().get_node("Tokens_duels_solo")
@onready var duels_label: Label = get_node("DuelsCount")
@onready var solo_label: Label = get_node("SoloCount")

var ncfa_token: String = ""


func _ready():
	pressed.connect(_on_button_pressed)

	# Ensure signal is connected only once
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	# Init progress bars
	duels_label.text = "Duels loaded: 0"
	solo_label.text = "Solo loaded: 0"


func _on_button_pressed():
	_load_ncfa()
	_start_fetch()


func _load_ncfa():
	# Load ncfa token from file
	if not FileAccess.file_exists(NCFA_PATH):
		push_error("ncfa.txt not found")
		return

	var file := FileAccess.open(NCFA_PATH, FileAccess.READ)
	ncfa_token = file.get_as_text().strip_edges()
	file.close()


func _start_fetch():
	# Reset state
	game_tokens_duels.clear()
	game_tokens_solo.clear()
	pagination_token = ""

	_process_page()


func _process_page():
	# Build request URL with pagination
	var url := BASE_URL + "feed/private"
	if pagination_token != "":
		url += "?paginationToken=" + pagination_token

	var headers := ["Cookie: _ncfa=" + ncfa_token]

	var err := http_request.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if err != OK:
		push_error("HTTPRequest failed: %s" % err)


func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		push_error("HTTP error %s" % response_code)
		return

	var response :Variant = JSON.parse_string(body.get_string_from_utf8())
	if response == null:
		push_error("Invalid JSON response")
		return

	# Read pagination token
	var token = response.get("paginationToken")
	pagination_token = token if token != null else ""

	var entries: Array = response.get("entries", [])

	for entry in entries:
		var payload_str: String = entry.get("payload", "")
		var payload_array : Variant= JSON.parse_string(payload_str)

		if payload_array == null or not payload_array is Array:
			continue

		for item in payload_array:
			var payload: Dictionary = item.get("payload", {})
			if not payload.has("gameMode"):
				continue

			match payload["gameMode"]:
				"Duels":
					if payload.has("gameId") and payload.has("competitiveGameMode"):
						game_tokens_duels.append(payload["gameId"])

				"Standard":
					if payload.has("gameToken"):
						game_tokens_solo.append(payload["gameToken"])


	# Update progress bars (heuristic-based, since API doesn't give totals)
	duels_label.text = "Duels loaded: %d" % game_tokens_duels.size()
	solo_label.text = "Solo loaded: %d" % game_tokens_solo.size()

	# Continue or finish
	if pagination_token == "" or pagination_token == null:
		_save_game_tokens()
	else:
		_process_page()


func _refresh_stats_display():
	var root = get_tree().root
	var stats_tab = _find_node_by_name(root, "AnalyzeGames")
	if stats_tab:
		_refresh_node_recursive(stats_tab)
		print("Analyzer refreshed")

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


func _save_game_tokens():
	# Save duels tokens
	var duels_file := FileAccess.open(DUELS_FILE_PATH, FileAccess.WRITE)
	if duels_file:
		duels_file.store_string(JSON.stringify(game_tokens_duels, "\t"))
		duels_file.close()

	# Save solo tokens
	var solo_file := FileAccess.open(SOLO_FILE_PATH, FileAccess.WRITE)
	if solo_file:
		solo_file.store_string(JSON.stringify(game_tokens_solo, "\t"))
		solo_file.close()

	print("Saved %d duels and %d solo games" %
		[game_tokens_duels.size(), game_tokens_solo.size()])
	get_parent().get_parent()._refresh_ui()
	_refresh_stats_display()

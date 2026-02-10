extends Button

const BASE_URL := "https://www.geoguessr.com/api/v4/feed/private"

@onready var http: HTTPRequest = HTTPRequest.new()

var ncfa := ""
var pagination_token := ""
var last_known_id := ""
var new_duel_ids: Array = []

func _ready():
	add_child(http)
	pressed.connect(_on_pressed)
	http.request_completed.connect(_on_feed_response)

func _on_pressed():
	ncfa = FileManager.load_text(FilePaths.NCFA).strip_edges()
	last_known_id = _load_last_duel_id()
	new_duel_ids.clear()
	pagination_token = ""
	_fetch_page()

func _load_last_duel_id() -> String:
	var data = FileManager.load_json(FilePaths.DUELS)
	if data and data is Array and data.size() > 0:
		return data[0]
	return ""

func _fetch_page():
	var url = BASE_URL
	if pagination_token != "":
		url += "?paginationToken=" + pagination_token
	http.request(url, ["Cookie: _ncfa=" + ncfa])

func _on_feed_response(result, code, headers, body):
	if code != 200:
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	pagination_token = json.get("paginationToken", "")

	for entry in json.get("entries", []):
		var payload = JSON.parse_string(entry.get("payload", ""))
		if not payload is Array:
			continue

		for item in payload:
			var p = item.get("payload", {})
			if p.get("gameMode") != "Duels" or not p.has("competitiveGameMode"):
				continue
			var id = p.get("gameId", "")
			if id == "":
				continue
			if id == last_known_id:
				_finalize_update()
				return
			new_duel_ids.append(id)

	if pagination_token == "":
		_finalize_update()
	else:
		_fetch_page()

func _finalize_update():
	if new_duel_ids.is_empty():
		return

	var duels = FileManager.load_json(FilePaths.DUELS, [])
	if not duels is Array:
		duels = []

	duels = new_duel_ids + duels
	FileManager.save_json(FilePaths.DUELS, duels)

	var analyzer = NodeUtils.find_by_name(get_tree().root, "AnalyzeGames")
	analyzer._analyze_all_games(new_duel_ids.size(), 0)

	var api_node = NodeUtils.find_by_name(get_tree().root, "Connection API")
	if api_node and api_node.has_method("_refresh_ui"):
		api_node._refresh_ui()

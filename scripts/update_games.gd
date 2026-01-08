extends Button

const BASE_URL := "https://www.geoguessr.com/api/v4/feed/private"
const NCFA_PATH := "user://ncfa.txt"
const DUELS_PATH := "user://duels.json"
const DUELS_DETAILED_PATH := "user://duels_detailed.json"

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
	_load_ncfa()
	last_known_id = _load_last_duel_id()
	new_duel_ids.clear()
	pagination_token = ""
	_fetch_page()

func _load_ncfa():
	ncfa = FileAccess.open(NCFA_PATH, FileAccess.READ).get_as_text().strip_edges()

func _load_last_duel_id() -> String:
	if not FileAccess.file_exists(DUELS_PATH):
		return ""
	var f = FileAccess.open(DUELS_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data[0] if data and data.size() > 0 else ""

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

	# --- Update duels.json (prepend)
	var duels := []
	if FileAccess.file_exists(DUELS_PATH):
		var f = FileAccess.open(DUELS_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		duels = parsed if parsed is Array else []
		f.close()

	duels = new_duel_ids + duels
	FileAccess.open(DUELS_PATH, FileAccess.WRITE).store_string(JSON.stringify(duels, "\t"))

	# --- Trigger analysis ONLY for new duels
	var analyzer = _find_node("AnalyzeGames")
	analyzer._analyze_all_games(new_duel_ids.size(), 0)
	
	get_parent().get_parent()._refresh_ui()

func _find_node(name: String) -> Node:
	return _find_node_rec(get_tree().root, name)

func _find_node_rec(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var r = _find_node_rec(c, name)
		if r:
			return r
	return null

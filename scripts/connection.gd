extends Button

const BASE_URL = "https://www.geoguessr.com/api/v3/"

func _ready():
	self.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	if FileAccess.file_exists(FilePaths.NCFA):
		_fetch_profile()
		return
	var popup = $Popup_ncfa
	popup.popup_centered()

func _save_ncfa(ncfa_string):
	var file = FileAccess.open(FilePaths.NCFA, FileAccess.WRITE)
	if file:
		file.store_string(ncfa_string)
		file.close()
		print("NCFA saved in ncfa.txt.")
		_fetch_profile()
	else:
		print("Error : impossible to create file ncfa.txt.")

func _fetch_profile():
	var ncfa_token := FileManager.load_text(FilePaths.NCFA).strip_edges()
	if ncfa_token == "":
		print("Error: cannot open NCFA file")
		return

	var http_request: HTTPRequest = get_parent().get_node("API_v3_profile")
	http_request.request_completed.connect(_on_request_completed)

	var headers := ["Cookie: _ncfa=" + ncfa_token]
	http_request.request(BASE_URL + "profiles", headers)

func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		print("Request error:", response_code, body.get_string_from_utf8())
		return

	var body_string: String = body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(body_string)

	if data == null:
		print("JSON parse error")
		print(body_string)
		return

	FileManager.save_json(FilePaths.PROFILE, data)
	print("Saved profile in profile.json.")

	var api_node = NodeUtils.find_by_name(get_tree().root, "Connection API")
	if api_node and api_node.has_method("_refresh_ui"):
		api_node._refresh_ui()

func _on_popup_validate():
	var ncfa = $Popup_ncfa/NCFA_input.text
	if ncfa.is_empty():
		print("Error : NCFA field is empty.")
		return

	_save_ncfa(ncfa)
	var api_node = NodeUtils.find_by_name(get_tree().root, "Connection API")
	if api_node and api_node.has_method("_refresh_ui"):
		api_node._refresh_ui()
	$Popup_ncfa.hide()

extends Button

# Path to user files
const NCFA_FILE_PATH = "user://ncfa.txt"
const PROFILE_FILE_PATH = "user://profile.json"
const BASE_URL = "https://www.geoguessr.com/api/v3/"

func _ready():
	self.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	# Check if file exists
	if FileAccess.file_exists(NCFA_FILE_PATH):
		_fetch_profile()  # Check directly API if ncfa exists
		return

	# Else open popup window
	var popup = $Popup_ncfa
	popup.popup_centered()

func _save_ncfa(ncfa_string):
	# Save NCFA file
	var file = FileAccess.open(NCFA_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(ncfa_string)
		file.close()
		print("NCFA saved in ncfa.txt.")
		_fetch_profile()
	else:
		print("Error : impossible to create file ncfa.txt.")
		

func _fetch_profile():
	# Read NCFA file
	var file := FileAccess.open(NCFA_FILE_PATH, FileAccess.READ)
	if file == null:
		print("Error: cannot open NCFA file")
		return

	var ncfa_token := file.get_as_text().strip_edges()
	file.close()

	# Récupérer le node HTTPRequest
	var http_request: HTTPRequest = get_parent().get_node("API_v3_profile")
	http_request.request_completed.connect(_on_request_completed)

	# Créer la requête avec cookie
	var headers := ["Cookie: _ncfa=" + ncfa_token]
	http_request.request(BASE_URL + "profiles", headers)


func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		print("Request error:", response_code, body.get_string_from_utf8())
		return

	var body_string: String = body.get_string_from_utf8()

	# Parsing JSON Godot 4
	var data: Variant = JSON.parse_string(body_string)

	if data == null:
		print("JSON parse error")
		print(body_string)
		return

	# Sauvegarde propre
	var profile_file := FileAccess.open(PROFILE_FILE_PATH, FileAccess.WRITE)
	if profile_file == null:
		print("Error: impossible to save profile.json")
		return

	# Re-serialisation JSON valide
	profile_file.store_string(JSON.stringify(data, "\t"))
	profile_file.close()

	print("Saved profile in profile.json.")
	get_parent().get_parent()._refresh_ui()

# Function called if validate is pushed
func _on_popup_validate():
	var ncfa = $Popup_ncfa/NCFA_input.text
	if ncfa.is_empty():
		print("Error : NCFA field is empty.")
		return

	_save_ncfa(ncfa)
	get_parent().get_parent()._refresh_ui()
	$Popup_ncfa.hide()  # Close popup

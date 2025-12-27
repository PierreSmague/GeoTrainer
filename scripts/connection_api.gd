extends VBoxContainer

const NCFA := "user://ncfa.txt"
const PROFILE := "user://profile.json"
const DUELS := "user://duels.json"
const SOLO := "user://solo.json"

@onready var btn_connection := $AuthSlot/Connection
@onready var profile_infos := $AuthSlot/Profile_infos
@onready var btn_import := $AuthSlot/ImportGames
@onready var btn_analyze := $AuthSlot/AnalyzeGames
@onready var nick_label = $AuthSlot/Profile_infos/Nick
@onready var country_label = $AuthSlot/Profile_infos/Country
@onready var level_label = $AuthSlot/Profile_infos/Level

func _ready():
	print(ProjectSettings.globalize_path("user://"))
	_refresh_ui()

func _refresh_ui():
	var has_ncfa := FileAccess.file_exists(NCFA)
	var has_profile := FileAccess.file_exists(PROFILE)
	var has_duels := FileAccess.file_exists(DUELS)
	var has_solo := FileAccess.file_exists(SOLO)

	btn_connection.visible = not has_ncfa or not has_profile

	profile_infos.visible = has_ncfa and has_profile
	if profile_infos.visible:
		var file = FileAccess.open(PROFILE, FileAccess.READ)
		var json = JSON.new()
		var parse_error = json.parse(file.get_as_text())
		file.close()

		if parse_error == OK:
			var profile_data = json.get_data()
			var user_data = profile_data.get("user", {})

			# Extract infos
			var nick = user_data.get("nick", "Inconnu")
			var country_code = user_data.get("countryCode", "N/A")
			var level = user_data.get("progress", {}).get("level", 0)

			# Update labels
			nick_label.text = str(nick)
			country_label.text = str(country_code)
			level_label.text = "Lvl " + str(int(level))

	btn_import.visible = (
		has_ncfa
		and has_profile
		and not (has_duels and has_solo)
	)
	
	btn_analyze.visible = (
		has_ncfa
		and has_profile
		and has_duels
		and has_solo
	)

extends VBoxContainer

@onready var btn_connection := $AuthSlot/Connection
@onready var profile_infos := $AuthSlot/Profile_infos
@onready var btn_import := $AuthSlot/ImportGames
@onready var btn_analyze := $AuthSlot/AnalyzeGames
@onready var btn_reset := $AuthSlot/ResetID
@onready var btn_update := $AuthSlot/UpdateGames
@onready var nick_label = $AuthSlot/Profile_infos/Nick
@onready var level_label = $AuthSlot/Profile_infos/Level

func _ready():
	print(ProjectSettings.globalize_path("user://"))
	_refresh_ui()

func _refresh_ui():
	var has_ncfa := FileAccess.file_exists(FilePaths.NCFA)
	var has_profile := FileAccess.file_exists(FilePaths.PROFILE)
	var has_duels := FileAccess.file_exists(FilePaths.DUELS)
	var has_solo := FileAccess.file_exists(FilePaths.SOLO)

	btn_connection.visible = not has_ncfa or not has_profile

	profile_infos.visible = has_ncfa and has_profile
	if profile_infos.visible:
		var profile_data = FileManager.load_json(FilePaths.PROFILE)
		if profile_data:
			var user_data = profile_data.get("user", {})
			var nick = user_data.get("nick", "Inconnu")
			var country_code = user_data.get("countryCode", "N/A")
			var level = user_data.get("progress", {}).get("level", 0)
			nick_label.text = str(nick)
			level_label.text = str(country_code).to_upper() + " | Lvl " + str(int(level))

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

	btn_update.visible = (
		has_ncfa
		and has_profile
		and has_duels
		and has_solo
	)

	btn_reset.visible = (
		has_ncfa
	)

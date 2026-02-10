class_name FileManager

static func load_json(path: String, fallback: Variant = null) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return fallback
	return parsed

static func save_json(path: String, data: Variant) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write to: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

static func load_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text = file.get_as_text()
	file.close()
	return text

static func load_player_id() -> String:
	var profile_data = load_json(FilePaths.PROFILE)
	if profile_data and profile_data is Dictionary and profile_data.has("user"):
		if profile_data["user"].has("id"):
			return profile_data["user"]["id"]
	return ""

static func unix_to_ymd(timestamp: int) -> String:
	var dt = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]

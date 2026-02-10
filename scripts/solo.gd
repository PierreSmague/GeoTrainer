extends TabContainer

@onready var top_maps_container = $Maps/ScrollContainer/VBoxContainer

func _ready():
	_load_solo_stats()

func _refresh():
	_load_solo_stats()

func _load_solo_stats():
	var solos_data = FileManager.load_json(FilePaths.SOLO_DETAILED)
	if solos_data == null or not solos_data is Array or solos_data.size() == 0:
		print("No solos found in solo_detailed.json")
		_display_no_data()
		return

	var map_counts = {}
	for game in solos_data:
		if game.has("mapName"):
			var map_name = game["mapName"]
			if map_counts.has(map_name):
				map_counts[map_name] += 1
			else:
				map_counts[map_name] = 1

	if map_counts.size() == 0:
		print("No maps found in solo games")
		_display_no_data()
		return

	var map_array = []
	for map_name in map_counts.keys():
		map_array.append({"name": map_name, "count": map_counts[map_name]})

	map_array.sort_custom(func(a, b): return a["count"] > b["count"])

	_display_top_maps(map_array)
	print("Solo stats loaded: %d unique maps" % map_counts.size())

func _display_top_maps(map_array: Array):
	for child in top_maps_container.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "Top 10 Most Played Maps"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_maps_container.add_child(title)

	var separator1 = HSeparator.new()
	top_maps_container.add_child(separator1)

	var top_count = min(10, map_array.size())
	for i in range(top_count):
		var map_entry = map_array[i]

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var rank_label = Label.new()
		rank_label.text = str(i + 1) + "."
		rank_label.custom_minimum_size = Vector2(30, 0)
		rank_label.add_theme_font_size_override("font_size", 16)
		hbox.add_child(rank_label)

		var name_label = Label.new()
		name_label.text = map_entry["name"]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 16)
		hbox.add_child(name_label)

		var count_label = Label.new()
		count_label.text = str(map_entry["count"]) + " games"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.custom_minimum_size = Vector2(100, 0)
		count_label.add_theme_font_size_override("font_size", 16)

		if i == 0:
			count_label.add_theme_color_override("font_color", Color.GOLD)
		elif i == 1:
			count_label.add_theme_color_override("font_color", Color.SILVER)
		elif i == 2:
			count_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			count_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)

		hbox.add_child(count_label)
		top_maps_container.add_child(hbox)

		if i < top_count - 1:
			var separator = HSeparator.new()
			top_maps_container.add_child(separator)

	var separator2 = HSeparator.new()
	top_maps_container.add_child(separator2)

	var total_label = Label.new()
	total_label.text = "Total unique maps: %d" % map_array.size()
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 14)
	total_label.add_theme_color_override("font_color", Color.GRAY)
	top_maps_container.add_child(total_label)

func _display_no_data():
	for child in top_maps_container.get_children():
		child.queue_free()

	var label = Label.new()
	label.text = "No data available.\nLoad solo games from the Games tab."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	top_maps_container.add_child(label)

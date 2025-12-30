extends GridContainer

func _ready():
	columns = 5

func set_data(title: String, difficulty: int, usefulness: int, url: String, map_url: String = ""):
	$Title.text = title
	$Title.pressed.connect(func(): OS.shell_open(url))

	_set_stars($DifficultyStars, difficulty)
	_set_stars($UsefulnessStars, usefulness)

	if map_url != "":
		$MapButton.text = "📍 Map"
		$MapButton.visible = true
		$MapButton.pressed.connect(func(): OS.shell_open(map_url))
	else:
		$MapButton.visible = false

func _on_link_pressed(url: String):
	OS.shell_open(url)

func _set_stars(container: HBoxContainer, value: int):
	for child in container.get_children():
		child.queue_free()
	
	for i in range(5):
		var star = Label.new()
		star.text = "★" if i < value else "☆"
		star.add_theme_font_size_override("font_size", 18)
		if i < value:
			star.add_theme_color_override("font_color", Color.GOLD)
		else:
			star.add_theme_color_override("font_color", Color.GRAY)
		container.add_child(star)

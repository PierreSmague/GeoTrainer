extends Control

func _ready():
	# Apply global theme
	theme = ThemeManager.create_theme()

	# Background color
	var bg = ColorRect.new()
	bg.color = ThemeManager.BG_MAIN
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# Build header bar
	_build_header()

	# Add IA Analyze tab
	var ia_tab = Control.new()
	ia_tab.name = "IA Analyze"
	ia_tab.set_script(load("res://scripts/ia_analyze.gd"))
	$Tabs.add_child(ia_tab)

	# Tab initialisation
	$Tabs.tab_changed.connect(_on_tab_changed)

func _build_header():
	# Header background panel (behind existing Connection API nodes)
	var header_bg = ColorRect.new()
	header_bg.name = "HeaderBG"
	header_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bg.offset_bottom = 85
	header_bg.color = ThemeManager.BG_SURFACE
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_bg)
	# Place behind Connection API (index 1 = right after the main bg at 0)
	move_child(header_bg, 1)

	# Accent line under header
	var accent_line = ColorRect.new()
	accent_line.name = "HeaderAccent"
	accent_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent_line.offset_top = 85
	accent_line.offset_bottom = 87
	accent_line.color = ThemeManager.ACCENT
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent_line)
	move_child(accent_line, 2)

	# Logo + Title (top-left, next to Connection API buttons)
	var logo_tex = load("res://misc/images/logo_gg.png")
	if logo_tex:
		var logo = TextureRect.new()
		logo.name = "HeaderLogo"
		logo.texture = logo_tex
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(40, 40)
		logo.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		logo.position = Vector2(20, 22)
		add_child(logo)

	var title = Label.new()
	title.name = "HeaderTitle"
	title.text = "GeoTrainer"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(70, 28)
	add_child(title)

	# Adjust Tabs to sit below header
	var tabs = get_node_or_null("Tabs")
	if tabs:
		tabs.offset_top = 90

func _on_tab_changed(tab_index):
	match tab_index:
		0:
			print("Dahsboard selected")
		1:
			print("Training selected")
		2:
			print("Resources selected")
		3:
			print("Stats selected")
		4:
			print("IA Analyze selected")

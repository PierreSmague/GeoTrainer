extends Control

enum State { IDLE, LOADING_GAME, SELECTING_ROUND, LOADING_IMAGES, IMAGES_READY, ANALYZING, ANALYSIS_DONE }

var state: int = State.IDLE
var rounds_data: Array = []
var current_round: int = -1
var current_pano_id: String = ""
var thumbnail_images: Array = []  # Array of Image
var thumbnail_index: int = 0
var headings: Array = [0, 90, 180, 270]
var direction_labels: Array = ["North (0°)", "East (90°)", "South (180°)", "West (270°)"]

# UI references
var url_input: LineEdit
var load_btn: Button
var status_label: Label
var rounds_bar: HFlowContainer
var images_grid: GridContainer
var analyze_btn: Button
var analysis_text: RichTextLabel
var scroll_container: ScrollContainer
var content_vbox: VBoxContainer

# HTTP nodes
var http_game: HTTPRequest
var http_thumb: HTTPRequest
var http_claude: HTTPRequest

# API key popup
var api_key_popup: AcceptDialog
var api_key_input: LineEdit

const CLAUDE_PROMPT = """You are an expert GeoGuessr analyst. You are shown 4 Street View images taken at the same location, facing North (0°), East (90°), South (180°), and West (270°).

Your task is to analyze these images like a professional GeoGuessr player and provide an educational breakdown. Structure your analysis as follows:

1. **Immediate Clues**: What stands out at first glance? (driving side, road markings, vegetation, sun position, landscape type)
2. **Language & Signs**: Any text visible? What language/script? Road signs, shop signs, license plates?
3. **Infrastructure**: Road quality, line markings, bollards, poles, fencing style, building architecture
4. **Vegetation & Climate**: Type of trees, soil color, overall climate zone
5. **Country Guess**: Based on all clues, what country is this most likely in? Explain your reasoning step by step.
6. **Region Narrowing**: Can you narrow it down to a specific region or area within the country?

Be pedagogical — explain WHY each clue points where it does, so the player can learn to spot these patterns themselves. Use bullet points and bold key identifiers."""

func _ready():
	_setup_ui()
	_setup_http_nodes()
	_setup_api_key_popup()

func _setup_ui():
	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 10)
	var margin_left = 20
	var margin_right = 20
	var margin_top = 10
	root_vbox.offset_left = margin_left
	root_vbox.offset_right = -margin_right
	root_vbox.offset_top = margin_top
	add_child(root_vbox)

	# URL bar
	var url_bar = HBoxContainer.new()
	url_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(url_bar)

	url_input = LineEdit.new()
	url_input.placeholder_text = "Paste duel URL..."
	url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_input.custom_minimum_size.y = 36
	url_bar.add_child(url_input)

	load_btn = Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(120, 36)
	load_btn.pressed.connect(_on_load_game)
	url_bar.add_child(load_btn)

	# Status label
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
	root_vbox.add_child(status_label)

	# Rounds bar (wraps to multiple lines)
	rounds_bar = HFlowContainer.new()
	rounds_bar.add_theme_constant_override("h_separation", 6)
	rounds_bar.add_theme_constant_override("v_separation", 6)
	rounds_bar.visible = false
	root_vbox.add_child(rounds_bar)

	# Scroll container for images + analysis
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll_container)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll_container.add_child(content_vbox)

	# Images grid (2 columns)
	images_grid = GridContainer.new()
	images_grid.columns = 2
	images_grid.add_theme_constant_override("h_separation", 8)
	images_grid.add_theme_constant_override("v_separation", 8)
	images_grid.visible = false
	content_vbox.add_child(images_grid)

	# Analyze button
	analyze_btn = Button.new()
	analyze_btn.text = "Analyze Round"
	analyze_btn.custom_minimum_size = Vector2(200, 40)
	analyze_btn.visible = false
	analyze_btn.pressed.connect(_on_analyze_pressed)
	content_vbox.add_child(analyze_btn)

	# Analysis text
	analysis_text = RichTextLabel.new()
	analysis_text.bbcode_enabled = true
	analysis_text.fit_content = true
	analysis_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analysis_text.selection_enabled = true
	analysis_text.visible = false
	analysis_text.add_theme_color_override("default_color", ThemeManager.TEXT_PRIMARY)
	content_vbox.add_child(analysis_text)

func _setup_http_nodes():
	http_game = HTTPRequest.new()
	http_game.name = "HTTPGame"
	http_game.request_completed.connect(_on_game_loaded)
	add_child(http_game)

	http_thumb = HTTPRequest.new()
	http_thumb.name = "HTTPThumb"
	http_thumb.request_completed.connect(_on_thumbnail_received)
	add_child(http_thumb)

	http_claude = HTTPRequest.new()
	http_claude.name = "HTTPClaude"
	http_claude.timeout = 120.0
	http_claude.request_completed.connect(_on_analysis_received)
	add_child(http_claude)

func _setup_api_key_popup():
	api_key_popup = AcceptDialog.new()
	api_key_popup.title = "Claude API Key"
	api_key_popup.dialog_text = "Enter your Anthropic API key to enable AI analysis:"
	api_key_popup.min_size = Vector2(450, 150)

	api_key_input = LineEdit.new()
	api_key_input.placeholder_text = "sk-ant-..."
	api_key_input.secret = true
	api_key_input.custom_minimum_size.y = 32
	api_key_popup.add_child(api_key_input)

	api_key_popup.confirmed.connect(_on_api_key_confirmed)
	add_child(api_key_popup)

# --- URL Parsing & Game Loading ---

func _extract_game_id(url: String) -> String:
	var parts = url.strip_edges().split("/")
	for i in range(parts.size()):
		if parts[i] == "duels" and i + 1 < parts.size():
			var candidate = parts[i + 1]
			if candidate.length() >= 20:
				return candidate
	return ""

func _on_load_game():
	var url = url_input.text.strip_edges()
	var game_id = _extract_game_id(url)
	if game_id == "":
		_set_status("Invalid duel URL. Expected format: geoguessr.com/duels/<id>", ThemeManager.ERROR)
		return

	state = State.LOADING_GAME
	_set_status("Loading game...", ThemeManager.TEXT_SECONDARY)
	_clear_round_ui()
	load_btn.disabled = true

	var ncfa_token = FileManager.load_text(FilePaths.NCFA).strip_edges()
	if ncfa_token == "":
		_set_status("NCFA token not found. Connect first.", ThemeManager.ERROR)
		load_btn.disabled = false
		return

	var headers = [
		"Cookie: _ncfa=" + ncfa_token,
		"Content-Type: application/json"
	]
	var api_url = "https://game-server.geoguessr.com/api/duels/" + game_id
	var err = http_game.request(api_url, headers)
	if err != OK:
		_set_status("HTTP request failed: " + str(err), ThemeManager.ERROR)
		load_btn.disabled = false

func _on_game_loaded(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
	load_btn.disabled = false

	if code != 200:
		_set_status("API error (HTTP " + str(code) + ")", ThemeManager.ERROR)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		_set_status("Failed to parse game data", ThemeManager.ERROR)
		return

	# Extract rounds
	rounds_data.clear()
	var rounds = data.get("rounds", [])
	if rounds.is_empty():
		_set_status("No rounds found in this game", ThemeManager.WARNING)
		return

	for r in rounds:
		var panorama = r.get("panorama", {})
		rounds_data.append({
			"roundNumber": r.get("roundNumber", 0),
			"lat": panorama.get("lat", 0.0),
			"lng": panorama.get("lng", 0.0),
			"panoId": panorama.get("panoId", ""),
			"countryCode": panorama.get("countryCode", ""),
			"heading": panorama.get("heading", 0.0),
		})

	_build_round_buttons()
	state = State.SELECTING_ROUND
	_set_status("Select a round to analyze", ThemeManager.ACCENT_SEC)

func _build_round_buttons():
	# Clear existing buttons
	for child in rounds_bar.get_children():
		child.queue_free()

	for i in range(rounds_data.size()):
		var rd = rounds_data[i]
		var btn = Button.new()

		var label_text = "R" + str(int(rd["roundNumber"]))
		var cc = rd.get("countryCode", "")
		if cc != "":
			var countries_data = FileManager.load_json(FilePaths.COUNTRIES, {})
			var country_name = countries_data.get(cc.to_lower(), cc.to_upper())
			label_text += " - " + country_name
		btn.text = label_text

		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_round_selected.bind(i))
		rounds_bar.add_child(btn)

		# Add flag icon
		var flag = GeoUtils.create_flag_icon(cc, 16.0)
		if flag:
			rounds_bar.add_child(flag)
			rounds_bar.move_child(flag, rounds_bar.get_child_count() - 2)

	rounds_bar.visible = true

func _on_round_selected(round_index: int):
	current_round = round_index
	var rd = rounds_data[round_index]

	state = State.LOADING_IMAGES
	_set_status("Gathering round images...", ThemeManager.TEXT_SECONDARY)
	_clear_images()
	analyze_btn.visible = false
	analysis_text.visible = false

	thumbnail_images.clear()
	thumbnail_index = 0

	# Decode hex-encoded panoId from GeoGuessr API
	var raw_pano = rd.get("panoId", "")
	if raw_pano != "" and raw_pano != null:
		current_pano_id = _hex_decode(raw_pano)
	else:
		current_pano_id = ""
	_download_next_thumbnail()

# --- Panorama ID & Thumbnails ---

func _hex_decode(hex_string: String) -> String:
	var result = PackedByteArray()
	for i in range(0, hex_string.length(), 2):
		if i + 1 >= hex_string.length():
			break
		var byte_str = hex_string.substr(i, 2)
		result.append(("0x" + byte_str).hex_to_int())
	return result.get_string_from_ascii()

func _download_next_thumbnail():
	if thumbnail_index >= 4:
		_on_all_thumbnails_loaded()
		return

	var heading = headings[thumbnail_index]
	_set_status("Downloading image %d/4 (%s)..." % [thumbnail_index + 1, direction_labels[thumbnail_index]], ThemeManager.TEXT_SECONDARY)

	var url: String
	if current_pano_id != "":
		url = "https://streetviewpixels-pa.googleapis.com/v1/thumbnail?panoid=%s&cb_client=maps_sv.tactile.gps&w=640&h=360&yaw=%d&pitch=0&thumbfov=100" % [current_pano_id.uri_encode(), heading]
	else:
		var rd = rounds_data[current_round]
		url = "https://streetviewpixels-pa.googleapis.com/v1/thumbnail?center=%.6f,%.6f&cb_client=maps_sv.tactile.gps&w=640&h=360&yaw=%d&pitch=0&thumbfov=100&radius=50" % [rd["lat"], rd["lng"], heading]
	var err = http_thumb.request(url)
	if err != OK:
		_set_status("Failed to download thumbnail " + str(thumbnail_index + 1), ThemeManager.ERROR)
		state = State.SELECTING_ROUND

func _on_thumbnail_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
	if code != 200:
		_set_status("Failed to download image (HTTP " + str(code) + ")", ThemeManager.WARNING)
		state = State.SELECTING_ROUND
		return

	var img = Image.new()
	var err = img.load_jpg_from_buffer(body)
	if err != OK:
		# Try PNG
		err = img.load_png_from_buffer(body)
	if err != OK:
		_set_status("Failed to decode image " + str(thumbnail_index + 1), ThemeManager.WARNING)
		state = State.SELECTING_ROUND
		return

	thumbnail_images.append(img)
	thumbnail_index += 1
	_download_next_thumbnail()

func _on_all_thumbnails_loaded():
	_clear_images()
	images_grid.visible = true

	for i in range(thumbnail_images.size()):
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 4)

		var dir_label = Label.new()
		dir_label.text = direction_labels[i]
		dir_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dir_label.add_theme_font_size_override("font_size", 13)
		dir_label.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
		container.add_child(dir_label)

		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(480, 270)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		var tex = ImageTexture.create_from_image(thumbnail_images[i])
		tex_rect.texture = tex
		container.add_child(tex_rect)

		images_grid.add_child(container)

	analyze_btn.visible = true
	state = State.IMAGES_READY
	_set_status("Images loaded. Click Analyze Round to get AI analysis.", ThemeManager.SUCCESS)

# --- Claude Analysis ---

func _on_analyze_pressed():
	if thumbnail_images.size() < 4:
		_set_status("Not enough images to analyze", ThemeManager.ERROR)
		return

	var api_key = FileManager.load_text(FilePaths.CLAUDE_API_KEY).strip_edges()
	if api_key == "":
		api_key_popup.popup_centered()
		return

	_send_analysis(api_key)

func _on_api_key_confirmed():
	var key = api_key_input.text.strip_edges()
	if key == "":
		return

	var file = FileAccess.open(FilePaths.CLAUDE_API_KEY, FileAccess.WRITE)
	if file:
		file.store_string(key)
		file.close()

	_send_analysis(key)

func _send_analysis(api_key: String):
	state = State.ANALYZING
	analyze_btn.disabled = true
	_set_status("Analyzing round with Claude...", ThemeManager.ACCENT)
	analysis_text.text = ""
	analysis_text.visible = false

	# Build content blocks: 4 images + text prompt
	var content = []
	for i in range(thumbnail_images.size()):
		var png_buffer = thumbnail_images[i].save_png_to_buffer()
		var b64 = Marshalls.raw_to_base64(png_buffer)
		content.append({
			"type": "text",
			"text": direction_labels[i] + ":"
		})
		content.append({
			"type": "image",
			"source": {
				"type": "base64",
				"media_type": "image/png",
				"data": b64
			}
		})

	content.append({
		"type": "text",
		"text": CLAUDE_PROMPT
	})

	var request_body = {
		"model": "claude-sonnet-4-5-20250929",
		"max_tokens": 2048,
		"messages": [
			{
				"role": "user",
				"content": content
			}
		]
	}

	var json_body = JSON.stringify(request_body)
	var request_headers = [
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01",
		"content-type: application/json"
	]

	var err = http_claude.request(
		"https://api.anthropic.com/v1/messages",
		request_headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if err != OK:
		_set_status("Failed to send analysis request: " + str(err), ThemeManager.ERROR)
		analyze_btn.disabled = false
		state = State.IMAGES_READY

func _on_analysis_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
	analyze_btn.disabled = false

	var body_str = body.get_string_from_utf8()
	var data = JSON.parse_string(body_str)

	if code != 200 or data == null:
		var error_msg = "Analysis failed (HTTP " + str(code) + ")"
		if data != null and data.has("error"):
			error_msg += ": " + str(data["error"].get("message", ""))
		_set_status(error_msg, ThemeManager.ERROR)
		state = State.IMAGES_READY
		return

	# Extract text from response
	var response_text = ""
	var content_blocks = data.get("content", [])
	for block in content_blocks:
		if block.get("type", "") == "text":
			response_text += block.get("text", "")

	if response_text == "":
		_set_status("Empty response from Claude", ThemeManager.WARNING)
		state = State.IMAGES_READY
		return

	# Convert markdown bold to BBCode
	var bbcode = _markdown_to_bbcode(response_text)
	analysis_text.text = bbcode
	analysis_text.visible = true
	state = State.ANALYSIS_DONE
	_set_status("Analysis complete", ThemeManager.SUCCESS)

# --- Helpers ---

func _set_status(text: String, color: Color):
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)

func _clear_round_ui():
	rounds_bar.visible = false
	for child in rounds_bar.get_children():
		child.queue_free()
	_clear_images()
	analyze_btn.visible = false
	analysis_text.visible = false

func _clear_images():
	images_grid.visible = false
	for child in images_grid.get_children():
		child.queue_free()

func _markdown_to_bbcode(md: String) -> String:
	var text = md
	# Convert **bold** to [b]bold[/b]
	var regex = RegEx.new()
	regex.compile("\\*\\*(.+?)\\*\\*")
	text = regex.sub(text, "[b]$1[/b]", true)
	# Convert headers ## to bold
	var header_regex = RegEx.new()
	header_regex.compile("(?m)^#{1,3}\\s+(.+)$")
	text = header_regex.sub(text, "\n[b][color=#%s]$1[/color][/b]" % ThemeManager.ACCENT_SEC.to_html(false), true)
	return text

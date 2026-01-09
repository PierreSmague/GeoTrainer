extends Control

const duels_detailed := "user://duels_filtered.json"
const profile := "user://profile.json"

var data: Array = []
var dates: Array = []  # Store dates for each point
var chart_title: String = "Duels - ELO Evolution"
var line_color: Color = Color.CYAN
var moving_avg_color: Color = Color(1.0, 0.5, 0.0)  # Orange
var padding: int = 60
var player_id: String = ""
var moving_avg_period: int = 10
var hovered_point_index: int = -1
var points: PackedVector2Array = []

# UI elements
var period_slider: HSlider
var period_label: Label

func _ready():
	_setup_ui()
	_load_player_id()
	_load_elo_data()

func _refresh():
	_load_player_id()
	_load_elo_data()

func _setup_ui():
	# Create slider container
	var slider_container = HBoxContainer.new()
	slider_container.position = Vector2(10, 50)
	slider_container.custom_minimum_size = Vector2(250, 30)
	add_child(slider_container)
	
	# Create label
	var label_text = Label.new()
	label_text.text = "Moving Average Period:"
	label_text.custom_minimum_size = Vector2(180, 0)
	slider_container.add_child(label_text)
	
	# Create period label
	period_label = Label.new()
	period_label.text = str(moving_avg_period)
	period_label.custom_minimum_size = Vector2(30, 0)
	slider_container.add_child(period_label)
	
	# Create slider
	period_slider = HSlider.new()
	period_slider.min_value = 2
	period_slider.max_value = 50
	period_slider.step = 1
	period_slider.value = moving_avg_period
	period_slider.custom_minimum_size = Vector2(150, 0)
	period_slider.value_changed.connect(_on_period_changed)
	slider_container.add_child(period_slider)

func _on_period_changed(value: float):
	moving_avg_period = int(value)
	period_label.text = str(moving_avg_period)
	queue_redraw()

func _load_player_id():
	var file = FileAccess.open(profile, FileAccess.READ)
	if file:
		var profile_data = JSON.parse_string(file.get_as_text())
		file.close()
		if profile_data and profile_data["user"].has("id"):
			player_id = profile_data["user"]["id"]
			print("Player ID loaded: ", player_id)

func _load_elo_data():
	# Check if file exists
	if not FileAccess.file_exists(duels_detailed):
		print("duels_detailed.json file not found")
		visible = false
		return
	
	# Load data
	var file = FileAccess.open(duels_detailed, FileAccess.READ)
	if not file:
		push_error("Cannot open duels_detailed.json")
		visible = false
		return
	
	var duels_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not duels_data or duels_data.size() == 0:
		print("No duels found in duels_detailed.json")
		visible = false
		return
	
	# Extract ELO ratings and dates from duels (already in chronological order)
	var elo_data = []
	var date_data = []
	for duel in duels_data:
		if duel.has("playerRatingAfter") and duel.has("date"):
			elo_data.append(duel["playerRatingAfter"])
			date_data.append(duel["date"])
	
	elo_data.reverse()
	date_data.reverse()
	
	if elo_data.size() == 0:
		print("No ELO found in duels")
		visible = false
		return
	
	# Set data and trigger redraw
	data = elo_data
	dates = date_data
	visible = true
	queue_redraw()
	
	print("ELO data loaded: %d points" % elo_data.size())

func _input(event):
	if event is InputEventMouseMotion:
		# Convert global mouse position to local control coordinates
		var local_pos = get_global_mouse_position() - global_position
		_check_hover(local_pos)

func _check_hover(mouse_pos: Vector2):
	var old_hovered = hovered_point_index
	hovered_point_index = -1
	
	# Check if mouse is within the control bounds
	if not Rect2(Vector2.ZERO, size).has_point(mouse_pos):
		if old_hovered != hovered_point_index:
			queue_redraw()
		return
	
	# Check if mouse is near any point
	for i in range(points.size()):
		var distance = mouse_pos.distance_to(points[i])
		if distance < 10:  # 10 pixel radius for hover detection
			hovered_point_index = i
			break
	
	# Redraw if hover state changed
	if old_hovered != hovered_point_index:
		queue_redraw()

func _calculate_moving_average() -> Array:
	if data.size() < moving_avg_period:
		return []
	
	var moving_avg = []
	for i in range(data.size()):
		if i < moving_avg_period - 1:
			moving_avg.append(null)  # Not enough data yet
		else:
			var sum = 0.0
			for j in range(moving_avg_period):
				sum += data[i - j]
			moving_avg.append(sum / moving_avg_period)
	
	return moving_avg

func format_unix_to_date(timestamp: int) -> String:
	var dt = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]

func _draw():
	if data.size() == 0:
		return
	
	var chart_size = size
	var drawable_width = chart_size.x - 2 * padding
	var drawable_height = chart_size.y - 2 * padding - 40  # Space for title
	
	# Find min and max for normalization
	var data_min = data[0]
	var data_max = data[0]
	for val in data:
		data_min = min(data_min, val)
		data_max = max(data_max, val)
	
	# Round to nearest hundred (floor for min, ceil for max)
	var min_val = floor(data_min / 100.0) * 100
	var max_val = ceil(data_max / 100.0) * 100
	
	# Ensure we have at least some range
	if max_val == min_val:
		min_val -= 100
		max_val += 100
	
	var range_val = max_val - min_val
	
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, chart_size), Color(0.1, 0.1, 0.1, 0.5))
	
	# Draw title
	var title_pos = Vector2(chart_size.x / 2, 25)
	draw_string(ThemeDB.fallback_font, title_pos, chart_title, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)
	
	# Draw axes
	var origin = Vector2(padding, chart_size.y - padding)
	var x_axis_end = Vector2(chart_size.x - padding, chart_size.y - padding)
	var y_axis_end = Vector2(padding, padding + 40)
	
	draw_line(y_axis_end, origin, Color.WHITE, 2)  # Y axis
	draw_line(origin, x_axis_end, Color.WHITE, 2)  # X axis
	
	# Calculate number of grid lines (every 100 units)
	var num_hundreds = int(range_val / 100)
	
	# Draw horizontal grid lines at every hundred
	for i in range(num_hundreds + 1):
		var value = min_val + (i * 100)
		var normalized = float(i) / num_hundreds
		var y = origin.y - normalized * drawable_height
		
		var grid_start = Vector2(padding, y)
		var grid_end = Vector2(chart_size.x - padding, y)
		draw_line(grid_start, grid_end, Color(0.3, 0.3, 0.3, 0.5), 1)
		
		# Draw Y axis labels
		var label_pos = Vector2(10, y + 5)
		draw_string(ThemeDB.fallback_font, label_pos, str(int(value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	
	# Calculate points positions
	points.clear()
	for i in range(data.size()):
		var x = padding + (float(i) / (data.size() - 1 if data.size() > 1 else 1)) * drawable_width
		var normalized = (data[i] - min_val) / range_val
		var y = origin.y - normalized * drawable_height
		points.append(Vector2(x, y))
		
		# Draw X axis labels (game numbers)
		if data.size() <= 20 or i % max(1, int(data.size() / 10)) == 0 or i == data.size() - 1:
			var label = "G" + str(i + 1)  # G for Game
			var label_pos = Vector2(x, origin.y + 20)
			draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.LIGHT_GRAY)
	
	# Draw main ELO line (no points)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], line_color, 3)
	
	# Draw moving average line
	var moving_avg = _calculate_moving_average()
	if moving_avg.size() > 0:
		var ma_points = PackedVector2Array()
		for i in range(moving_avg.size()):
			if moving_avg[i] != null:
				var x = padding + (float(i) / (data.size() - 1 if data.size() > 1 else 1)) * drawable_width
				var normalized = (moving_avg[i] - min_val) / range_val
				var y = origin.y - normalized * drawable_height
				ma_points.append(Vector2(x, y))
		
		# Draw moving average line
		for i in range(ma_points.size() - 1):
			draw_line(ma_points[i], ma_points[i + 1], moving_avg_color, 2)
	
	# Draw hover tooltip
	if hovered_point_index >= 0 and hovered_point_index < points.size():
		var point = points[hovered_point_index]
		var elo_value = int(data[hovered_point_index])
		var date_str = format_unix_to_date(dates[hovered_point_index])
		
		# Tooltip text
		var tooltip_text = date_str + "\nELO: " + str(elo_value)
		
		# Calculate tooltip size
		var font = ThemeDB.fallback_font
		var font_size = 14
		var line_height = 20
		var tooltip_width = 120
		var tooltip_height = 50
		
		# Position tooltip (offset from point)
		var tooltip_pos = point + Vector2(15, -25)
		
		# Keep tooltip within bounds
		if tooltip_pos.x + tooltip_width > chart_size.x:
			tooltip_pos.x = point.x - tooltip_width - 15
		if tooltip_pos.y < 0:
			tooltip_pos.y = point.y + 25
		
		# Draw tooltip background
		var tooltip_rect = Rect2(tooltip_pos, Vector2(tooltip_width, tooltip_height))
		draw_rect(tooltip_rect, Color(0.2, 0.2, 0.2, 0.95))
		draw_rect(tooltip_rect, Color.WHITE, false, 2)  # Border
		
		# Draw tooltip text
		var text_pos = tooltip_pos + Vector2(10, 18)
		draw_string(font, text_pos, date_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		text_pos.y += line_height
		draw_string(font, text_pos, "ELO: " + str(elo_value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)
		
		# Highlight hovered point
		draw_circle(point, 6, Color.WHITE)
		draw_circle(point, 4, line_color)
	
	# Display statistics
	if data.size() > 1:
		var evolution = data[-1] - data[0]
		var avg = 0.0
		for val in data:
			avg += val
		avg /= data.size()
		
		var stats_y = chart_size.y - 15
		var stats_text = "Current ELO: %d | Evolution: %+d | Average: %d | Nb of ranked games: %d" % [
			int(data[-1]),
			int(evolution),
			int(avg),
			data.size()
		]
		
		var evolution_color = Color.GREEN if evolution >= 0 else Color.RED
		draw_string(ThemeDB.fallback_font, Vector2(padding, stats_y), stats_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, evolution_color)

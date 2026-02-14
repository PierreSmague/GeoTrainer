extends Control

var data: Array = []
var chart_title: String = ""
var line_color: Color = ThemeManager.ACCENT_SEC
var trend_color: Color = ThemeManager.WARNING
var padding: int = 60
var player_id: String = ""

var regression_slope: float = 0.0
var regression_intercept: float = 0.0

func _ready():
	player_id = FileManager.load_player_id()
	_load_points_data()

func _refresh():
	player_id = FileManager.load_player_id()
	_load_points_data()

func _load_points_data():
	var duels_data = FileManager.load_json(FilePaths.DUELS_FILTERED)
	if duels_data == null or not duels_data is Array or duels_data.size() == 0:
		print("No duels found")
		visible = false
		return

	var points_data = []
	for i in range(duels_data.size() - 1, -1, -1):
		var duel = duels_data[i]
		var avg_points = _extract_avg_points_from_duel(duel)
		if avg_points != -1:
			points_data.append(avg_points)

	if points_data.size() == 0:
		print("No points found in duels")
		visible = false
		return

	_calculate_linear_regression(points_data)

	visible = true
	data = points_data
	chart_title = "Duels - Average points per round"
	queue_redraw()
	print("Points stats loaded: %d duels" % points_data.size())

func _extract_avg_points_from_duel(duel):
	var total_score = 0
	var guess_count = 0

	for round in duel["rounds"]:
		if round["player"].has("score"):
			total_score += round["player"]["score"]
			guess_count += 1

	if guess_count > 0:
		return float(total_score) / float(guess_count)
	return -1

func _calculate_linear_regression(points_data: Array):
	var n = points_data.size()
	if n < 2:
		regression_slope = 0.0
		regression_intercept = 0.0
		return

	var sum_x = 0.0
	var sum_y = 0.0
	for i in range(n):
		sum_x += i
		sum_y += points_data[i]

	var mean_x = sum_x / n
	var mean_y = sum_y / n

	var numerator = 0.0
	var denominator = 0.0

	for i in range(n):
		numerator += (i - mean_x) * (points_data[i] - mean_y)
		denominator += (i - mean_x) * (i - mean_x)

	if denominator != 0:
		regression_slope = numerator / denominator
		regression_intercept = mean_y - regression_slope * mean_x
	else:
		regression_slope = 0.0
		regression_intercept = mean_y

func _draw():
	if data.size() == 0:
		return

	var chart_size = size
	var drawable_width = chart_size.x - 2 * padding
	var drawable_height = chart_size.y - 2 * padding - 40

	var min_val = 2500.0
	var max_val = 5000.0
	var range_val = max_val - min_val

	draw_rect(Rect2(Vector2.ZERO, chart_size), Color(ThemeManager.BG_SURFACE.r, ThemeManager.BG_SURFACE.g, ThemeManager.BG_SURFACE.b, 0.5))

	var title_pos = Vector2(chart_size.x / 2, 25)
	draw_string(ThemeDB.fallback_font, title_pos, chart_title, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)

	var origin = Vector2(padding, chart_size.y - padding)
	var x_axis_end = Vector2(chart_size.x - padding, chart_size.y - padding)
	var y_axis_end = Vector2(padding, padding + 40)

	draw_line(y_axis_end, origin, Color.WHITE, 2)
	draw_line(origin, x_axis_end, Color.WHITE, 2)

	for value in range(min_val, max_val + 1, 100):
		var normalized = (value - min_val) / range_val
		var y = origin.y - normalized * drawable_height

		var grid_start = Vector2(padding, y)
		var grid_end = Vector2(chart_size.x - padding, y)
		draw_line(grid_start, grid_end, Color(ThemeManager.BORDER.r, ThemeManager.BORDER.g, ThemeManager.BORDER.b, 0.5), 1)

		var label_pos = Vector2(10, y + 5)
		draw_string(ThemeDB.fallback_font, label_pos, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	var points = PackedVector2Array()
	var valid_indices = []

	for i in range(data.size()):
		var x = padding + (float(i) / (data.size() - 1 if data.size() > 1 else 1)) * drawable_width

		if data[i] >= min_val:
			var normalized = (data[i] - min_val) / range_val
			var y = origin.y - normalized * drawable_height
			points.append(Vector2(x, y))
			valid_indices.append(i)

			draw_circle(Vector2(x, y), 2.5, line_color)

			if data.size() <= 20 or i % max(1, int(data.size() / 10)) == 0 or i == data.size() - 1:
				var label = "G" + str(i + 1)
				var label_pos = Vector2(x, origin.y + 20)
				draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.LIGHT_GRAY)

	for i in range(valid_indices.size() - 1):
		if valid_indices[i + 1] == valid_indices[i] + 1:
			draw_line(points[i], points[i + 1], line_color, 1.5)

	if data.size() >= 2:
		var trend_points = PackedVector2Array()
		for i in range(data.size()):
			var x = padding + (float(i) / (data.size() - 1 if data.size() > 1 else 1)) * drawable_width
			var trend_value = regression_intercept + regression_slope * i
			var normalized = (trend_value - min_val) / range_val
			var y = origin.y - normalized * drawable_height
			trend_points.append(Vector2(x, y))

		for i in range(trend_points.size() - 1):
			draw_line(trend_points[i], trend_points[i + 1], trend_color, 4)

	if data.size() > 0:
		var avg = 0.0
		for val in data:
			avg += val
		avg /= data.size()

		var stats_y = chart_size.y - 15
		var stats_text = "Overall avg: %d pts | Games: %d | Trend: %+.2f pts/game" % [
			int(avg),
			data.size(),
			regression_slope
		]

		var trend_color_display = Color.GREEN if regression_slope >= 0 else Color.RED
		draw_string(ThemeDB.fallback_font, Vector2(padding, stats_y), stats_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, trend_color_display)

extends Control

const duels_detailed := "user://duels_detailed.json"
const profile := "user://profile.json"

var data: Array = []
var chart_title: String = ""
var line_color: Color = Color.GREEN
var trend_color: Color = Color.ORANGE
var padding: int = 60
var player_id: String = ""

# Regression line parameters
var regression_slope: float = 0.0
var regression_intercept: float = 0.0

func _ready():
	_load_player_id()
	_load_points_data()
	
func _refresh():
	_load_player_id()
	_load_points_data()

func _load_player_id():
	var file = FileAccess.open(profile, FileAccess.READ)
	if file:
		var profile_data = JSON.parse_string(file.get_as_text())
		file.close()
		if profile_data and profile_data["user"].has("id"):
			player_id = profile_data["user"]["id"]

func _load_points_data():
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
	
	# Extract average points per duel (reverse order since duels are from newest to oldest)
	var points_data = []
	for i in range(duels_data.size() - 1, -1, -1):  # Iterate backwards
		var duel = duels_data[i]
		var avg_points = _extract_avg_points_from_duel(duel)
		if avg_points != -1:
			points_data.append(avg_points)
	
	if points_data.size() == 0:
		print("No points found in duels")
		visible = false
		return
	
	# Calculate linear regression
	_calculate_linear_regression(points_data)
	
	# Display chart
	visible = true
	data = points_data
	chart_title = "Duels - Average points per round"
	queue_redraw()
	
	print("Points stats loaded: %d duels" % points_data.size())

func _extract_avg_points_from_duel(duel):
	# Search for player in teams
	if not duel.has("teams"):
		return -1
	
	for team in duel["teams"]:
		if not team.has("players"):
			continue
		
		for player in team["players"]:
			if player["playerId"] == player_id:
				# Get all guesses and calculate average score
				if player.has("guesses") and player["guesses"].size() > 0:
					var total_score = 0
					var guess_count = 0
					
					for guess in player["guesses"]:
						if guess.has("score"):
							total_score += guess["score"]
							guess_count += 1
					
					if guess_count > 0:
						return float(total_score) / float(guess_count)
	
	return -1  # Player or scores not found

func _calculate_linear_regression(points_data: Array):
	var n = points_data.size()
	if n < 2:
		regression_slope = 0.0
		regression_intercept = 0.0
		return
	
	# Calculate means
	var sum_x = 0.0
	var sum_y = 0.0
	for i in range(n):
		sum_x += i
		sum_y += points_data[i]
	
	var mean_x = sum_x / n
	var mean_y = sum_y / n
	
	# Calculate slope and intercept
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
	var drawable_height = chart_size.y - 2 * padding - 40  # Space for title
	
	# Fixed scale: 3500 to 5000
	var min_val = 3500.0
	var max_val = 5000.0
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
	
	# Draw horizontal grid lines every 100 units from 3500 to 5000
	for value in range(3500, 5001, 100):
		var normalized = (value - min_val) / range_val
		var y = origin.y - normalized * drawable_height
		
		var grid_start = Vector2(padding, y)
		var grid_end = Vector2(chart_size.x - padding, y)
		draw_line(grid_start, grid_end, Color(0.3, 0.3, 0.3, 0.5), 1)
		
		# Draw Y axis labels
		var label_pos = Vector2(10, y + 5)
		draw_string(ThemeDB.fallback_font, label_pos, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	
	# Draw data points and lines (filter points < 3500 for display only)
	var points = PackedVector2Array()
	var valid_indices = []  # Track which points are displayed
	
	for i in range(data.size()):
		var x = padding + (float(i) / (data.size() - 1 if data.size() > 1 else 1)) * drawable_width
		
		# Only display points >= 3500
		if data[i] >= min_val:
			var normalized = (data[i] - min_val) / range_val
			var y = origin.y - normalized * drawable_height
			points.append(Vector2(x, y))
			valid_indices.append(i)
			
			# Draw point (thinner - radius 2.5 instead of 5)
			draw_circle(Vector2(x, y), 2.5, line_color)
			
			# Draw label every N points to avoid overlap
			if data.size() <= 20 or i % max(1, int(data.size() / 10)) == 0 or i == data.size() - 1:
				var label = "G" + str(i + 1)  # G for Game
				var label_pos = Vector2(x, origin.y + 20)
				draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.LIGHT_GRAY)
	
	# Draw lines between consecutive valid points (thinner - width 1.5 instead of 3)
	for i in range(valid_indices.size() - 1):
		# Only connect if indices are consecutive in original data
		if valid_indices[i + 1] == valid_indices[i] + 1:
			draw_line(points[i], points[i + 1], line_color, 1.5)
	
	# Draw regression line (AFTER data, so it's on top - thicker at width 4)
	if data.size() >= 2:
		var trend_points = PackedVector2Array()
		for i in range(data.size()):
			var x = padding + (float(i) / (data.size() - 1 if data.size() > 1 else 1)) * drawable_width
			var trend_value = regression_intercept + regression_slope * i
			var normalized = (trend_value - min_val) / range_val
			var y = origin.y - normalized * drawable_height
			trend_points.append(Vector2(x, y))
		
		# Draw trend line (thicker and on top)
		for i in range(trend_points.size() - 1):
			draw_line(trend_points[i], trend_points[i + 1], trend_color, 4)
	
	# Display statistics
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

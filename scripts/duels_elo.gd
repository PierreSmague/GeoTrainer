extends Control

var data: Array = []
var chart_title: String = ""
var line_color: Color = Color.CYAN
var padding: int = 60

func set_data(new_data: Array, title: String = "Chart", color: Color = Color.CYAN):
	data = new_data
	chart_title = title
	line_color = color
	queue_redraw()

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
	
	# Draw points and lines
	var points = PackedVector2Array()
	for i in range(data.size()):
		var x = padding + (float(i) / (data.size() - 1 if data.size() > 1 else 1)) * drawable_width
		var normalized = (data[i] - min_val) / range_val
		var y = origin.y - normalized * drawable_height
		points.append(Vector2(x, y))
		
		# Draw point
		draw_circle(Vector2(x, y), 5, line_color)
		
		# Draw label every N points to avoid overlap
		if data.size() <= 20 or i % max(1, int(data.size() / 10)) == 0 or i == data.size() - 1:
			var label = "G" + str(i + 1)  # G for Game
			var label_pos = Vector2(x, origin.y + 20)
			draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.LIGHT_GRAY)
	
	# Draw lines between points
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], line_color, 3)
	
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

extends Node
class_name DeterminePriorities

const STATS_FILE := "user://stats_detailed.json"

func load_and_compute() -> Array:
	if not FileAccess.file_exists(STATS_FILE):
		push_error("stats_detailed.json not found")
		return []

	var file = FileAccess.open(STATS_FILE, FileAccess.READ)
	if not file:
		push_error("Cannot open stats_detailed.json")
		return []

	var stats: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if stats == null or stats.is_empty():
		return []

	return _compute_priorities(stats)


# ============================================================
# PRIORITY METRIC (PURE LOGIC)
# ============================================================
func _compute_priorities(stats: Dictionary) -> Array:
	var priorities: Array = []

	# --------------------------------------------------------
	# Occurrences & frequency (normalized by total rounds)
	# --------------------------------------------------------
	var total_rounds := 0.0

	for c in stats.values():
		if c.score_delta.avg != 0:
			c["occurences"] = c.score_delta.total / c.score_delta.avg
		else:
			c["occurences"] = 0

		total_rounds += c["occurences"]

	if total_rounds == 0:
		return []

	for c in stats.values():
		c["frequency"] = c["occurences"] / total_rounds

	# --------------------------------------------------------
	# Priority scores
	# --------------------------------------------------------
	for country in stats.keys():
		var c = stats[country]
		var freq: float = c["frequency"]

		# ---------------- Identification ----------------
		var potential_precision :float= (100.0 - c.precision.player) / 100.0
		var delta_precision :float= (c.precision.player - c.precision.opponent) / 100.0
		var penalty_precision :float= (
			c.avg_score_correct.player
			- c.avg_score_incorrect.player
		)

		var precision_priority :float= 0.5 * freq * potential_precision * penalty_precision

		if delta_precision < 0:
			precision_priority -= 5.0 * freq * delta_precision * penalty_precision
			
		if c.avg_score_correct.player == 0:
			precision_priority = 0

		if precision_priority > 0:
			priorities.append({
				"type": "Identification",
				"country": country,
				"score": int(round(precision_priority))
			})

		# ---------------- Regionguess ----------------
		var potential_regionguess :float= 5000.0 - c.avg_score_correct.player
		var delta_regionguess :float= (
			c.avg_score_correct.player
			- c.avg_score_correct.opponent
		)

		var regionguess_priority := 0.5 * freq * potential_regionguess

		if delta_regionguess < 0:
			regionguess_priority -= 5.0 * freq * delta_regionguess

		if regionguess_priority > 0:
			priorities.append({
				"type": "Regionguess",
				"country": country,
				"score": int(round(regionguess_priority))
			})

	# --------------------------------------------------------
	# Sort
	# --------------------------------------------------------
	priorities.sort_custom(func(a, b):
		return a.score > b.score
	)

	return priorities

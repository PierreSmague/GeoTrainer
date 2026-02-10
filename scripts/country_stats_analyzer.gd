class_name CountryStatsAnalyzer

static func analyze_duels(duels_data: Array, player_id: String) -> Dictionary:
	var player_stats = {}
	var opponent_stats = {}

	for duel in duels_data:
		_analyze_duel(duel, player_stats, opponent_stats)

	var country_stats = {}
	var exported_stats = {}

	for country in player_stats.keys():
		var result = _process_country_stats(country, player_stats, opponent_stats)
		country_stats[country] = result["country_stats"]
		exported_stats[country] = result["exported_stats"]

	return {"country_stats": country_stats, "exported_stats": exported_stats}


static func _analyze_duel(duel: Dictionary, player_stats: Dictionary, opponent_stats: Dictionary):
	if not duel.has("rounds"):
		return

	for round in duel["rounds"]:
		var correct_country = round["actualCountry"]

		if round.has("player") and round["player"].size() > 0:
			var guessed_country = round["player"]["guessedCountry"]
			var distance = round["player"]["distance"]
			var score = round["player"]["score"]
			_update_stats(player_stats, correct_country, guessed_country, distance, score)

		if round.has("opponent") and round["opponent"].size() > 0:
			var guessed_country = round["opponent"]["guessedCountry"]
			var distance = round["opponent"]["distance"]
			var score = round["opponent"]["score"]
			_update_stats(opponent_stats, correct_country, guessed_country, distance, score)


static func _update_stats(stats: Dictionary, correct_country: String, guessed_country: String, distance: float, score: int):
	if not stats.has(correct_country):
		stats[correct_country] = {
			"correct": 0,
			"total": 0,
			"correct_distance": 0.0,
			"total_score": 0,
			"correct_score": 0
		}

	stats[correct_country]["total"] += 1
	stats[correct_country]["total_score"] += score

	if guessed_country == correct_country:
		stats[correct_country]["correct"] += 1
		stats[correct_country]["correct_distance"] += distance
		stats[correct_country]["correct_score"] += score


static func _process_country_stats(country: String, player_stats: Dictionary, opponent_stats: Dictionary) -> Dictionary:
	var player_correct = player_stats[country]["correct"]
	var player_total = player_stats[country]["total"]
	var player_accuracy = (float(player_correct) / player_total) * 100.0 if player_total > 0 else 0.0

	var opp_correct = opponent_stats[country]["correct"] if opponent_stats.has(country) else 0
	var opp_total = opponent_stats[country]["total"] if opponent_stats.has(country) else 0
	var opp_accuracy = (float(opp_correct) / opp_total) * 100.0 if opp_total > 0 else 0.0

	var player_avg_score = float(player_stats[country]["total_score"]) / player_total if player_total > 0 else 0.0
	var opp_avg_score = float(opponent_stats[country]["total_score"]) / opp_total if opp_total > 0 and opponent_stats.has(country) else 0.0

	var player_avg_score_correct = 0.0
	var opp_avg_score_correct = 0.0
	if player_correct > 0:
		player_avg_score_correct = float(player_stats[country]["correct_score"]) / player_correct
	if opp_correct > 0 and opponent_stats.has(country):
		opp_avg_score_correct = float(opponent_stats[country]["correct_score"]) / opp_correct

	var mean_score_correct = (player_avg_score_correct + opp_avg_score_correct) / 2.0 if (player_correct + opp_correct) > 0 else 1.0
	var regionguess_performance = (player_avg_score_correct - opp_avg_score_correct) / mean_score_correct if mean_score_correct > 0 else 0.0
	var regionguess_diff = 0.0
	if player_correct > 0 and opp_correct > 0:
		regionguess_diff = player_avg_score_correct - opp_avg_score_correct

	var score_delta = player_avg_score - opp_avg_score
	var total_score_diff = score_delta * player_total

	var cs = {
		"precision": player_accuracy,
		"relative_precision": player_accuracy - opp_accuracy,
		"regionguess_perf": regionguess_performance * 100.0,
		"regionguess": regionguess_diff,
		"global_absolute_score": total_score_diff,
		"global_relative_score": score_delta,
		"player_accuracy": player_accuracy,
		"opponent_accuracy": opp_accuracy,
		"player_avg_score": player_avg_score,
		"opponent_avg_score": opp_avg_score,
		"player_avg_score_correct": player_avg_score_correct,
		"opponent_avg_score_correct": opp_avg_score_correct,
		"total_rounds": player_total
	}

	var es = {
		"precision": {
			"player": player_accuracy,
			"opponent": opp_accuracy
		},
		"avg_region_km": {
			"player": player_stats[country]["correct_distance"] / player_correct / 1000.0 if player_correct > 0 else 0.0,
			"opponent": opponent_stats[country]["correct_distance"] / opp_correct / 1000.0 if opp_correct > 0 else 0.0
		},
		"avg_score": {
			"player": player_avg_score,
			"opponent": opp_avg_score
		},
		"avg_score_correct": {
			"player": player_avg_score_correct,
			"opponent": opp_avg_score_correct
		},
		"avg_score_incorrect": {
			"player": (player_stats[country]["total_score"] - player_stats[country]["correct_score"]) / max(1, player_total - player_correct),
			"opponent": (opponent_stats[country]["total_score"] - opponent_stats[country]["correct_score"]) / max(1, opp_total - opp_correct)
		},
		"score_delta": {
			"avg": score_delta,
			"total": total_score_diff
		}
	}

	return {"country_stats": cs, "exported_stats": es}

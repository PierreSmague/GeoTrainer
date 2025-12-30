extends TabContainer

const duels_detailed := "user://duels_detailed.json"
const profile := "user://profile.json"

@onready var duels_elo_chart = $ELO

var player_id: String = ""

func _ready():
	_load_player_id()
	_load_duels_stats()
	
func _refresh():
	_load_player_id()
	_load_duels_stats()

func _load_player_id():
	var file = FileAccess.open(profile, FileAccess.READ)
	if file:
		var profile_data = JSON.parse_string(file.get_as_text())
		file.close()
		if profile_data and profile_data["user"].has("id"):
			player_id = profile_data["user"]["id"]
			print("Player ID loaded: ", player_id)

func _load_duels_stats():
	# Check if file exists
	if not FileAccess.file_exists(duels_detailed):
		print("duels_detailed.json file not found")
		duels_elo_chart.visible = false
		return
	
	# Load data
	var file = FileAccess.open(duels_detailed, FileAccess.READ)
	if not file:
		push_error("Cannot open duels_detailed.json")
		duels_elo_chart.visible = false
		return
	
	var duels_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not duels_data or duels_data.size() == 0:
		print("No duels found in duels_detailed.json")
		duels_elo_chart.visible = false
		return
	
	# Extract ELO ratings (reverse order since duels are from newest to oldest)
	var elo_data = []
	for i in range(duels_data.size() - 1, -1, -1):  # Iterate backwards
		var duel = duels_data[i]
		var rating = duel["playerRatingAfter"]
		if rating != -1:
			elo_data.append(rating)
	
	if elo_data.size() == 0:
		print("No ELO found in duels")
		duels_elo_chart.visible = false
		return
	
	# Display chart
	duels_elo_chart.visible = true
	duels_elo_chart.set_data(elo_data, "Duels - ELO evolution")
	
	print("Duels stats loaded: %d ELO points" % elo_data.size())

extends PanelContainer

@onready var title_label: Label = $Priorities/Title
@onready var priority_list: VBoxContainer = $Priorities/ScrollContainer/PriorityList
@onready var priority_engine := DeterminePriorities.new()

var priorities: Array = []
var country_names: Dictionary = {}

func _ready():
	country_names = FileManager.load_json(FilePaths.COUNTRIES, {})
	_load_and_compute()

func _refresh():
	_load_and_compute()


func _load_and_compute():
	priorities = priority_engine.load_and_compute()
	_display_priorities()


# ============================================================
# UI DISPLAY (SCROLLABLE)
# ============================================================
func _display_priorities():
	for child in priority_list.get_children():
		child.queue_free()

	var rank := 1

	for p in priorities:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var rank_label = Label.new()
		rank_label.text = "%d." % rank
		rank_label.custom_minimum_size.x = 30
		row.add_child(rank_label)

		var country_display :String = p.country.to_lower()
		if country_names.has(country_display):
			country_display = country_names[country_display]

		var desc_label = Label.new()
		desc_label.text = "%s – %s" % [p.type, country_display]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_label)

		var score_label = Label.new()
		score_label.text = str(p.score)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.custom_minimum_size.x = 70
		row.add_child(score_label)

		priority_list.add_child(row)
		rank += 1

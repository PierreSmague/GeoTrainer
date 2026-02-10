extends Popup

@onready var spin_box_duels = $VBoxContainer/DuelsSection/N_games_duels/N_chosen_duels
@onready var label_total_duels = $VBoxContainer/DuelsSection/N_games_duels/N_total_duels

@onready var spin_box_solos = $VBoxContainer/SolosSection/N_games_solos/N_chosen_solos
@onready var label_total_solos = $VBoxContainer/SolosSection/N_games_solos/N_total_solos

@onready var button_validate = $VBoxContainer/ButtonValidate

var total_duels = 0
var total_solos = 0

func _ready():
	_load_duels_count()
	_load_solos_count()
	button_validate.pressed.connect(_on_validate_pressed)

func _refresh():
	_load_duels_count()
	_load_solos_count()

func _load_duels_count():
	var duels = FileManager.load_json(FilePaths.DUELS)
	if duels and duels is Array:
		total_duels = duels.size()
		label_total_duels.text = "Total: " + str(total_duels)
		spin_box_duels.max_value = total_duels
		spin_box_duels.min_value = 0
		spin_box_duels.value = min(10, total_duels)

func _load_solos_count():
	var solos = FileManager.load_json(FilePaths.SOLO)
	if solos and solos is Array:
		total_solos = solos.size()
		label_total_solos.text = "Total: " + str(total_solos)
		spin_box_solos.max_value = total_solos
		spin_box_solos.min_value = 0
		spin_box_solos.value = min(10, total_solos)

func get_n_duels():
	return spin_box_duels.value

func get_n_solos():
	return spin_box_solos.value

func _on_validate_pressed():
	get_parent()._on_popup_validate()

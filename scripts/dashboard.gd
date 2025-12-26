extends Control

func _ready():
	$StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	print("Début de l'entraînement !")

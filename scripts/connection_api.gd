extends MarginContainer

func _ready():
	# Connexion du signal avec la syntaxe moderne
	$Connection.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	print("Connexion à l'API Geoguessr...")

extends Button

# Chemin vers le fichier ncfa.txt (dans le dossier user:// pour persistance)
const NCFA_FILE_PATH = "res://user/ncfa.txt"

func _ready():
	self.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	# Vérifie si le fichier existe
	if FileAccess.file_exists(NCFA_FILE_PATH):
		print("Le fichier ncfa.txt existe déjà. Aucune action.")
		return

	# Sinon, ouvre la popup
	var popup = $Popup_ncfa
	popup.popup_centered()

func _save_ncfa(ncfa_string):
	# Sauvegarde le ncfa dans le fichier
	var file = FileAccess.open(NCFA_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(ncfa_string)
		file.close()
		print("NCFA sauvegardé dans ncfa.txt.")
	else:
		print("Erreur : impossible de créer le fichier ncfa.txt.")

# Fonction appelée quand l'utilisateur valide dans la popup
func _on_popup_validate():
	var ncfa = $Popup_ncfa/LineEdit.text
	if ncfa.is_empty():
		print("Erreur : le champ NCFA est vide.")
		return

	_save_ncfa(ncfa)
	$Popup_ncfa.hide()  # Ferme la popup

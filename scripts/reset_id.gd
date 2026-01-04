extends Button

@onready var confirm_popup: ConfirmationDialog = $"../ConfirmationPopup"
@onready var connection_api := get_parent().get_parent()

func _ready():
	pressed.connect(_on_reset_pressed)

	# Configuration du popup
	confirm_popup.confirmed.connect(_on_proceed)
	confirm_popup.canceled.connect(_on_cancel)

	confirm_popup.title = "Reset user data"
	confirm_popup.dialog_text = "%s\n\n%s" % [
	"This will permanently delete all local data.",
	"Are you sure you want to proceed?"
]

	confirm_popup.ok_button_text = "Proceed"
	confirm_popup.cancel_button_text = "Cancel"


# ----------------------------------------------------
# Button pressed
# ----------------------------------------------------
func _on_reset_pressed():
	confirm_popup.popup_centered()


# ----------------------------------------------------
# Cancel
# ----------------------------------------------------
func _on_cancel():
	confirm_popup.hide()


# ----------------------------------------------------
# Proceed
# ----------------------------------------------------
func _on_proceed():
	_clear_user_folder()
	confirm_popup.hide()

	if connection_api.has_method("_refresh_ui"):
		connection_api._refresh_ui()
	else:
		push_warning("Parent has no _refresh_ui() method")

func _clear_user_folder():
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("Cannot access user://")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := "user://" + file_name

			if dir.current_is_dir():
				_delete_directory_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

	print("user:// cleared successfully")


func _delete_directory_recursive(path: String):
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := path + "/" + file_name

			if dir.current_is_dir():
				_delete_directory_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	DirAccess.remove_absolute(path)

extends TabContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_tab_changed(tab_index):
	var scenes = [
		preload("res://scenes/dashboard.tscn"),
		preload("res://scenes/training.tscn"),
		preload("res://scenes/resources.tscn"),
		preload("res://scenes/stats.tscn")
	]
	$Tabs.get_child(tab_index).add_child(scenes[tab_index].instantiate())

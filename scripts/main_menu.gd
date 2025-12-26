extends Control

func _ready():
	# Tab initialisation
	$Tabs.tab_changed.connect(_on_tab_changed)

func _on_tab_changed(tab_index):
	match tab_index:
		0:
			print("Dahsboard selected")
		1:
			print("Training selected")
		2:
			print("Resources selected")
		3:
			print("Stats selected")

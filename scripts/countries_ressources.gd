extends ScrollContainer

@export var country_name: String = "Botswana"

@onready var docs_list = $Content/DocsColumn/DocsList
@onready var doc_item_scene = preload("res://ui/doc_item/DocItem.tscn")

var all_docs = {}

func _ready():
	all_docs = load_json("res://misc/resources.json")
	var docs = all_docs.get(country_name, [])
	
	# Sort documents according to criteria
	docs = _sort_documents(docs)
	
	for doc in docs:
		var map_url = doc.get("map", "")
		add_doc(doc.title, doc.difficulty, doc.usefulness, doc.url, map_url)

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JSON file not found: %s" % path)
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	
	var json: Variant = JSON.parse_string(content)
	if json == null:
		push_error("Invalid JSON in %s" % path)
		return {}
	
	return json

func _sort_documents(docs: Array) -> Array:
	var sorted_docs = docs.duplicate()
	
	sorted_docs.sort_custom(func(a, b):
		var score_a = a.usefulness - a.difficulty
		var score_b = b.usefulness - b.difficulty
		
		if score_a != score_b:
			return score_a > score_b
		
		if a.difficulty != b.difficulty:
			return a.difficulty < b.difficulty
		
		return false
	)
	
	return sorted_docs

func add_doc(title: String, difficulty: int, usefulness: int, url: String, map_url: String = ""):
	var item = doc_item_scene.instantiate()
	docs_list.add_child(item)
	item.set_data(title, difficulty, usefulness, url, map_url)

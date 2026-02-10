extends ScrollContainer

@export var country_name: String = "Botswana"

@onready var docs_list = $Content/DocsColumn/DocsList
@onready var doc_item_scene = preload("res://ui/doc_item/DocItem.tscn")

var all_docs = {}

func _ready():
	all_docs = FileManager.load_json(FilePaths.RESOURCES, {})
	var docs = all_docs.get(country_name, [])

	docs = _sort_documents(docs)

	for doc in docs:
		var map_url = doc.get("map", "")
		add_doc(doc.title, doc.difficulty, doc.usefulness, doc.url, map_url)

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

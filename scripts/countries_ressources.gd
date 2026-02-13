extends ScrollContainer

@export var country_name: String = "Botswana"

@onready var docs_list = $Content/DocsColumn/DocsList
@onready var doc_item_scene = preload("res://ui/doc_item/DocItem.tscn")

var all_docs = {}
var flag_texture: Texture2D = null

func _ready():
	all_docs = FileManager.load_json(FilePaths.RESOURCES, {})
	var docs = all_docs.get(country_name, [])

	docs = _sort_documents(docs)

	for doc in docs:
		var map_url = doc.get("map", "")
		add_doc(doc.title, doc.difficulty, doc.usefulness, doc.url, map_url)

	_load_flag()

func _load_flag():
	var countries_map = FileManager.load_json(FilePaths.COUNTRIES, {})
	var code = GeoUtils.country_name_to_code(country_name, countries_map)
	if code == "":
		return
	var path = FilePaths.FLAGS_DIR + code + ".svg"
	if ResourceLoader.exists(path):
		flag_texture = load(path)
		queue_redraw()

func _draw():
	if flag_texture == null:
		return
	var tex_size = flag_texture.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		return
	var draw_size = size
	draw_texture_rect(flag_texture, Rect2(Vector2.ZERO, draw_size), false, Color(1, 1, 1, 0.08))

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

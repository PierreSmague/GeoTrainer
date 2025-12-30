extends Node

var countries: Dictionary = {}

func _ready():
	load_country("botswana")

func load_country(code: String):
	var path = "res://data/countries/%s.tres" % code
	var res: CountryResources = load(path)
	countries[code] = res

func get_country(code: String) -> CountryResources:
	return countries.get(code)

func get_docs(code: String) -> Array[DocResource]:
	return get_country(code).docs

func get_maps(code: String) -> Array[DocResource]:
	return get_country(code).maps

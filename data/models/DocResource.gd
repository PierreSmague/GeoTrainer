extends Resource
class_name DocResource

@export var title: String
@export var url: String
@export_range(1, 5) var difficulty: int = 3
@export_range(1, 5) var usefulness: int = 3

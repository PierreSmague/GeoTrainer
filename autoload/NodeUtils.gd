class_name NodeUtils

static func find_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var result = find_by_name(child, node_name)
		if result:
			return result
	return null

static func refresh_recursive(node: Node) -> void:
	if node.has_method("_refresh"):
		node._refresh()
	for child in node.get_children():
		refresh_recursive(child)

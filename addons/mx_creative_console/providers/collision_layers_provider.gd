extends MXOptionProvider
## Toggle collision_layer / collision_mask bits on the selected CollisionObject2D or CollisionObject3D.

const ID_TOGGLE_LAYER := "mx.collision.toggle_layer"
const ID_TOGGLE_MASK := "mx.collision.toggle_mask"


func _init() -> void:
	priority = 13


func _first_collision_3d(context: Dictionary) -> CollisionObject3D:
	for n in context.get("selected_nodes", []):
		if n is CollisionObject3D:
			return n
	return null


func _first_collision_2d(context: Dictionary) -> CollisionObject2D:
	for n in context.get("selected_nodes", []):
		if n is CollisionObject2D:
			return n
	return null


func _collision_target(context: Dictionary) -> Node:
	var c3 := _first_collision_3d(context)
	if c3 != null:
		return c3
	return _first_collision_2d(context)


func build_options(_context: Dictionary) -> Array:
	return []


func apply_event(
	event: Dictionary,
	context: Dictionary,
	_editor: EditorInterface,
	undo: EditorUndoRedoManager,
) -> bool:
	var id := str(event.get("id", ""))
	var kind := str(event.get("kind", ""))
	if kind != "set_int":
		return false
	var node := _collision_target(context)
	if node == null:
		return false
	var layer_idx := int(event.get("value", 0))
	if layer_idx < 1 or layer_idx > 32:
		return false
	match id:
		ID_TOGGLE_LAYER:
			_toggle_uint_prop(node, "collision_layer", layer_idx, undo)
			return true
		ID_TOGGLE_MASK:
			_toggle_uint_prop(node, "collision_mask", layer_idx, undo)
			return true
	return false


func _toggle_uint_prop(node: Node, prop: String, layer_1_to_32: int, undo: EditorUndoRedoManager) -> void:
	var b := layer_1_to_32 - 1
	var cur: int = int(node.get(prop))
	var new_v: int = cur ^ (1 << b)
	_set_prop(node, prop, new_v, undo)


func _set_prop(node: Node, prop: String, value: Variant, undo: EditorUndoRedoManager) -> void:
	var old = node.get(prop)
	undo.create_action("MX Console: %s" % prop)
	undo.add_do_property(node, prop, value)
	undo.add_undo_property(node, prop, old)
	undo.commit_action()

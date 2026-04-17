extends MXOptionProvider
## Selected Node3D or Node2D: visibility, uniform scale, position, rotation (degrees) for MX console / bridge.
## Node3D takes priority when both appear in the selection.

const ID_VISIBLE := "mx.transform.visible"
const ID_SCALE := "mx.transform.scale_uniform"
const ID_POS_X := "mx.transform.position_x"
const ID_POS_Y := "mx.transform.position_y"
const ID_POS_Z := "mx.transform.position_z"
const ID_ROT_X := "mx.transform.rotation_deg_x"
const ID_ROT_Y := "mx.transform.rotation_deg_y"
const ID_ROT_Z := "mx.transform.rotation_deg_z"

const G3 := "Node3D###Transform"
const G2 := "Node2D###Transform"


func _init() -> void:
	priority = 10


func _first_node_3d(context: Dictionary) -> Node3D:
	for n in context.get("selected_nodes", []):
		if n is Node3D:
			return n
	return null


func _first_node_2d(context: Dictionary) -> Node2D:
	for n in context.get("selected_nodes", []):
		if n is Node2D:
			return n
	return null


func build_options(context: Dictionary) -> Array:
	var n3 := _first_node_3d(context)
	if n3 != null:
		return _build_options_3d(n3)
	var n2 := _first_node_2d(context)
	if n2 != null:
		return _build_options_2d(n2)
	return []


func _build_options_3d(node: Node3D) -> Array:
	var u := (node.scale.x + node.scale.y + node.scale.z) / 3.0
	var px: float = node.position.x
	var py: float = node.position.y
	var pz: float = node.position.z
	var rdx: float = rad_to_deg(node.rotation.x)
	var rdy: float = rad_to_deg(node.rotation.y)
	var rdz: float = rad_to_deg(node.rotation.z)
	return [
		MXOption.toggle(ID_VISIBLE, "Visible", node.visible, G3),
		MXOption.range_option(ID_SCALE, "Uniform scale", 0.01, 20.0, 0.01, u, G3),
		MXOption.range_option(ID_POS_X, "Position X", -1e6, 1e6, 0.001, px, G3),
		MXOption.range_option(ID_POS_Y, "Position Y", -1e6, 1e6, 0.001, py, G3),
		MXOption.range_option(ID_POS_Z, "Position Z", -1e6, 1e6, 0.001, pz, G3),
		MXOption.range_option(ID_ROT_X, "Rotation X (°)", -360.0, 360.0, 0.1, rdx, G3),
		MXOption.range_option(ID_ROT_Y, "Rotation Y (°)", -360.0, 360.0, 0.1, rdy, G3),
		MXOption.range_option(ID_ROT_Z, "Rotation Z (°)", -360.0, 360.0, 0.1, rdz, G3),
	]


func _build_options_2d(node: Node2D) -> Array:
	var u := (node.scale.x + node.scale.y) / 2.0
	var px: float = node.position.x
	var py: float = node.position.y
	var rdz: float = rad_to_deg(node.rotation)
	return [
		MXOption.toggle(ID_VISIBLE, "Visible", node.visible, G2),
		MXOption.range_option(ID_SCALE, "Uniform scale", 0.01, 20.0, 0.01, u, G2),
		MXOption.range_option(ID_POS_X, "Position X", -1e6, 1e6, 0.001, px, G2),
		MXOption.range_option(ID_POS_Y, "Position Y", -1e6, 1e6, 0.001, py, G2),
		MXOption.range_option(ID_ROT_Z, "Rotation (°)", -360.0, 360.0, 0.1, rdz, G2),
	]


func apply_event(
	event: Dictionary,
	context: Dictionary,
	_editor: EditorInterface,
	undo: EditorUndoRedoManager,
) -> bool:
	var n3 := _first_node_3d(context)
	if n3 != null:
		return _apply_to_node3d(event, n3, undo)
	var n2 := _first_node_2d(context)
	if n2 != null:
		return _apply_to_node2d(event, n2, undo)
	return false


func _apply_to_node3d(event: Dictionary, node: Node3D, ur: EditorUndoRedoManager) -> bool:
	var id := str(event.get("id", ""))
	var kind := str(event.get("kind", ""))
	match id:
		ID_VISIBLE:
			if kind == "set_bool":
				var v := bool(event.get("value", false))
				var old: bool = node.visible
				ur.create_action("MX Console: Visible")
				ur.add_do_property(node, "visible", v)
				ur.add_undo_property(node, "visible", old)
				ur.commit_action()
				return true
		ID_SCALE:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var v := float(event.get("value", 1.0))
				var old: Vector3 = node.scale
				if is_rel: v += (old.x + old.y + old.z) / 3.0
				var new_s := Vector3(v, v, v)
				ur.create_action("MX Console: Scale")
				ur.add_do_property(node, "scale", new_s)
				ur.add_undo_property(node, "scale", old)
				ur.commit_action()
				return true
		ID_POS_X:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var v := float(event.get("value", 0.0))
				var old: Vector3 = node.position
				var new_p := Vector3(old.x + v if is_rel else v, old.y, old.z)
				ur.create_action("MX Console: Position X")
				ur.add_do_property(node, "position", new_p)
				ur.add_undo_property(node, "position", old)
				ur.commit_action()
				return true
		ID_POS_Y:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var v := float(event.get("value", 0.0))
				var old: Vector3 = node.position
				var new_p := Vector3(old.x, old.y + v if is_rel else v, old.z)
				ur.create_action("MX Console: Position Y")
				ur.add_do_property(node, "position", new_p)
				ur.add_undo_property(node, "position", old)
				ur.commit_action()
				return true
		ID_POS_Z:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var v := float(event.get("value", 0.0))
				var old: Vector3 = node.position
				var new_p := Vector3(old.x, old.y, old.z + v if is_rel else v)
				ur.create_action("MX Console: Position Z")
				ur.add_do_property(node, "position", new_p)
				ur.add_undo_property(node, "position", old)
				ur.commit_action()
				return true
		ID_ROT_X:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var deg := float(event.get("value", 0.0))
				var old: Vector3 = node.rotation
				var new_rx := clampf(rad_to_deg(old.x) + deg if is_rel else deg, -360.0, 360.0)
				var new_r := Vector3(deg_to_rad(new_rx), old.y, old.z)
				ur.create_action("MX Console: Rotation X")
				ur.add_do_property(node, "rotation", new_r)
				ur.add_undo_property(node, "rotation", old)
				ur.commit_action()
				return true
		ID_ROT_Y:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var deg := float(event.get("value", 0.0))
				var old: Vector3 = node.rotation
				var new_ry := clampf(rad_to_deg(old.y) + deg if is_rel else deg, -360.0, 360.0)
				var new_r := Vector3(old.x, deg_to_rad(new_ry), old.z)
				ur.create_action("MX Console: Rotation Y")
				ur.add_do_property(node, "rotation", new_r)
				ur.add_undo_property(node, "rotation", old)
				ur.commit_action()
				return true
		ID_ROT_Z:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var deg := float(event.get("value", 0.0))
				var old: Vector3 = node.rotation
				var new_rz := clampf(rad_to_deg(old.z) + deg if is_rel else deg, -360.0, 360.0)
				var new_r := Vector3(old.x, old.y, deg_to_rad(new_rz))
				ur.create_action("MX Console: Rotation Z")
				ur.add_do_property(node, "rotation", new_r)
				ur.add_undo_property(node, "rotation", old)
				ur.commit_action()
				return true
	return false


func _apply_to_node2d(event: Dictionary, node: Node2D, ur: EditorUndoRedoManager) -> bool:
	var id := str(event.get("id", ""))
	var kind := str(event.get("kind", ""))
	match id:
		ID_VISIBLE:
			if kind == "set_bool":
				var v := bool(event.get("value", false))
				var old: bool = node.visible
				ur.create_action("MX Console: Visible")
				ur.add_do_property(node, "visible", v)
				ur.add_undo_property(node, "visible", old)
				ur.commit_action()
				return true
		ID_SCALE:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var v := float(event.get("value", 1.0))
				var old: Vector2 = node.scale
				if is_rel: v += (old.x + old.y) / 2.0
				var new_s := Vector2(v, v)
				ur.create_action("MX Console: Scale")
				ur.add_do_property(node, "scale", new_s)
				ur.add_undo_property(node, "scale", old)
				ur.commit_action()
				return true
		ID_POS_X:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var v := float(event.get("value", 0.0))
				var old: Vector2 = node.position
				var new_p := Vector2(old.x + v if is_rel else v, old.y)
				ur.create_action("MX Console: Position X")
				ur.add_do_property(node, "position", new_p)
				ur.add_undo_property(node, "position", old)
				ur.commit_action()
				return true
		ID_POS_Y:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var v := float(event.get("value", 0.0))
				var old: Vector2 = node.position
				var new_p := Vector2(old.x, old.y + v if is_rel else v)
				ur.create_action("MX Console: Position Y")
				ur.add_do_property(node, "position", new_p)
				ur.add_undo_property(node, "position", old)
				ur.commit_action()
				return true
		ID_POS_Z, ID_ROT_X, ID_ROT_Y:
			return false
		ID_ROT_Z:
			if kind == "set_float":
				var is_rel := bool(event.get("relative", false))
				var deg := float(event.get("value", 0.0))
				var old: float = node.rotation
				var new_rz := clampf(rad_to_deg(old) + deg if is_rel else deg, -360.0, 360.0)
				var new_r := deg_to_rad(new_rz)
				ur.create_action("MX Console: Rotation")
				ur.add_do_property(node, "rotation", new_r)
				ur.add_undo_property(node, "rotation", old)
				ur.commit_action()
				return true
	return false

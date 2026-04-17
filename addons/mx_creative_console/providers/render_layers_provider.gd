extends MXOptionProvider
## Unified folder: [VisualInstance3D] layers 1–20 (see Godot 4.6 docs) or [CanvasItem] visibility (bit index 0–19 for UI slots 1–20). Light mask: 20 bits.

const ID_RENDER_LAYERS := "mx.render_layers.toggle"
## Kept for older Logitech profiles / manual events.
const _ID_LEGACY_CANVAS_VIS := "mx.canvas.visibility_layer.toggle"
const _ID_LEGACY_VI_LAYERS := "mx.visual_instance.layers.toggle"
const ID_CANVAS_LIGHT := "mx.canvas.light_mask.toggle"
const RENDER_SLOTS := 20
const MASK_20 := (1 << RENDER_SLOTS) - 1


func _init() -> void:
	priority = 11


func _first_canvas_item(context: Dictionary) -> CanvasItem:
	for n in context.get("selected_nodes", []):
		if n is CanvasItem:
			return n
	return null


func _first_visual_instance(context: Dictionary) -> VisualInstance3D:
	for n in context.get("selected_nodes", []):
		if n is VisualInstance3D:
			return n
	return null


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
	var layer_idx := int(event.get("value", 0))
	if layer_idx < 1 or layer_idx > RENDER_SLOTS:
		return false
	match id:
		ID_RENDER_LAYERS, _ID_LEGACY_CANVAS_VIS, _ID_LEGACY_VI_LAYERS:
			var vi := _first_visual_instance(context)
			if vi != null:
				_toggle_visual_instance_layer(vi, layer_idx, undo)
				return true
			var ci := _first_canvas_item(context)
			if ci != null:
				_toggle_visibility_layer_bit(ci, layer_idx, undo)
				return true
			return false
		ID_CANVAS_LIGHT:
			var ci2 := _first_canvas_item(context)
			if ci2 == null:
				return false
			_toggle_light_mask_bit(ci2, layer_idx, undo)
			return true
	return false


func _toggle_visibility_layer_bit(ci: CanvasItem, layer_1_to_20: int, undo: EditorUndoRedoManager) -> void:
	# CanvasItem: bit index 0..31 (layer "1" in the inspector = index 0). Unlike VisualInstance3D, which uses 1..20.
	var bit := layer_1_to_20 - 1
	if bit < 0 or bit >= RENDER_SLOTS:
		return
	var old_on := ci.get_visibility_layer_bit(bit)
	undo.create_action("MX Console: visibility_layer")
	undo.add_do_method(ci, "set_visibility_layer_bit", bit, not old_on)
	undo.add_undo_method(ci, "set_visibility_layer_bit", bit, old_on)
	undo.commit_action()


func _toggle_light_mask_bit(ci: CanvasItem, layer_1_to_20: int, undo: EditorUndoRedoManager) -> void:
	var b := layer_1_to_20 - 1
	var cur: int = int(ci.light_mask)
	var new_v: int = (cur ^ (1 << b)) & MASK_20
	_set_prop(ci, "light_mask", new_v, undo)


func _toggle_visual_instance_layer(vi: VisualInstance3D, layer_1_to_20: int, undo: EditorUndoRedoManager) -> void:
	var old_on := vi.get_layer_mask_value(layer_1_to_20)
	undo.create_action("MX Console: visual layers")
	undo.add_do_method(vi, "set_layer_mask_value", layer_1_to_20, not old_on)
	undo.add_undo_method(vi, "set_layer_mask_value", layer_1_to_20, old_on)
	undo.commit_action()


func _set_prop(node: Node, prop: String, value: Variant, undo: EditorUndoRedoManager) -> void:
	var old = node.get(prop)
	undo.create_action("MX Console: %s" % prop)
	undo.add_do_property(node, prop, value)
	undo.add_undo_property(node, prop, old)
	undo.commit_action()

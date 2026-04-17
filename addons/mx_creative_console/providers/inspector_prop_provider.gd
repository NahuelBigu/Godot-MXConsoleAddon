extends MXOptionProvider
## Exposes whatever float/int range property is currently focused in the Inspector,
## so any property with a slider in Godot can be controlled with a dial — generically.

const ID := "mx.inspector.focused_prop"


func _init() -> void:
	priority = 100


func build_options(context: Dictionary) -> Array:
	var fp: Dictionary = context.get("focused_inspector_prop", {})
	if fp.is_empty():
		return []
	var obj: Object = fp.get("object", null)
	if not is_instance_valid(obj):
		return []
	var prop: String = fp.get("property", "")
	var cur: float = float(obj.get(prop))
	return [
		MXOption.range_option(
			ID,
			fp.get("label", prop),
			fp.get("min", 0.0),
			fp.get("max", 1.0),
			fp.get("step", 0.001),
			cur,
			"Inspector",
		),
	]


func apply_event(
	event: Dictionary,
	context: Dictionary,
	_editor: EditorInterface,
	undo: EditorUndoRedoManager,
) -> bool:
	if str(event.get("id", "")) != ID:
		return false
	if str(event.get("kind", "")) != "set_float":
		return false
	var fp: Dictionary = context.get("focused_inspector_prop", {})
	if fp.is_empty():
		return false
	var obj: Object = fp.get("object", null)
	if not is_instance_valid(obj):
		return false
	var prop: String = fp.get("property", "")
	var mn := float(fp.get("min", 0.0))
	var mx := float(fp.get("max", 1.0))
	var fp_step := float(fp.get("step", 0.001))
	var old: float = float(obj.get(prop))
	var v: float
	if bool(event.get("relative", false)):
		var n := int(round(float(event.get("value", 0.0))))
		if n == 0:
			return true
		var st := fp_step
		if st <= 0.0:
			st = maxf((mx - mn) * 0.001, 1e-9) if mx > mn else 0.001
		v = old + float(n) * st
		v = clampf(v, mn, mx)
		if fp_step > 0.0:
			v = mn + round((v - mn) / fp_step) * fp_step
			v = clampf(v, mn, mx)
	else:
		v = float(event.get("value", 0.0))
	undo.create_action("MX Console: %s" % prop)
	undo.add_do_property(obj, prop, v)
	undo.add_undo_property(obj, prop, old)
	undo.commit_action()
	return true

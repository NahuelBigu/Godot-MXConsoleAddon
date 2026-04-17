extends MXOptionProvider
## GPU/CPU particles (2D & 3D). Amount ratio is only offered for GPUParticles2D/3D.

const ID_EMITTING := "mx.particles.emitting"
const ID_AMOUNT := "mx.particles.amount"
const ID_AMOUNT_RATIO := "mx.particles.amount_ratio"
const ID_ONE_SHOT := "mx.particles.one_shot"
const ID_LIFETIME := "mx.particles.lifetime"
const ID_SPEED_SCALE := "mx.particles.speed_scale"
const ID_EXPLOSIVENESS := "mx.particles.explosiveness"
const ID_RANDOMNESS := "mx.particles.randomness"
const ID_RESTART := "mx.particles.restart"

const GP := "Particles"


func _init() -> void:
	priority = 15


func _first_particles(context: Dictionary) -> Node:
	for n in context.get("selected_nodes", []):
		if n is GPUParticles3D or n is GPUParticles2D or n is CPUParticles3D or n is CPUParticles2D:
			return n
	return null


func _supports_amount_ratio(node: Node) -> bool:
	return node is GPUParticles2D or node is GPUParticles3D


func build_options(context: Dictionary) -> Array:
	var node := _first_particles(context)
	if node == null:
		return []
	var opts: Array = [
		MXOption.toggle(ID_EMITTING, "Emitting", node.emitting, GP),
		MXOption.toggle(ID_ONE_SHOT, "One Shot", node.one_shot, GP),
		MXOption.range_option(ID_AMOUNT, "Amount", 1, 10000, 1, node.amount, GP),
	]
	if _supports_amount_ratio(node):
		opts.append(MXOption.range_option(ID_AMOUNT_RATIO, "Amount Ratio", 0.0, 1.0, 0.01, node.amount_ratio, GP))
	opts.append_array([
		MXOption.range_option(ID_LIFETIME, "Lifetime", 0.01, 600.0, 0.01, node.lifetime, GP),
		MXOption.range_option(ID_SPEED_SCALE, "Speed Scale", 0.0, 64.0, 0.05, node.speed_scale, GP),
		MXOption.range_option(ID_EXPLOSIVENESS, "Explosiveness", 0.0, 1.0, 0.01, node.explosiveness, GP),
		MXOption.range_option(ID_RANDOMNESS, "Randomness", 0.0, 1.0, 0.01, node.randomness, GP),
		MXOption.trigger(ID_RESTART, "Restart", GP),
	])
	return opts


func apply_event(
	event: Dictionary,
	context: Dictionary,
	_editor: EditorInterface,
	undo: EditorUndoRedoManager,
) -> bool:
	var id := str(event.get("id", ""))
	var kind := str(event.get("kind", ""))
	var node := _first_particles(context)
	if node == null:
		return false
	match id:
		ID_EMITTING:
			if kind == "set_bool":
				_set_prop(node, "emitting", bool(event.get("value", false)), undo)
				return true
		ID_ONE_SHOT:
			if kind == "set_bool":
				_set_prop(node, "one_shot", bool(event.get("value", false)), undo)
				return true
		ID_AMOUNT:
			if kind == "set_float" or kind == "set_int":
				_set_prop(node, "amount", int(event.get("value", 8)), undo)
				return true
		ID_AMOUNT_RATIO:
			if not _supports_amount_ratio(node):
				return false
			if kind == "set_float":
				_set_prop(node, "amount_ratio", float(event.get("value", 1.0)), undo)
				return true
		ID_LIFETIME:
			if kind == "set_float":
				var lt := clampf(float(event.get("value", 1.0)), 0.01, 600.0)
				_set_prop(node, "lifetime", lt, undo)
				return true
		ID_SPEED_SCALE:
			if kind == "set_float":
				_set_prop(node, "speed_scale", float(event.get("value", 1.0)), undo)
				return true
		ID_EXPLOSIVENESS:
			if kind == "set_float":
				_set_prop(node, "explosiveness", float(event.get("value", 0.0)), undo)
				return true
		ID_RANDOMNESS:
			if kind == "set_float":
				_set_prop(node, "randomness", float(event.get("value", 0.0)), undo)
				return true
		ID_RESTART:
			if kind == "trigger":
				node.restart()
				return true
	return false


func _set_prop(node: Node, prop: String, value: Variant, undo: EditorUndoRedoManager) -> void:
	var old = node.get(prop)
	undo.create_action("MX Console: %s" % prop)
	undo.add_do_property(node, prop, value)
	undo.add_undo_property(node, prop, old)
	undo.commit_action()

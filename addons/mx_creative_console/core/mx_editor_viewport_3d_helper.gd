class_name MXEditorViewport3dHelper
extends RefCounted
## Horizontal camera viewport yaw orbit around the **selected object** in the editor 3D viewport:
## keeps distance and vertical offset relative to the pivot (rotation around [Vector3.UP]).
##
## If no [Node3D] is selected or no [Camera3D] exists in the viewport, it uses a fallback that simulates
## middle-click dragging ([method SubViewport.push_input] with [code]in_local_coords = true[/code]).
##
## [param steps] is the integer from the bridge (dial detents). **Linear** rotation:
## [code]angle = deg_to_rad(float(steps) * DEGREES_PER_ENCODER_STEP)[/code] (no curves or powers).


## Degrees per detent (linear with [param steps]); ~0.30 degrees per detent.
const DEGREES_PER_ENCODER_STEP := 0.30
## Middle mouse button fallback: proportional to rotation in degrees.
const PIXELS_PER_ENCODER_STEP := 1.75


static func _grab_viewport_host_focus(vp: SubViewport) -> void:
	var p: Node = vp.get_parent()
	while p:
		if p is Control:
			var c := p as Control
			if c.focus_mode != Control.FOCUS_NONE:
				c.grab_focus()
			break
		p = p.get_parent()


static func _find_camera_in_subtree(n: Node) -> Camera3D:
	if n is Camera3D:
		return n as Camera3D
	for c in n.get_children():
		var f := _find_camera_in_subtree(c)
		if f != null:
			return f
	return null


static func _resolve_viewport_camera(vp: SubViewport) -> Camera3D:
	var c := vp.get_camera_3d()
	if c != null and is_instance_valid(c):
		return c
	return _find_camera_in_subtree(vp)


static func _visual_pivot(n: Node3D) -> Vector3:
	if n is VisualInstance3D:
		var vi := n as VisualInstance3D
		var aabb: AABB = vi.get_aabb()
		return vi.global_transform * aabb.get_center()
	return n.global_position


static func _selection_orbit_pivot(editor: EditorInterface) -> Variant:
	var raw_nodes: Array = editor.get_selection().get_selected_nodes()
	if raw_nodes.is_empty():
		return null
	var acc := Vector3.ZERO
	var count := 0
	for node in raw_nodes:
		if node is Node3D:
			acc += _visual_pivot(node as Node3D)
			count += 1
	if count == 0:
		return null
	return acc / float(count)


static func _orbit_camera_yaw_around_pivot(editor: EditorInterface, pivot: Vector3, steps: int) -> bool:
	var vp := editor.get_editor_viewport_3d(0)
	if vp == null:
		return false
	var cam := _resolve_viewport_camera(vp)
	if cam == null:
		return false
	_grab_viewport_host_focus(vp)
	var angle := deg_to_rad(float(steps) * DEGREES_PER_ENCODER_STEP)
	var rel := cam.global_position - pivot
	rel = rel.rotated(Vector3.UP, angle)
	cam.global_position = pivot + rel
	if (pivot - cam.global_position).length_squared() < 0.0001:
		return true
	cam.look_at(pivot, Vector3.UP)
	return true


static func _orbit_yaw_via_middle_mouse_drag(editor: EditorInterface, steps: int) -> bool:
	var vp := editor.get_editor_viewport_3d(0)
	if vp == null:
		return false
	var sz := Vector2(vp.size)
	if sz.x < 2.0 or sz.y < 2.0:
		return false
	_grab_viewport_host_focus(vp)
	var center := sz * 0.5
	var dx := float(steps) * PIXELS_PER_ENCODER_STEP
	var end_pos := center + Vector2(dx, 0.0)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = center
	down.device = -1
	vp.push_input(down, true)
	var motion := InputEventMouseMotion.new()
	motion.position = end_pos
	motion.relative = Vector2(dx, 0.0)
	motion.velocity = Vector2.ZERO
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	motion.device = -1
	vp.push_input(motion, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = end_pos
	up.device = -1
	vp.push_input(up, true)
	return true


static func orbit_yaw_steps(editor: EditorInterface, steps: int) -> bool:
	if steps == 0:
		return false
	var pivot_v: Variant = _selection_orbit_pivot(editor)
	if pivot_v != null and pivot_v is Vector3:
		if _orbit_camera_yaw_around_pivot(editor, pivot_v as Vector3, steps):
			return true
	return _orbit_yaw_via_middle_mouse_drag(editor, steps)

extends MXOptionProvider
## Editor shortcuts (spatial_editor / canvas_item_editor) and 3D camera orbit via bridge.

const ID_EDITOR_SHORTCUT := "mx.editor.shortcut"
const ID_VIEW3D_ORBIT_YAW := "mx.view3d.orbit_yaw"


func _init() -> void:
	priority = 4


func build_options(_context: Dictionary) -> Array:
	return []


func _is_3d_main_screen(main_screen: String) -> bool:
	var s := String(main_screen).strip_edges()
	if s.is_empty():
		return false
	var u := s.to_upper()
	# Internal name is English; in some locales the tab may include "3D" plus extra text.
	return u == "3D" or u.contains(" 3D") or u.ends_with("3D") or u.begins_with("3D")


func apply_event(
	event: Dictionary,
	context: Dictionary,
	editor: EditorInterface,
	_undo: EditorUndoRedoManager,
) -> bool:
	var id := str(event.get("id", ""))
	var kind := str(event.get("kind", ""))
	if id == ID_EDITOR_SHORTCUT and kind == "editor_shortcut":
		var path := str(event.get("path", ""))
		if path.is_empty():
			return false
		return MXEditorShortcutHelper.execute(editor, path)
	if id == ID_VIEW3D_ORBIT_YAW and kind == "set_int":
		if not _is_3d_main_screen(str(context.get("main_screen", ""))):
			return false
		var raw: Variant = event.get("value", 0)
		var steps := int(round(float(raw)))
		return MXEditorViewport3dHelper.orbit_yaw_steps(editor, steps)
	return false

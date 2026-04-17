class_name MXEditorShortcutHelper
extends RefCounted
## Executes an editor shortcut by reading its [Shortcut] from [EditorSettings]
## and replaying its events (same TileMap logic: user-customized bindings are respected).
##
## [code]scene_tree/attach_script[/code]: in many versions the shortcut exists but has no keys assigned;
## in that case it opens the same [ScriptCreateDialog] as the Scene dock ([method EditorPlugin.get_script_create_dialog]).


const _PATH_ATTACH_SCRIPT := "scene_tree/attach_script"


static func execute(editor: EditorInterface, editor_setting_path: String) -> bool:
	var es := editor.get_editor_settings()
	if es.has_shortcut(editor_setting_path):
		var sc: Shortcut = es.get_shortcut(editor_setting_path)
		if sc != null and not sc.events.is_empty():
			var main_screen := editor.get_editor_main_screen()
			if main_screen and main_screen.focus_mode != Control.FOCUS_NONE:
				main_screen.grab_focus()
			for ev in sc.events:
				_parse_duplicate_shortcut_event(ev)
			return true

	if editor_setting_path == _PATH_ATTACH_SCRIPT:
		return _open_attach_script_dialog(editor)

	if not es.has_shortcut(editor_setting_path):
		return false
	return false


static func _open_attach_script_dialog(editor: EditorInterface) -> bool:
	var plug := MXEditorPluginHost.instance
	if plug == null:
		return false
	var nodes := editor.get_selection().get_selected_nodes()
	if nodes.is_empty():
		return false
	var selected: Node = nodes[0]
	var path_str: String
	var scene_fp := String(selected.scene_file_path)
	if scene_fp.is_empty():
		var root := editor.get_edited_scene_root()
		var root_path := ""
		if root != null:
			root_path = String(root.scene_file_path)
		if root_path.is_empty():
			path_str = "res://".path_join(String(selected.name))
		else:
			path_str = root_path.get_base_dir().path_join(String(selected.name))
	else:
		path_str = scene_fp
	var inherits := String(selected.get_class())
	var dialog: ScriptCreateDialog = plug.get_script_create_dialog()
	# Godot 4.2: ScriptCreateDialog has no set_inheritance_base_type (only available in newer versions).
	if dialog.has_method(&"set_inheritance_base_type"):
		dialog.set_inheritance_base_type("Node")
	dialog.config(inherits, path_str)
	# The ScriptCreateDialog does not automatically attach the script when opened manually.
	# We bind a dynamic handler to attach the created script to our selected node.
	var on_created := func(s: Script) -> void:
		if is_instance_valid(selected):
			var undo := plug.get_undo_redo()
			undo.create_action("MX: Attach Script")
			undo.add_do_method(selected, "set_script", s)
			undo.add_undo_method(selected, "set_script", selected.get_script())
			undo.commit_action()
			editor.edit_resource(s)

	# Helper to clean up connections so we don't pollute the global dialog
	var helper: Array[Callable] = []
	var on_hidden := func() -> void:
		if not dialog.visible:
			if dialog.script_created.is_connected(on_created):
				dialog.script_created.disconnect(on_created)
			if dialog.visibility_changed.is_connected(helper[0]):
				dialog.visibility_changed.disconnect(helper[0])
	helper.append(on_hidden)

	dialog.script_created.connect(on_created)
	dialog.visibility_changed.connect(on_hidden)

	dialog.popup_centered()
	return true


## Opens the ScriptCreateDialog without attaching to any selected node.
## Used by mx.script.new to mimic the Script editor "New Script..." flow.
static func open_new_script_dialog(editor: EditorInterface) -> bool:
	var plug := MXEditorPluginHost.instance
	if plug == null:
		return false
	var dialog: ScriptCreateDialog = plug.get_script_create_dialog()
	var root := editor.get_edited_scene_root()
	var base_dir := "res://"
	if root != null and String(root.scene_file_path) != "":
		base_dir = String(root.scene_file_path).get_base_dir()
	var path_str := base_dir.path_join("new_script.gd")
	dialog.config("Node", path_str)
	dialog.popup_centered()
	return true


static func _parse_duplicate_shortcut_event(ev: InputEvent) -> void:
	if ev is InputEventKey:
		var ek := ev as InputEventKey
		var down := ek.duplicate() as InputEventKey
		down.pressed = true
		down.echo = false
		down.device = -1
		Input.parse_input_event(down)
		var up := ek.duplicate() as InputEventKey
		up.pressed = false
		up.echo = false
		up.device = -1
		Input.parse_input_event(up)
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		var d := mb.duplicate() as InputEventMouseButton
		d.pressed = true
		d.device = -1
		Input.parse_input_event(d)
		var u := mb.duplicate() as InputEventMouseButton
		u.pressed = false
		u.device = -1
		Input.parse_input_event(u)

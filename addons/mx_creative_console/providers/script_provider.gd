extends MXOptionProvider
## Script editor actions bridged from mx.script.* events.

const ID_NEW := "mx.script.new"
const ID_SAVE := "mx.script.save"
const ID_RUN := "mx.script.run"
const ID_CUT := "mx.script.cut"
const ID_COPY := "mx.script.copy"
const ID_PASTE := "mx.script.paste"
const ID_FIND := "mx.script.find"
const ID_SEARCH_HELP := "mx.script.search_help"

const _PATHS_SAVE := ["script_editor/save_file", "script_text_editor/save_file", "editor/save_scene"]
const _PATHS_RUN := ["script_editor/run_file"]
const _PATHS_CUT := ["script_text_editor/cut", "script_editor/cut"]
const _PATHS_COPY := ["script_text_editor/copy", "script_editor/copy"]
const _PATHS_PASTE := ["script_text_editor/paste", "script_editor/paste"]
const _PATHS_FIND := ["script_text_editor/find", "script_editor/find"]
const _PATHS_HELP := ["editor/editor_help", "script_editor/open_help"]


func _init() -> void:
	priority = 6


func build_options(_context: Dictionary) -> Array:
	return []


func apply_event(
	event: Dictionary,
	_context: Dictionary,
	editor: EditorInterface,
	_undo: EditorUndoRedoManager,
) -> bool:
	if str(event.get("kind", "")) != "trigger":
		return false
	var id := str(event.get("id", ""))
	match id:
		ID_NEW:
			return MXEditorShortcutHelper.open_new_script_dialog(editor)
		ID_SAVE:
			return _exec_first(editor, _PATHS_SAVE) or _send_ctrl_key(editor, KEY_S)
		ID_RUN:
			return _exec_first(editor, _PATHS_RUN)
		ID_CUT:
			return _exec_first(editor, _PATHS_CUT) or _send_ctrl_key(editor, KEY_X)
		ID_COPY:
			return _exec_first(editor, _PATHS_COPY) or _send_ctrl_key(editor, KEY_C)
		ID_PASTE:
			return _exec_first(editor, _PATHS_PASTE) or _send_ctrl_key(editor, KEY_V)
		ID_FIND:
			return _exec_first(editor, _PATHS_FIND)
		ID_SEARCH_HELP:
			return _exec_first(editor, _PATHS_HELP)
	return false


func _exec_first(editor: EditorInterface, paths: Array) -> bool:
	for p in paths:
		if MXEditorShortcutHelper.execute(editor, str(p)):
			return true
	return false


func _send_ctrl_key(editor: EditorInterface, keycode: Key) -> bool:
	var main_screen := editor.get_editor_main_screen()
	if main_screen and main_screen.focus_mode != Control.FOCUS_NONE:
		main_screen.grab_focus()
	var down := InputEventKey.new()
	down.pressed = true
	down.echo = false
	down.device = -1
	down.ctrl_pressed = true
	down.keycode = keycode
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.echo = false
	up.device = -1
	up.ctrl_pressed = true
	up.keycode = keycode
	Input.parse_input_event(up)
	return true

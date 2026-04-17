extends MXOptionProvider
## Debugger actions bridged from mx.debug.* events.

const ID_STEP_INTO := "mx.debug.step_into"
const ID_STEP_OVER := "mx.debug.step_over"
const ID_BREAKPOINT := "mx.debug.breakpoint"
const ID_CONTINUE := "mx.debug.continue"

const _PATHS_STEP_INTO := ["debugger/step_into", "script_editor/debug_step_into"]
const _PATHS_STEP_OVER := ["debugger/step_over", "script_editor/debug_step_over"]
const _PATHS_BREAKPOINT := ["script_text_editor/toggle_breakpoint", "script_editor/toggle_breakpoint"]
const _PATHS_CONTINUE := ["debugger/continue", "debugger/next", "script_editor/debug_continue"]


func _init() -> void:
	priority = 7


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
		ID_STEP_INTO:
			return _exec_first(editor, _PATHS_STEP_INTO)
		ID_STEP_OVER:
			return _exec_first(editor, _PATHS_STEP_OVER)
		ID_BREAKPOINT:
			return _exec_first(editor, _PATHS_BREAKPOINT)
		ID_CONTINUE:
			return _exec_first(editor, _PATHS_CONTINUE)
	return false


func _exec_first(editor: EditorInterface, paths: Array) -> bool:
	for p in paths:
		if MXEditorShortcutHelper.execute(editor, str(p)):
			return true
	return false

class_name MXOptionProvider
extends RefCounted
## Extend this class and register an instance on MXContextBus.
## Higher `priority` wins when merging options with the same `id`.

var priority: int = 0


## Return an array of option dictionaries (use MXOption.* builders).
func build_options(_context: Dictionary) -> Array:
	return []


## Return true if this provider handled the event (e.g. applied a property with undo).
## `event` shape: { "id": String, "kind": "set_bool"|"set_float"|"set_int"|"set_choice"|"trigger", "value": Variant }
func apply_event(
	_event: Dictionary,
	_context: Dictionary,
	_editor: EditorInterface,
	_undo: EditorUndoRedoManager,
) -> bool:
	return false

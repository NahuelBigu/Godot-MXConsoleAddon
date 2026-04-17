extends MXOptionProvider
## Scene dock toolbar: add node, instantiate child scene, attach script ([code]scene_tree/*[/code] shortcuts).

const ID_ADD_CHILD := "mx.scene_tree.add_child_node"
const ID_INSTANTIATE := "mx.scene_tree.instantiate_scene"
const ID_ATTACH_SCRIPT := "mx.scene_tree.attach_script"

const G_SCENE := "Scene tree"


func _init() -> void:
	priority = 12


func build_options(_context: Dictionary) -> Array:
	return [
		MXOption.trigger(ID_ADD_CHILD, "Add child node", G_SCENE),
		MXOption.trigger(ID_INSTANTIATE, "Instantiate child scene", G_SCENE),
		MXOption.trigger(ID_ATTACH_SCRIPT, "Attach script", G_SCENE),
	]


func apply_event(
	event: Dictionary,
	_context: Dictionary,
	editor: EditorInterface,
	_undo: EditorUndoRedoManager,
) -> bool:
	if str(event.get("kind", "")) != "trigger":
		return false
	var shortcut_path := ""
	match str(event.get("id", "")):
		ID_ADD_CHILD:
			shortcut_path = "scene_tree/add_child_node"
		ID_INSTANTIATE:
			shortcut_path = "scene_tree/instantiate_scene"
		ID_ATTACH_SCRIPT:
			shortcut_path = "scene_tree/attach_script"
		_:
			return false
	return MXEditorShortcutHelper.execute(editor, shortcut_path)

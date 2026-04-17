class_name MXEditorRunHelper
extends RefCounted
## Pause/resume the running project like the editor command [code]editor/pause_scene[/code] (default F7).
## Uses [method EditorSettings.get_shortcut] so user remaps in Editor → Editor Settings → Shortcuts apply.
## Fallback: Run Bar pause toggle button, then legacy F7 simulation.


## Official action id: see [url=https://docs.godotengine.org/en/stable/tutorials/editor/default_key_mapping.html]Default editor shortcuts[/url].
const PAUSE_SCENE_ACTION := "editor/pause_scene"


static func get_runtime_paused(editor: EditorInterface) -> bool:
	var b := _find_editor_pause_button(editor)
	if b != null:
		return b.button_pressed
	return false


static func set_runtime_paused(editor: EditorInterface, paused: bool) -> void:
	if get_runtime_paused(editor) == paused:
		return
	if _trigger_pause_scene_action(editor):
		return
	var b := _find_editor_pause_button(editor)
	if b != null and not b.disabled:
		b.button_pressed = paused
		return
	_simulate_shortcut(KEY_F7)


## Runs the configured shortcut for [constant PAUSE_SCENE_ACTION] (toggle once).
static func _trigger_pause_scene_action(editor: EditorInterface) -> bool:
	var es := editor.get_editor_settings()
	if es == null:
		return false
	var sc: Variant = es.get_shortcut(PAUSE_SCENE_ACTION)
	if sc == null or not sc is Shortcut:
		return false
	var shortcut := sc as Shortcut
	if not shortcut.has_valid_event():
		return false
	var vp := editor.get_base_control().get_viewport()
	for ev in shortcut.events:
		if ev is InputEvent:
			_push_shortcut_event_to_viewport(vp, ev as InputEvent)
	return true


static func _push_shortcut_event_to_viewport(vp: Viewport, template: InputEvent) -> void:
	if template is InputEventKey:
		var k := template as InputEventKey
		var down := k.duplicate() as InputEventKey
		down.pressed = true
		down.echo = false
		vp.push_input(down)
		var up := k.duplicate() as InputEventKey
		up.pressed = false
		up.echo = false
		vp.push_input(up)
	elif template is InputEventMouseButton:
		var m := template as InputEventMouseButton
		var down_m := m.duplicate() as InputEventMouseButton
		down_m.pressed = true
		vp.push_input(down_m)
		var up_m := m.duplicate() as InputEventMouseButton
		up_m.pressed = false
		vp.push_input(up_m)
	else:
		var dup := template.duplicate() as InputEvent
		if dup != null:
			vp.push_input(dup)


## Last-resort key simulation (may not match user shortcut remap).
static func _simulate_shortcut(keycode: Key, ctrl := false, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	Input.parse_input_event(up)


static func _find_editor_pause_button(editor: EditorInterface) -> Button:
	var root := editor.get_base_control()
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b == null or not b.toggle_mode:
			continue
		var tt := String(b.tooltip_text).to_lower()
		if tt.contains("pause") or tt.contains("pausa") or tt.contains("pausar"):
			return b
	return null

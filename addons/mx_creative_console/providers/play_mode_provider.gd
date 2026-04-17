extends MXOptionProvider
## Runtime / Game tab: pause (Run Bar), [member Engine.time_scale] dial, stop & restart, play when idle.
## Note: [member Engine.time_scale] from the editor plugin affects the same process as an embedded run; with a separate
## game window it may not reach the game - use the Game tab speed control in that case.

const ID_PAUSE := "mx.runtime.pause"
const ID_TIME_SCALE := "mx.runtime.time_scale"
const ID_STOP := "mx.runtime.stop"
const ID_RESTART := "mx.runtime.restart"
const ID_PLAY_CURRENT := "mx.runtime.play_current"
const ID_PLAY_MAIN := "mx.runtime.play_main"
const ID_FOCUS_GAME := "mx.runtime.focus_game_tab"
const ID_FOCUS_2D := "mx.runtime.focus_2d_tab"
const ID_FOCUS_3D := "mx.runtime.focus_3d_tab"
const ID_FOCUS_SCRIPT := "mx.runtime.focus_script_tab"
const ID_RESET_TIME_SCALE := "mx.runtime.reset_time_scale"

const G_PLAY := "Runtime"
const G_IDLE := "Game tab"


func _init() -> void:
	priority = 20


func _is_game_tab(ms: String) -> bool:
	return ms == "Game" or ms == "Juego"


func build_options(context: Dictionary) -> Array:
	var out: Array = []
	var playing: bool = context.get("is_playing", false)
	var ms := str(context.get("main_screen", ""))
	if playing:
		out.append(
			MXOption.toggle(
				ID_PAUSE,
				"Pause (Run Bar)",
				bool(context.get("runtime_paused", false)),
				G_PLAY,
			)
		)
		out.append(
			MXOption.range_option(
				ID_TIME_SCALE,
				"Time scale (embedded run; separate window → use Juego tab)",
				0.05,
				4.0,
				0.05,
				float(context.get("engine_time_scale", 1.0)),
				G_PLAY,
			)
		)
		out.append(MXOption.trigger(ID_STOP, "Stop game", G_PLAY))
		out.append(MXOption.trigger(ID_RESTART, "Restart current scene", G_PLAY))
		out.append(MXOption.trigger(ID_RESET_TIME_SCALE, "Reset time scale (1×)", G_PLAY))
	else:
		if _is_game_tab(ms):
			out.append(MXOption.trigger(ID_PLAY_CURRENT, "Run current scene", G_IDLE))
			out.append(MXOption.trigger(ID_PLAY_MAIN, "Run main scene", G_IDLE))
		var g_tab := G_IDLE if not playing else G_PLAY
		out.append(MXOption.trigger(ID_FOCUS_GAME, "Open Game tab", g_tab))
		out.append(MXOption.trigger(ID_FOCUS_2D, "Open 2D tab", g_tab))
		out.append(MXOption.trigger(ID_FOCUS_3D, "Open 3D tab", g_tab))
		out.append(MXOption.trigger(ID_FOCUS_SCRIPT, "Open Script tab", g_tab))
	return out


func apply_event(
	event: Dictionary,
	_context: Dictionary,
	editor: EditorInterface,
	_undo: EditorUndoRedoManager,
) -> bool:
	var id := str(event.get("id", ""))
	var kind := str(event.get("kind", ""))
	match id:
		ID_PAUSE:
			if kind == "set_bool":
				MXEditorRunHelper.set_runtime_paused(editor, bool(event.get("value", false)))
				return true
		ID_TIME_SCALE:
			if kind == "set_float":
				var v: float = clampf(float(event.get("value", 1.0)), 0.05, 16.0)
				Engine.time_scale = v
				return true
		ID_STOP:
			if kind == "trigger":
				editor.stop_playing_scene()
				return true
		ID_RESTART:
			if kind == "trigger":
				editor.play_current_scene()
				return true
		ID_RESET_TIME_SCALE:
			if kind == "trigger":
				Engine.time_scale = 1.0
				return true
		ID_PLAY_CURRENT:
			if kind == "trigger":
				editor.play_current_scene()
				return true
		ID_PLAY_MAIN:
			if kind == "trigger":
				editor.play_main_scene()
				return true
		ID_FOCUS_GAME:
			if kind == "trigger":
				_focus_game_tab(editor)
				return true
		ID_FOCUS_2D:
			if kind == "trigger":
				editor.set_main_screen_editor("2D")
				return true
		ID_FOCUS_3D:
			if kind == "trigger":
				editor.set_main_screen_editor("3D")
				return true
		ID_FOCUS_SCRIPT:
			if kind == "trigger":
				_focus_script_tab(editor)
				return true
	return false


func _editor_language_lower(editor: EditorInterface) -> String:
	var es := editor.get_editor_settings()
	if es and es.has_setting("interface/editor/localization/editor_language"):
		return str(es.get_setting("interface/editor/localization/editor_language")).to_lower()
	return "en"


func _focus_game_tab(editor: EditorInterface) -> void:
	## Tab caption matches Editor Settings → Interface → Editor language (not OS locale).
	var lang := _editor_language_lower(editor)
	var tab := "Juego" if lang.begins_with("es") else "Game"
	editor.set_main_screen_editor(tab)


func _focus_script_tab(editor: EditorInterface) -> void:
	var lang := _editor_language_lower(editor)
	var tab := "Código" if lang.begins_with("es") else "Script"
	editor.set_main_screen_editor(tab)

@tool
extends Control

signal default_action_pressed
signal node3d_action_pressed
## Emulates a bridge hardware event (same shape as [code]events.json[/code] entries).
signal mx_hardware_event_emulated(event: Dictionary)

const _TM_IDS: PackedStringArray = [
	"mx.tilemap.tool_paint",
	"mx.tilemap.tool_line",
	"mx.tilemap.tool_rect",
	"mx.tilemap.tool_bucket",
	"mx.tilemap.tool_picker",
	"mx.tilemap.tool_eraser",
	"mx.tilemap.toggle_random_tile",
	"mx.tilemap.rotate_left",
	"mx.tilemap.rotate_right",
	"mx.tilemap.flip_h",
	"mx.tilemap.flip_v",
	"mx.tilemap.prev_layer",
	"mx.tilemap.next_layer",
]

## Maps [param tilemap_snapshot.active_tool] → trigger id for toggle highlight.
const _ACTIVE_TOOL_TO_ID := {
	"paint": "mx.tilemap.tool_paint",
	"line": "mx.tilemap.tool_line",
	"rect": "mx.tilemap.tool_rect",
	"bucket": "mx.tilemap.tool_bucket",
	"picker": "mx.tilemap.tool_picker",
	"eraser": "mx.tilemap.tool_eraser",
	"select": "",
	"unknown": "",
}

const _BTN_LABELS := {
	"mx.tilemap.tool_paint": "Paint",
	"mx.tilemap.tool_line": "Line",
	"mx.tilemap.tool_rect": "Rect",
	"mx.tilemap.tool_bucket": "Bucket",
	"mx.tilemap.tool_picker": "Picker",
	"mx.tilemap.tool_eraser": "Eraser",
	"mx.tilemap.toggle_random_tile": "Random tile",
	"mx.tilemap.rotate_left": "Rotate left",
	"mx.tilemap.rotate_right": "Rotate right",
	"mx.tilemap.flip_h": "Flip H",
	"mx.tilemap.flip_v": "Flip V",
	"mx.tilemap.prev_layer": "Prev layer",
	"mx.tilemap.next_layer": "Next layer",
}

## Same [EditorIcons] names as [code]tile_map_layer_editor.cpp[/code] (Godot 4.x).
const _TM_ICON_NAMES := {
	"mx.tilemap.tool_paint": "Edit",
	"mx.tilemap.tool_line": "Line",
	"mx.tilemap.tool_rect": "Rectangle",
	"mx.tilemap.tool_bucket": "Bucket",
	"mx.tilemap.tool_picker": "ColorPick",
	"mx.tilemap.tool_eraser": "Eraser",
	"mx.tilemap.toggle_random_tile": "RandomNumberGenerator",
	"mx.tilemap.rotate_left": "RotateLeft",
	"mx.tilemap.rotate_right": "RotateRight",
	"mx.tilemap.flip_h": "MirrorX",
	"mx.tilemap.flip_v": "MirrorY",
	"mx.tilemap.prev_layer": "MoveUp",
	"mx.tilemap.next_layer": "MoveDown",
}

const _EDITOR_ICONS := &"EditorIcons"

var _editor_interface: EditorInterface

@onready var _status: Label = $Margin/VBox/Status
@onready var _btn_default: Button = $Margin/VBox/DefaultAction
@onready var _btn_3d: Button = $Margin/VBox/Node3DAction

var _tilemap_strip: VBoxContainer
var _tilemap_layer_lbl: Label
var _tilemap_grid: GridContainer
var _tilemap_btns: Dictionary = {}


func _ready() -> void:
	_btn_default.pressed.connect(_on_default_pressed)
	_btn_3d.pressed.connect(_on_3d_pressed)


func _on_default_pressed() -> void:
	default_action_pressed.emit()


func _on_3d_pressed() -> void:
	node3d_action_pressed.emit()


func set_editor_interface(ei: EditorInterface) -> void:
	_editor_interface = ei
	if _tilemap_grid != null:
		_apply_tilemap_button_icons()


func _tilemap_button_min_size() -> Vector2:
	var ed_scale := 1.0
	if _editor_interface:
		ed_scale = _editor_interface.get_editor_scale()
	var px := int(round(28.0 * ed_scale))
	return Vector2(px, px)


func _apply_tilemap_button_icons() -> void:
	var th: Theme = null
	if _editor_interface:
		th = _editor_interface.get_editor_theme()
	var min_sz := _tilemap_button_min_size()
	for ev_id in _TM_IDS:
		var btn: Variant = _tilemap_btns.get(ev_id, null)
		if not (btn is Button):
			continue
		var b := btn as Button
		var label := str(_BTN_LABELS.get(ev_id, ev_id))
		b.tooltip_text = label
		b.flat = true
		b.expand_icon = true
		b.custom_minimum_size = min_sz
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var inm: String = str(_TM_ICON_NAMES.get(ev_id, ""))
		if th != null and not inm.is_empty() and th.has_icon(inm, _EDITOR_ICONS):
			b.icon = th.get_icon(inm, _EDITOR_ICONS)
			b.text = ""
		else:
			b.icon = null
			b.text = label


func _ensure_tilemap_strip() -> void:
	if _tilemap_strip != null:
		return
	var vbox: VBoxContainer = $Margin/VBox
	var insert_at := vbox.get_child_count() - 2
	_tilemap_strip = VBoxContainer.new()
	_tilemap_strip.name = "TileMapStrip"
	_tilemap_strip.visible = false
	var title := Label.new()
	title.text = "TileMap editor (shortcuts)"
	_tilemap_strip.add_child(title)
	_tilemap_layer_lbl = Label.new()
	_tilemap_layer_lbl.name = "TileMapLayerInfo"
	_tilemap_strip.add_child(_tilemap_layer_lbl)
	_tilemap_grid = GridContainer.new()
	_tilemap_grid.name = "TileMapGrid"
	_tilemap_grid.columns = 3
	_tilemap_grid.add_theme_constant_override("h_separation", 6)
	_tilemap_grid.add_theme_constant_override("v_separation", 6)
	_tilemap_strip.add_child(_tilemap_grid)
	for ev_id in _TM_IDS:
		var b := Button.new()
		b.text = str(_BTN_LABELS.get(ev_id, ev_id))
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.set_meta("mx_event_id", ev_id)
		b.pressed.connect(_on_tilemap_btn_pressed.bind(ev_id))
		_tilemap_grid.add_child(b)
		_tilemap_btns[ev_id] = b
	_apply_tilemap_button_icons()
	vbox.add_child(_tilemap_strip)
	vbox.move_child(_tilemap_strip, maxi(0, insert_at))


func _on_tilemap_btn_pressed(ev_id: String) -> void:
	mx_hardware_event_emulated.emit({"id": ev_id, "kind": "trigger"})


func _update_tilemap_tool_highlights(active_tool: String) -> void:
	var active_id: String = str(_ACTIVE_TOOL_TO_ID.get(active_tool, ""))
	for ev_id in _TM_IDS:
		var btn: Variant = _tilemap_btns.get(ev_id, null)
		if not (btn is Button):
			continue
		var b := btn as Button
		var is_paint_tool := ev_id.begins_with("mx.tilemap.tool_")
		if is_paint_tool and ev_id == active_id and not active_id.is_empty():
			b.modulate = Color(0.65, 0.85, 1.0, 1.0)
		else:
			b.modulate = Color.WHITE


func apply_snapshot(context: Dictionary, options: Array) -> void:
	if not is_node_ready():
		await ready
	var has_tf: bool = bool(context.get("has_node3d", false)) or bool(context.get("has_node2d", false))
	_btn_3d.visible = has_tf
	var scene_path := str(context.get("scene_path", ""))
	var main_scr := str(context.get("main_screen", ""))
	var lines := "Main screen: %s\n" % (main_scr if main_scr != "" else "(unknown — switch 2D/3D/Script/… once)")
	if bool(context.get("is_playing", false)):
		lines += "Playing: %s\n" % str(context.get("playing_scene", "(running)"))
		var ts_g := float(context.get("engine_time_scale", 1.0))
		var ts_e := float(context.get("runtime_time_scale_effective", ts_g))
		lines += "Run-bar pause: %s\n" % str(context.get("runtime_paused", false))
		if is_equal_approx(ts_g, ts_e):
			lines += "time_scale (Engine): %s\n" % str(ts_g)
		else:
			lines += "time_scale (Engine): %s | effective (incl. Juego tab): %s\n" % [str(ts_g), str(ts_e)]
	var lines_scene := "Scene: %s\n" % scene_path if scene_path != "" else "Scene: (unsaved or empty)\n"
	lines += lines_scene
	var paths: Variant = context.get("selected_paths", [])
	if typeof(paths) == TYPE_PACKED_STRING_ARRAY:
		if paths.size() == 0:
			lines += "Selection: (empty)\n"
		else:
			lines += "Selection:\n- " + "\n- ".join(paths) + "\n"
	elif paths is Array:
		if paths.is_empty():
			lines += "Selection: (empty)\n"
		else:
			var ps: PackedStringArray = []
			for p in paths:
				ps.append(str(p))
			lines += "Selection:\n- " + "\n- ".join(ps) + "\n"
	else:
		lines += "Selection: (empty)\n"

	if bool(context.get("has_tilemap", false)):
		_ensure_tilemap_strip()
		_tilemap_strip.visible = true
		var tm: Variant = context.get("tilemap_snapshot", null)
		if typeof(tm) == TYPE_DICTIONARY:
			var d: Dictionary = tm
			var li := int(d.get("current_layer", 0))
			var lc := int(d.get("layer_count", 0))
			var lnames: Variant = d.get("layer_names", [])
			var lname := ""
			if lnames is Array and li >= 0 and li < (lnames as Array).size():
				lname = str((lnames as Array)[li])
			var tool := str(d.get("active_tool", "unknown"))
			_tilemap_layer_lbl.text = "Layer %d / %d — %s | Tool: %s" % [li + 1, maxi(lc, 1), lname, tool]
			_update_tilemap_tool_highlights(tool)
		else:
			_tilemap_layer_lbl.text = "TileMap (no snapshot)"
			_update_tilemap_tool_highlights("unknown")
		lines += "\nTileMap: active (see toolbar above)\n"
	else:
		if _tilemap_strip != null:
			_tilemap_strip.visible = false

	lines += "\nOptions (%d):\n" % options.size()
	for o in options:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var t := str(o.get("type", "?"))
		var lb := str(o.get("label", o.get("id", "")))
		var gr := str(o.get("group", ""))
		var suffix := " [%s]" % gr if gr != "" else ""
		match t:
			"toggle":
				lines += "  • [toggle] %s%s = %s\n" % [lb, suffix, str(o.get("value", false))]
			"range":
				lines += "  • [range] %s%s = %s\n" % [lb, suffix, str(o.get("value", 0.0))]
			"choice":
				lines += "  • [choice] %s%s (idx %s)\n" % [lb, suffix, str(o.get("index", 0))]
			"trigger":
				lines += "  • [trigger] %s%s\n" % [lb, suffix]
			_:
				lines += "  • [%s] %s\n" % [t, lb]
	lines += "\nBridge: context.json + events.json (see MXBridge)."
	_status.text = lines

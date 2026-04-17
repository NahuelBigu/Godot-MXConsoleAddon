extends MXOptionProvider
class_name MXTileMapProvider
## TileMap / TileMapLayer: executes editor actions using only
## **Editor → Editor Settings → Shortcuts** paths (the docs' *Editor setting* column).
##
## TileMap editor (bottom panel): [url]https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html#opening-the-tilemap-editor[/url]
##
## Reference: https://docs.godotengine.org/en/stable/tutorials/editor/default_key_mapping.html#tilemap-editor
##
## | Action name | Editor setting |
## | Select | tiles_editor/selection_tool |
## | Cut Selection | tiles_editor/cut |
## | Copy Selection | tiles_editor/copy |
## | Paste Selection | tiles_editor/paste |
## | Delete Selection | tiles_editor/delete |
## | Cancel | tiles_editor/cancel |
## | Paint | tiles_editor/paint_tool |
## | Line | tiles_editor/line_tool |
## | Rect | tiles_editor/rect_tool |
## | Bucket | tiles_editor/bucket_tool |
## | Picker | tiles_editor/picker |
## | Eraser | tiles_editor/eraser |
## | Flip Horizontally | tiles_editor/flip_tile_horizontal |
## | Flip Vertically | tiles_editor/flip_tile_vertical |
## | Rotate Left | tiles_editor/rotate_tile_left |
## | Rotate Right | tiles_editor/rotate_tile_right |
##
## Previous/next layer: same editor shortcuts, but not listed in that manual table;
## the engine registers them as [code]tiles_editor/select_previous_layer[/code] and
## [code]tiles_editor/select_next_layer[/code] (default PgUp / PgDown).

const GRP := "TileMap"

## Same constant as [MXEditorSnapStateHelper]: editor icons used to compare with [member Button.icon].
const _ED_ICONS := &"EditorIcons"

const ID_SELECT := "mx.tilemap.tool_select"
const ID_PAINT := "mx.tilemap.tool_paint"
const ID_LINE := "mx.tilemap.tool_line"
const ID_RECT := "mx.tilemap.tool_rect"
const ID_BUCKET := "mx.tilemap.tool_bucket"
const ID_PICKER := "mx.tilemap.tool_picker"
const ID_ERASER := "mx.tilemap.tool_eraser"
## There is no tiles_editor/* shortcut; toggles the "Place Random Tile" button (theme RandomNumberGenerator icon).
const ID_TOGGLE_RANDOM_TILE := "mx.tilemap.toggle_random_tile"
const ID_ROTATE := "mx.tilemap.rotate"
const ID_ROT_L := "mx.tilemap.rotate_left"
const ID_ROT_R := "mx.tilemap.rotate_right"
const ID_FLIP_H := "mx.tilemap.flip_h"
const ID_FLIP_V := "mx.tilemap.flip_v"
const ID_PREV_LAYER := "mx.tilemap.prev_layer"
const ID_NEXT_LAYER := "mx.tilemap.next_layer"
const ID_TILE_SCROLL := "mx.tilemap.tile_scroll"
const ID_RANDOM_SCATTER := "mx.tilemap.random_scatter"

## Doc: Select
const ES_TILEMAP_SELECTION_TOOL := "tiles_editor/selection_tool"
## Docs: Cut / Copy / Paste / Delete / Cancel (exposed in case they are later wired into the bridge)
const ES_TILEMAP_CUT := "tiles_editor/cut"
const ES_TILEMAP_COPY := "tiles_editor/copy"
const ES_TILEMAP_PASTE := "tiles_editor/paste"
const ES_TILEMAP_DELETE := "tiles_editor/delete"
const ES_TILEMAP_CANCEL := "tiles_editor/cancel"
## Doc: Paint … Rotate Right
const ES_TILEMAP_PAINT_TOOL := "tiles_editor/paint_tool"
const ES_TILEMAP_LINE_TOOL := "tiles_editor/line_tool"
const ES_TILEMAP_RECT_TOOL := "tiles_editor/rect_tool"
const ES_TILEMAP_BUCKET_TOOL := "tiles_editor/bucket_tool"
const ES_TILEMAP_PICKER := "tiles_editor/picker"
const ES_TILEMAP_ERASER := "tiles_editor/eraser"
const ES_TILEMAP_FLIP_TILE_HORIZONTAL := "tiles_editor/flip_tile_horizontal"
const ES_TILEMAP_FLIP_TILE_VERTICAL := "tiles_editor/flip_tile_vertical"
const ES_TILEMAP_ROTATE_TILE_LEFT := "tiles_editor/rotate_tile_left"
const ES_TILEMAP_ROTATE_TILE_RIGHT := "tiles_editor/rotate_tile_right"
## Engine-level (editor shortcuts); not in the TileMap table from the manual linked above.
const ES_TILEMAP_SELECT_PREVIOUS_LAYER := "tiles_editor/select_previous_layer"
const ES_TILEMAP_SELECT_NEXT_LAYER := "tiles_editor/select_next_layer"

## Toolbar sync: same dictionary as the docs' *Editor setting* column.
const _TOOL_TO_SHORTCUT := {
	"select": ES_TILEMAP_SELECTION_TOOL,
	"paint": ES_TILEMAP_PAINT_TOOL,
	"line": ES_TILEMAP_LINE_TOOL,
	"rect": ES_TILEMAP_RECT_TOOL,
	"bucket": ES_TILEMAP_BUCKET_TOOL,
	"picker": ES_TILEMAP_PICKER,
	"eraser": ES_TILEMAP_ERASER,
}

## Names in [code]EditorIcons[/code] (editor TileMap toolbar; more reliable than [Shortcut] on the button).
## [code]ToolSelect[/code] = exclusive "Selection" tool ([code]tiles_editor/selection_tool[/code]).
const _TM_TOOLBAR_ICONS := {
	"select": "ToolSelect",
	"paint": "Edit",
	"line": "Line",
	"rect": "Rectangle",
	"bucket": "Bucket",
	"picker": "ColorPick",
	"eraser": "Eraser",
}

## Exclusive tool order (only one pressed in the native [ButtonGroup]).
const _TM_EXCLUSIVE_TOOLS := ["select", "paint", "line", "rect", "bucket"]

## Single [code]print[/code] in console when toolbar signature changes (state of all buttons).
const MX_LOG_TILEMAP_TOOLBAR_CHANGES := true

## Last logged signature (avoids spam; message includes all flags in one line).
static var _tm_last_toolbar_log_sig: String = ""


func _init() -> void:
	priority = 18


## Layer for snapshot/poll: selection first; if there is no selected [TileMapLayer] in 2D, use first layer in opened scene.
static func resolve_tilemap_layer(editor: EditorInterface, selected_nodes: Array) -> TileMapLayer:
	var layer := _first_tilemap_layer(selected_nodes)
	if layer != null:
		return layer
	return _first_tilemap_layer_in_edited_scene(editor)


static func _first_tilemap_layer_in_edited_scene(editor: EditorInterface) -> TileMapLayer:
	var root := editor.get_edited_scene_root()
	if root == null:
		return null
	return _find_first_tilemap_layer_depth_first(root)


static func _find_first_tilemap_layer_depth_first(n: Node) -> TileMapLayer:
	if n is TileMapLayer:
		return n
	if n is TileMap:
		var layers := _collect_tilemap_layers(n as TileMap)
		if not layers.is_empty():
			return layers[0]
	# include_internal=true to cover internal children (e.g. TileMapLayer under legacy TileMap).
	for c in n.get_children(true):
		var f := _find_first_tilemap_layer_depth_first(c)
		if f != null:
			return f
	return null


## Merge into [MXContextBus] [code]build_context[/code] return value.
static func extend_context(editor: EditorInterface, main_screen: String, selected_nodes: Array, full_ui_poll: bool = true) -> Dictionary:
	if not screen_allows_tilemap(main_screen):
		return {"has_tilemap": false, "tilemap_snapshot": null}
	var layer := resolve_tilemap_layer(editor, selected_nodes)
	if layer == null:
		return {"has_tilemap": false, "tilemap_snapshot": null}
	var snap = null
	if full_ui_poll:
		snap = _build_snapshot(layer, editor)
	return {
		"has_tilemap": true,
		"tilemap_snapshot": snap,
	}


static func screen_allows_tilemap(main_screen: String) -> bool:
	var s := main_screen.strip_edges()
	if s.is_empty():
		return true
	var sl := s.to_lower()
	if sl.contains("script") or sl.contains("código"):
		return false
	if sl == "game" or sl.contains("juego"):
		return false
	## Pure 3D viewport (English/localized name usually contains "3d" without "2d").
	if sl.contains("3d") and not sl.contains("2d"):
		return false
	## Do not require a "2d" substring: in translations the tab may not contain it and TileMap context disappears.
	return true


static func _first_tilemap_layer(nodes: Array) -> TileMapLayer:
	for n in nodes:
		if n is TileMapLayer:
			return n
		if n is TileMap:
			var layers := _collect_tilemap_layers(n as TileMap)
			if not layers.is_empty():
				return layers[0]
	return null


static func _collect_tilemap_layers(tm: TileMap) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	# include_internal=true: in Godot 4.2+ TileMapLayer nodes are internal children of legacy TileMap.
	for c in tm.get_children(true):
		if c is TileMapLayer:
			out.append(c as TileMapLayer)
	return out



static func _build_snapshot(layer: TileMapLayer, editor: EditorInterface) -> Dictionary:
	var parent := layer.get_parent()
	var layers: Array[TileMapLayer] = []
	if parent:
		for c in parent.get_children():
			if c is TileMapLayer:
				layers.append(c)
	var idx := layers.find(layer)
	if idx < 0:
		idx = 0
	var names: Array = []
	for L in layers:
		names.append(L.name)
	var meta: Dictionary = _tilemap_toolbar_state_with_meta(editor)
	var toolbar: Dictionary = meta["toolbar"] as Dictionary
	var active := _derive_exclusive_tool_from_toolbar(toolbar)
	if active == "unknown":
		active = _detect_active_tool_via_shortcuts(editor)
	var scatter: float = _read_random_scatter_value(editor)
	_log_tilemap_toolbar_if_changed(
		toolbar, active, scatter, meta.get("bar") as Node, bool(meta.get("used_native", false)))

	return {
		"path": str(layer.get_path()),
		"tilemap_path": str(parent.get_path()) if parent else "",
		"current_layer": idx,
		"layer_count": layers.size(),
		"layer_names": names,
		"active_tool": active,
		"toolbar": toolbar,
		"random_scatter": scatter,
	}


## TileMap toolbar in bottom panel: engine assigns icons via
## [code]tiles_bottom_panel->get_editor_theme_icon()[/code], which **does not** match by reference with
## [code]EditorInterface.get_editor_theme().get_icon()[/code]. Smart Snap relies on [code]icon == want[/code];
## here we read the native hierarchy (see [code]tile_map_layer_editor.cpp[/code]): one [code]HBox[/code] with
## 5 toggles (Tiles) or 4 (Terrains) in a single [ButtonGroup], plus [code]tools_settings[/code] with picker/eraser/random.
static func _tilemap_toolbar_state(editor: EditorInterface) -> Dictionary:
	return _tilemap_toolbar_state_with_meta(editor)["toolbar"] as Dictionary


static func _tilemap_toolbar_state_with_meta(editor: EditorInterface) -> Dictionary:
	var es := editor.get_editor_settings()
	var out := {}
	for tool_key in _TOOL_TO_SHORTCUT.keys():
		out[tool_key] = false
	out["random_tile"] = false
	var bar: Node = _tilemap_toolbar_bar_container(editor)
	if bar != null:
		_tm_apply_native_toolbar_snapshot(out, bar, es, editor)
		return {"toolbar": out, "bar": bar, "used_native": true}
	_tm_apply_toolbar_fallback_icons_and_shortcuts(editor, es, out)
	return {"toolbar": out, "bar": null, "used_native": false}


static func _log_tilemap_toolbar_if_changed(
	toolbar: Dictionary, active: String, scatter: float, bar: Node, used_native: bool,
) -> void:
	if not MX_LOG_TILEMAP_TOOLBAR_CHANGES:
		return
	var keys := ["select", "paint", "line", "rect", "bucket", "picker", "eraser", "random_tile"]
	var seg: PackedStringArray = PackedStringArray()
	for k in keys:
		seg.append("%s=%d" % [k, 1 if bool(toolbar.get(k, false)) else 0])
	var sig := "|".join(seg) + "|active=%s|scatter=%.5f" % [active, scatter]
	if sig == _tm_last_toolbar_log_sig:
		return
	_tm_last_toolbar_log_sig = sig
	var src := "native_ui" if used_native else "fallback_icons"
	var bar_p := str(bar.get_path()) if bar != null else "<no_bar>"


static func _tm_apply_native_toolbar_snapshot(out: Dictionary, bar: Node, es: EditorSettings, editor: EditorInterface) -> void:
	var row: Node = bar.get_child(0)
	var ntools: int = row.get_child_count() if row != null else 0
	var settings_diag: Node = bar.get_child(1) if bar.get_child_count() > 1 else null
	# Exclusive tools: recursive ButtonGroup search over the full bar (handles any nesting depth)
	_tm_apply_exclusive_tools_from_bar(out, bar)
	# Settings (picker/eraser/random_tile): search the full bar by icon/shortcut
	_tm_apply_tools_settings_row(out, bar, es, editor)


## Dumps node tree for diagnostics (limited depth).
static func _tm_dump_node_tree(n: Node, indent: String, depth: int, max_depth: int) -> void:
	if n == null or depth > max_depth:
		return
	var info := ""
	if n is BaseButton:
		var b := n as BaseButton
		info = " [toggle=%s pressed=%s sc=%s icon=%s]" \
			% [str(b.toggle_mode), str(b.button_pressed),
			   str(b.shortcut != null), str(b.icon != null)]
	for c in n.get_children():
		_tm_dump_node_tree(c, indent + "  ", depth + 1, max_depth)


## Recursive search: finds the ButtonGroup with 4 or 5 members at any level under bar.
## Replaces the version that only descended one level and failed when buttons were more deeply nested.
static func _tm_apply_exclusive_tools_from_bar(out: Dictionary, bar: Node) -> void:
	out["select"] = false
	out["paint"] = false
	out["line"] = false
	out["rect"] = false
	out["bucket"] = false

	var all_btns: Array[BaseButton] = []
	_tm_collect_base_buttons_depth_first(bar, all_btns)

	var found_grp: ButtonGroup = null
	for b in all_btns:
		if b.button_group == null:
			continue
		var gb = b.button_group.get_buttons()
		if gb.size() == 4 or gb.size() == 5:
			found_grp = b.button_group
			break

	if found_grp == null:
		return

	var grp_btns = found_grp.get_buttons()
	var nbtn: int = grp_btns.size()
	var pressed = found_grp.get_pressed_button()
	var idx := -1
	if pressed != null:
		for i in nbtn:
			if grp_btns[i] == pressed:
				idx = i
				break
	if idx < 0:
		for i in nbtn:
			if grp_btns[i].button_pressed:
				idx = i
				break

	if idx < 0:
		return

	if nbtn == 5:
		match idx:
			0:
				out["select"] = true
			1:
				out["paint"] = true
			2:
				out["line"] = true
			3:
				out["rect"] = true
			4:
				out["bucket"] = true
	else:
		match idx:
			0:
				out["paint"] = true
			1:
				out["line"] = true
			2:
				out["rect"] = true
			3:
				out["bucket"] = true


## The engine uses [ButtonGroup]; in some builds [member BaseButton.button_pressed] does not reliably reflect exclusivity.
## In Godot 4.x the dock may wrap buttons in an extra container: row -> wrapper -> [btns],
## so we descend one more level when direct children are not [BaseButton].
static func _tm_apply_exclusive_tools_from_tool_row(out: Dictionary, row: Node, ntools: int) -> void:
	out["select"] = false
	out["paint"] = false
	out["line"] = false
	out["rect"] = false
	out["bucket"] = false

	# Collect BaseButton direct children from row (allows separators/labels between buttons).
	var btns: Array[BaseButton] = []
	for i in ntools:
		var ch: Node = row.get_child(i)
		if ch is BaseButton:
			btns.append(ch as BaseButton)

	# If there are not enough direct buttons, descend one level in the first child container
	# (structure row -> wrapper_container -> [paint, line, rect, bucket, ...]).
	if btns.size() < 4:
		btns.clear()
		for i in ntools:
			var ch: Node = row.get_child(i)
			if not (ch is BaseButton):
				for j in ch.get_child_count():
					var nested: Node = ch.get_child(j)
					if nested is BaseButton:
						btns.append(nested as BaseButton)

	var nbtn := btns.size()
	if nbtn != 4 and nbtn != 5:
		return

	var b0 := btns[0]
	var idx := -1
	var grp: ButtonGroup = b0.button_group
	if grp != null:
		var pressed: BaseButton = grp.get_pressed_button()
		if pressed != null:
			for i in nbtn:
				if btns[i] == pressed:
					idx = i
					break
	if idx < 0:
		for i in nbtn:
			if btns[i].button_pressed:
				idx = i
				break
	if idx < 0:
		return
	if nbtn == 5:
		match idx:
			0:
				out["select"] = true
			1:
				out["paint"] = true
			2:
				out["line"] = true
			3:
				out["rect"] = true
			4:
				out["bucket"] = true
	else:
		## Terrains: no Select.
		match idx:
			0:
				out["paint"] = true
			1:
				out["line"] = true
			2:
				out["rect"] = true
			3:
				out["bucket"] = true


static func _tm_apply_tools_settings_row(out: Dictionary, settings: Node, es: EditorSettings, editor: EditorInterface) -> void:
	if settings == null:
		return
	out["picker"] = false
	out["eraser"] = false
	out["random_tile"] = false

	# Collect BaseButton (covers Button and TextureButton).
	var base_buttons: Array[BaseButton] = []
	_tm_collect_base_buttons_depth_first(settings, base_buttons)

	var picker_sc: Shortcut = es.get_shortcut(ES_TILEMAP_PICKER) if es.has_shortcut(ES_TILEMAP_PICKER) else null
	var eraser_sc: Shortcut = es.get_shortcut(ES_TILEMAP_ERASER) if es.has_shortcut(ES_TILEMAP_ERASER) else null


	for b in base_buttons:
		var sc: Shortcut = b.shortcut
		var has_sc := sc != null
		if has_sc:
			if picker_sc != null and _shortcuts_equal(sc, picker_sc):
				out["picker"] = b.button_pressed
			if eraser_sc != null and _shortcuts_equal(sc, eraser_sc):
				out["eraser"] = b.button_pressed

	## Icon fallback: more robust if b.shortcut is null in the UI instance even when it exists in EditorSettings.
	## Uses _tm_find_toggle_basebutton_with_icon (without pressed filter) to read real state.
	var th := editor.get_editor_theme() if editor != null else null
	if th != null:
		if not out["picker"]:
			var ic := th.get_icon("ColorPick", _ED_ICONS) if th.has_icon("ColorPick", _ED_ICONS) else null
			if ic != null:
				var found := _tm_find_toggle_basebutton_with_icon(settings, ic)
				if found != null:
					out["picker"] = found.button_pressed
		if not out["eraser"]:
			var ic := th.get_icon("Eraser", _ED_ICONS) if th.has_icon("Eraser", _ED_ICONS) else null
			if ic != null:
				var found := _tm_find_toggle_basebutton_with_icon(settings, ic)
				if found != null:
					out["eraser"] = found.button_pressed
		## Random tile: identify by icon (no shortcut in the UI).
		var rnd_ic := th.get_icon("RandomNumberGenerator", _ED_ICONS) if th.has_icon("RandomNumberGenerator", _ED_ICONS) else null
		if rnd_ic != null:
			var found := _tm_find_toggle_basebutton_with_icon(settings, rnd_ic)
			if found != null:
				out["random_tile"] = found.button_pressed
				return

	## Last resort: toggle without shortcut among all collected BaseButtons.
	if not out["random_tile"]:
		for b in base_buttons:
			if b.toggle_mode and b.shortcut == null:
				out["random_tile"] = b.button_pressed
				break


static func _tm_collect_buttons_depth_first(n: Node, out: Array[Button]) -> void:
	for c in n.get_children():
		_tm_collect_buttons_depth_first(c, out)
	if n is Button:
		out.append(n as Button)


## Same as _tm_collect_buttons_depth_first but collects BaseButton (includes TextureButton).
static func _tm_collect_base_buttons_depth_first(n: Node, out: Array[BaseButton]) -> void:
	for c in n.get_children():
		_tm_collect_base_buttons_depth_first(c, out)
	if n is BaseButton:
		out.append(n as BaseButton)


## Finds the first BaseButton with toggle_mode and the given icon (regardless of pressed state).
static func _tm_find_toggle_basebutton_with_icon(root: Node, want: Texture2D) -> BaseButton:
	if root is BaseButton:
		var b := root as BaseButton
		if b.toggle_mode and b.icon != null and b.icon == want:
			return b
	for c in root.get_children():
		var f := _tm_find_toggle_basebutton_with_icon(c, want)
		if f != null:
			return f
	return null


## Finds the first BaseButton with toggle_mode+button_pressed and the given icon.
static func _tm_find_pressed_toggle_basebutton_with_icon(root: Node, want: Texture2D) -> BaseButton:
	if root is BaseButton:
		var b := root as BaseButton
		if b.toggle_mode and b.button_pressed and b.icon != null and b.icon == want:
			return b
	for c in root.get_children():
		var f := _tm_find_pressed_toggle_basebutton_with_icon(c, want)
		if f != null:
			return f
	return null


## Fallback when toolbar does not yet exist in the tree: icon ref + shortcuts (e.g. freshly opened editor).
static func _tm_apply_toolbar_fallback_icons_and_shortcuts(
	editor: EditorInterface, es: EditorSettings, out: Dictionary,
) -> void:
	var search_root: Node = editor.get_base_control()
	if search_root == null:
		return
	var th := editor.get_editor_theme()
	if th != null:
		for tool_key in _TM_TOOLBAR_ICONS.keys():
			var inm: String = _TM_TOOLBAR_ICONS[tool_key]
			if not th.has_icon(inm, _ED_ICONS):
				continue
			var tex: Texture2D = th.get_icon(inm, _ED_ICONS)
			if tex == null:
				continue
			out[tool_key] = _tm_snap_style_find_pressed_toggle_with_icon(search_root, tex) != null
	var buttons: Array[BaseButton] = []
	_collect_base_buttons(search_root, buttons)
	for btn in buttons:
		if not btn.button_pressed:
			continue
		var sc: Shortcut = btn.shortcut
		if sc == null:
			continue
		for tool_key in _TOOL_TO_SHORTCUT.keys():
			if bool(out.get(tool_key, false)):
				continue
			var spath: String = _TOOL_TO_SHORTCUT[tool_key]
			if not es.has_shortcut(spath):
				continue
			var ref_sc: Shortcut = es.get_shortcut(spath)
			if ref_sc != null and _shortcuts_equal(sc, ref_sc):
				out[tool_key] = true
	if th != null and th.has_icon("RandomNumberGenerator", _ED_ICONS):
		var ic := th.get_icon("RandomNumberGenerator", _ED_ICONS)
		if ic != null:
			out["random_tile"] = _tm_snap_style_find_pressed_toggle_with_icon(search_root, ic) != null


## Search roots: bottom panel lives under [code]base_control[/code]; then 2D viewport.
static func _tilemap_search_roots(editor: EditorInterface) -> Array:
	var a: Array = []
	var bc := editor.get_base_control()
	if bc != null:
		a.append(bc)
	var ms := editor.get_editor_main_screen()
	if ms != null and ms != bc:
		a.append(ms)
	return a


## [code]toolbar[/code] container in TileMap plugin: 2 children ([code]tilemap_tiles_tools_buttons[/code] + [code]tools_settings[/code]).
static func _tilemap_toolbar_bar_container(editor: EditorInterface) -> Node:
	var base := editor.get_base_control()
	if base == null:
		return null
	var candidates: Array[Node] = []
	_tm_collect_tilemap_toolbar_bars(base, candidates)
	for bar in candidates:
		if bar.is_visible_in_tree():
			return bar
	## Bottom panel sometimes does not mark hierarchy as visible even while TileMap editor is active.
	for bar2 in candidates:
		var row: Node = bar2.get_child(0)
		if _tm_row_has_resolved_pressed_tool(row):
			return bar2
	if not candidates.is_empty():
		return candidates[candidates.size() - 1]
	return _tm_bar_from_random_icon_anchor(base, editor)


static func _tm_row_has_resolved_pressed_tool(row: Node) -> bool:
	if row == null or row.get_child_count() < 1:
		return false
	# Recursively search the first BaseButton with ButtonGroup
	var all_btns: Array[BaseButton] = []
	_tm_collect_base_buttons_depth_first(row, all_btns)
	for b in all_btns:
		if b.button_group != null:
			return b.button_group.get_pressed_button() != null
	return false


static func _tm_collect_tilemap_toolbar_bars(n: Node, out: Array[Node]) -> void:
	if _tm_node_is_tilemap_toolbar_bar(n):
		out.append(n)
	for c in n.get_children():
		_tm_collect_tilemap_toolbar_bars(c, out)


static func _tm_node_is_tilemap_toolbar_bar(node: Node) -> bool:
	if node.get_child_count() != 2:
		return false
	var row: Node = node.get_child(0)
	var settings: Node = node.get_child(1)
	## Exclusive tool row: [HBoxContainer] in older builds; [FlowContainer] if dock wraps the toolbar.
	if not _tm_is_tilemap_tool_row_container(row):
		return false
	if not settings is Container:
		return false
	var rc: int = row.get_child_count()
	if rc != 4 and rc != 5:
		return false
	return _tm_row_is_uniform_tool_toggle_row(row, rc)


static func _tm_is_tilemap_tool_row_container(row: Node) -> bool:
	return row is BoxContainer or row is FlowContainer


static func _tm_row_is_uniform_tool_toggle_row(row: Node, count: int) -> bool:
	var g: ButtonGroup = null
	for i in count:
		var ch: Node = row.get_child(i)
		if not ch is Button:
			return false
		var b := ch as Button
		if not b.toggle_mode:
			return false
		if g == null:
			g = b.button_group
		elif b.button_group != g:
			return false
	return g != null


static func _tm_bar_from_random_icon_anchor(base: Control, editor: EditorInterface) -> Node:
	var th := editor.get_editor_theme()
	if th == null or not th.has_icon("RandomNumberGenerator", _ED_ICONS):
		return null
	var want: Texture2D = th.get_icon("RandomNumberGenerator", _ED_ICONS)
	if want == null:
		return null
	var rnd: Button = _tm_snap_style_find_toggle_with_icon(base, want)
	if rnd == null:
		return null
	var settings_row := rnd.get_parent()
	if settings_row == null:
		return null
	return settings_row.get_parent()


## Copy of [method MXEditorSnapStateHelper._find_toggle_with_icon] criteria (no visibility filter).
static func _tm_snap_style_find_toggle_with_icon(n: Node, want: Texture2D) -> Button:
	if n is Button:
		var b := n as Button
		if b.toggle_mode and b.icon != null and b.icon == want:
			return b
	for c in n.get_children():
		var f := _tm_snap_style_find_toggle_with_icon(c, want)
		if f != null:
			return f
	return null


static func _tm_snap_style_find_pressed_toggle_with_icon(n: Node, want: Texture2D) -> Button:
	if n is Button:
		var b := n as Button
		if b.toggle_mode and b.button_pressed and b.icon != null and b.icon == want:
			return b
	for c in n.get_children():
		var f := _tm_snap_style_find_pressed_toggle_with_icon(c, want)
		if f != null:
			return f
	return null


## Diagnostic helper: tool name by index and group size.
static func _tool_key_from_idx(idx: int, nbtn: int) -> String:
	if nbtn == 5:
		var k5 := ["select", "paint", "line", "rect", "bucket"]
		return k5[idx] if idx >= 0 and idx < k5.size() else "?"
	var k4 := ["paint", "line", "rect", "bucket"]
	return k4[idx] if idx >= 0 and idx < k4.size() else "?"


## Current exclusive tool from [param toolbar] map (icons / shortcuts).
static func _derive_exclusive_tool_from_toolbar(toolbar: Dictionary) -> String:
	for k in _TM_EXCLUSIVE_TOOLS:
		if bool(toolbar.get(k, false)):
			return k
	return "unknown"


static func _detect_active_tool_via_shortcuts(editor: EditorInterface) -> String:
	var es := editor.get_editor_settings()
	var bar: Node = _tilemap_toolbar_bar_container(editor)
	# Try known toolbar first; if it does not work, expand to base_control
	# (safeguard for cases where found toolbar does not directly contain exclusive buttons).
	var roots: Array[Node] = []
	if bar != null:
		roots.append(bar)
	var bc := editor.get_base_control()
	if bc != null and bc != bar:
		roots.append(bc)
	for root_idx in roots.size():
		var search_root: Node = roots[root_idx]
		var buttons: Array[BaseButton] = []
		_collect_base_buttons(search_root, buttons)
		for btn in buttons:
			if not btn.button_pressed:
				continue
			var sc: Shortcut = btn.shortcut
			if sc == null:
				continue
			for tool_key in _TOOL_TO_SHORTCUT:
				var path: String = _TOOL_TO_SHORTCUT[tool_key]
				if not es.has_shortcut(path):
					continue
				var ref_sc: Shortcut = es.get_shortcut(path)
				if ref_sc and _shortcuts_equal(sc, ref_sc):
					return tool_key
	return "unknown"


static func _detect_active_tool(editor: EditorInterface) -> String:
	var tb: Dictionary = _tilemap_toolbar_state(editor)
	var ex := _derive_exclusive_tool_from_toolbar(tb)
	if ex != "unknown":
		return ex
	return _detect_active_tool_via_shortcuts(editor)


static func _collect_base_buttons(n: Node, out: Array[BaseButton]) -> void:
	for c in n.get_children():
		_collect_base_buttons(c, out)
	if n is BaseButton:
		out.append(n as BaseButton)


static func _shortcuts_equal(a: Shortcut, b: Shortcut) -> bool:
	if a == null or b == null:
		return false
	if a.events.size() != b.events.size():
		return false
	for i in a.events.size():
		if not _events_equal(a.events[i], b.events[i]):
			return false
	return true


static func _events_equal(e1: InputEvent, e2: InputEvent) -> bool:
	if e1.get_class() != e2.get_class():
		return false
	if e1 is InputEventKey and e2 is InputEventKey:
		var k1 := e1 as InputEventKey
		var k2 := e2 as InputEventKey
		return k1.keycode == k2.keycode \
			and k1.physical_keycode == k2.physical_keycode \
			and k1.ctrl_pressed == k2.ctrl_pressed \
			and k1.alt_pressed == k2.alt_pressed \
			and k1.shift_pressed == k2.shift_pressed \
			and k1.meta_pressed == k2.meta_pressed
	if e1 is InputEventMouseButton and e2 is InputEventMouseButton:
		var m1 := e1 as InputEventMouseButton
		var m2 := e2 as InputEventMouseButton
		return m1.button_index == m2.button_index
	return false


## Triggers the action by reading the [Shortcut] registered in [EditorSettings] for [param editor_setting_path]
## (e.g. [code]tiles_editor/paint_tool[/code]) and replaying its [InputEvent] with [method Input.parse_input_event]
## - the same events the editor associated with the shortcut (user-modified bindings in Shortcuts).
static func execute_editor_shortcut(editor: EditorInterface, editor_setting_path: String) -> bool:
	return MXEditorShortcutHelper.execute(editor, editor_setting_path)


static func _try_grab_focus_if_allowed(n: Node) -> void:
	if n is Control:
		var c := n as Control
		if c.focus_mode != Control.FOCUS_NONE:
			c.grab_focus()


## Godot does not expose a shortcut for "Place Random Tile": toggle button without [Shortcut] in [code]tools_settings[/code].
static func toggle_place_random_tile(editor: EditorInterface) -> bool:
	_try_grab_focus_if_allowed(editor.get_editor_main_screen())
	var b: Button = _find_random_tile_toggle_button(editor)
	if b == null:
		var th := editor.get_editor_theme()
		if th == null or not th.has_icon("RandomNumberGenerator", _ED_ICONS):
			return false
		var want: Texture2D = th.get_icon("RandomNumberGenerator", _ED_ICONS)
		if want == null:
			return false
		b = _find_tilemap_button_with_icon_roots(_tilemap_search_roots(editor), want) as Button
	if b == null:
		return false
	_try_grab_focus_if_allowed(b)
	b.set_pressed(!b.button_pressed)
	return true


static func _find_random_tile_toggle_button(editor: EditorInterface) -> Button:
	var bar: Node = _tilemap_toolbar_bar_container(editor)
	if bar == null or bar.get_child_count() < 2:
		return null
	return _tm_find_toggle_without_shortcut(bar.get_child(1))


static func _tm_find_toggle_without_shortcut(settings: Node) -> Button:
	if settings == null:
		return null
	for i in settings.get_child_count():
		var c: Node = settings.get_child(i)
		if c is Button:
			var btn := c as Button
			if btn.toggle_mode and btn.shortcut == null:
				return btn
	return null


static func _find_tilemap_button_with_icon_roots(roots: Array, want: Texture2D) -> BaseButton:
	for r in roots:
		if r == null:
			continue
		var f := _find_tilemap_button_with_icon(r, want)
		if f != null:
			return f
	return null


static func _find_tilemap_button_with_icon(n: Node, want: Texture2D) -> BaseButton:
	if n is Button:
		var b := n as Button
		if b.toggle_mode and b.icon != null and b.icon == want:
			return b
	for c in n.get_children():
		var found := _find_tilemap_button_with_icon(c, want)
		if found != null:
			return found
	return null


## "Scattering" SpinBox next to Place Random Tile button (native editor).
static func _find_tilemap_scatter_spinbox(editor: EditorInterface) -> SpinBox:
	var rnd_btn: BaseButton = _find_random_tile_toggle_button(editor)
	if rnd_btn == null:
		var th := editor.get_editor_theme()
		if th == null or not th.has_icon("RandomNumberGenerator", _ED_ICONS):
			return null
		var want: Texture2D = th.get_icon("RandomNumberGenerator", _ED_ICONS)
		if want == null:
			return null
		rnd_btn = _find_tilemap_button_with_icon_roots(_tilemap_search_roots(editor), want)
	if rnd_btn == null:
		return null
	var p := rnd_btn.get_parent()
	if p == null:
		return null
	for i in range(rnd_btn.get_index() + 1, p.get_child_count()):
		var sb := _find_first_spinbox_descendant(p.get_child(i))
		if sb != null:
			return sb
	return null


static func _find_first_spinbox_descendant(n: Node) -> SpinBox:
	if n is SpinBox:
		return n as SpinBox
	for ch in n.get_children():
		var f := _find_first_spinbox_descendant(ch)
		if f != null:
			return f
	return null


static func adjust_random_scatter(editor: EditorInterface, delta_steps: int) -> bool:
	if delta_steps == 0:
		return true
	_try_grab_focus_if_allowed(editor.get_editor_main_screen())
	var spin := _find_tilemap_scatter_spinbox(editor)
	if spin == null:
		return false
	var step_f: float = maxf(float(spin.step), 0.001)
	var inc: float = step_f * 15.0 * float(delta_steps)
	spin.value = clampf(spin.value + inc, spin.min_value, spin.max_value)
	return true


static func _read_random_scatter_value(editor: EditorInterface) -> float:
	var sb := _find_tilemap_scatter_spinbox(editor)
	if sb == null:
		return 0.0
	return float(sb.value)


## No entry in the TileMap manual table; hardware dial -> synthetic wheel (not a [code]tiles_editor/*[/code]).
static func inject_tile_palette_wheel(editor: EditorInterface, steps: int) -> void:
	if steps == 0:
		return
	_try_grab_focus_if_allowed(editor.get_editor_main_screen())
	var vp: Viewport = editor.get_base_control().get_viewport()
	var rect := editor.get_base_control().get_global_rect()
	var pos := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.78)
	var n: int = mini(absi(steps), 16)
	var sign := 1 if steps > 0 else -1
	for _i in n:
		var ev := InputEventMouseButton.new()
		ev.global_position = pos
		ev.position = vp.get_mouse_position()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if sign > 0 else MOUSE_BUTTON_WHEEL_DOWN
		ev.factor = 1.0
		ev.pressed = true
		ev.device = -1
		Input.parse_input_event(ev)


func build_options(context: Dictionary) -> Array:
	if not context.get("has_tilemap", false):
		return []
	return [
		MXOption.trigger(ID_PAINT, "Paint", GRP),
		MXOption.trigger(ID_LINE, "Line", GRP),
		MXOption.trigger(ID_RECT, "Rectangle", GRP),
		MXOption.trigger(ID_BUCKET, "Bucket", GRP),
		MXOption.trigger(ID_PICKER, "Picker", GRP),
		MXOption.trigger(ID_ERASER, "Eraser", GRP),
		MXOption.trigger(ID_TOGGLE_RANDOM_TILE, "Random tile", GRP),
		MXOption.trigger(ID_ROT_L, "Rotate left", GRP),
		MXOption.trigger(ID_ROT_R, "Rotate right", GRP),
		MXOption.trigger(ID_ROTATE, "Rotate (right)", GRP),
		MXOption.trigger(ID_FLIP_H, "Flip H", GRP),
		MXOption.trigger(ID_FLIP_V, "Flip V", GRP),
		MXOption.trigger(ID_PREV_LAYER, "Prev layer", GRP),
		MXOption.trigger(ID_NEXT_LAYER, "Next layer", GRP),
	]


func apply_event(
	event: Dictionary,
	context: Dictionary,
	editor: EditorInterface,
	_undo: EditorUndoRedoManager,
) -> bool:
	var id := str(event.get("id", ""))
	# Do not intercept the rest of the bridge (e.g. mx.view3d.*, particles, transform...).
	if not id.begins_with("mx.tilemap."):
		return false
	var main_ms := str(context.get("main_screen", ""))
	var allow := bool(context.get("has_tilemap", false)) or screen_allows_tilemap(main_ms)
	if not allow:
		return false
	var kind := str(event.get("kind", ""))
	var ok := false
	if id == ID_TILE_SCROLL:
		if kind == "set_float" or kind == "set_int":
			var v := int(round(float(event.get("value", 0.0))))
			inject_tile_palette_wheel(editor, v)
			ok = true
	elif id == ID_RANDOM_SCATTER:
		if kind == "set_float" or kind == "set_int":
			var v2 := int(round(float(event.get("value", 0.0))))
			ok = adjust_random_scatter(editor, v2)
	elif kind == "trigger":
		ok = _tilemap_apply_trigger_event(id, editor)

	return ok


static func _tilemap_apply_trigger_event(id: String, editor: EditorInterface) -> bool:
	match id:
		ID_SELECT:
			return execute_editor_shortcut(editor, ES_TILEMAP_SELECTION_TOOL)
		ID_PAINT:
			return execute_editor_shortcut(editor, ES_TILEMAP_PAINT_TOOL)
		ID_LINE:
			return execute_editor_shortcut(editor, ES_TILEMAP_LINE_TOOL)
		ID_RECT:
			return execute_editor_shortcut(editor, ES_TILEMAP_RECT_TOOL)
		ID_BUCKET:
			return execute_editor_shortcut(editor, ES_TILEMAP_BUCKET_TOOL)
		ID_PICKER:
			return execute_editor_shortcut(editor, ES_TILEMAP_PICKER)
		ID_ERASER:
			return execute_editor_shortcut(editor, ES_TILEMAP_ERASER)
		ID_TOGGLE_RANDOM_TILE:
			return toggle_place_random_tile(editor)
		ID_ROT_L:
			return execute_editor_shortcut(editor, ES_TILEMAP_ROTATE_TILE_LEFT)
		ID_ROT_R, ID_ROTATE:
			return execute_editor_shortcut(editor, ES_TILEMAP_ROTATE_TILE_RIGHT)
		ID_FLIP_H:
			return execute_editor_shortcut(editor, ES_TILEMAP_FLIP_TILE_HORIZONTAL)
		ID_FLIP_V:
			return execute_editor_shortcut(editor, ES_TILEMAP_FLIP_TILE_VERTICAL)
		ID_PREV_LAYER:
			return execute_editor_shortcut(editor, ES_TILEMAP_SELECT_PREVIOUS_LAYER)
		ID_NEXT_LAYER:
			return execute_editor_shortcut(editor, ES_TILEMAP_SELECT_NEXT_LAYER)
		_:
			return false

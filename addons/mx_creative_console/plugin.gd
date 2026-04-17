@tool
extends EditorPlugin

## Preload dependency order so `class_name` scripts exist before provider scripts parse.
const _MxOption := preload("res://addons/mx_creative_console/core/mx_option.gd")
const _MxOptionProvider := preload("res://addons/mx_creative_console/core/mx_option_provider.gd")
const _MxBridge := preload("res://addons/mx_creative_console/core/mx_bridge.gd")
const _MxBridgeService := preload("res://addons/mx_creative_console/core/mx_bridge_service.gd")
const _MxEditorSnapStateHelperLoad := preload("res://addons/mx_creative_console/core/mx_editor_snap_state_helper.gd")
const _MxContextBus := preload("res://addons/mx_creative_console/core/mx_context_bus.gd")
const _MxEditorRunHelper := preload("res://addons/mx_creative_console/core/mx_editor_run_helper.gd")
const _MxEditorShortcutHelperLoad := preload("res://addons/mx_creative_console/core/mx_editor_shortcut_helper.gd")
const _MxEditorPluginHostLoad := preload("res://addons/mx_creative_console/core/mx_editor_plugin_host.gd")
const _MxEditorViewport3dHelperLoad := preload("res://addons/mx_creative_console/core/mx_editor_viewport_3d_helper.gd")

## Side-effect preload: registers [class_name MXTileMapProvider] before [method _enter_tree] uses it.
const _MxTileMapProviderLoad := preload("res://addons/mx_creative_console/providers/tile_map_provider.gd")
const NodeTransformProviderScript: Script = preload("res://addons/mx_creative_console/providers/node_transform_provider.gd")
const PlayModeProviderScript: Script = preload("res://addons/mx_creative_console/providers/play_mode_provider.gd")
const InspectorPropProviderScript: Script = preload("res://addons/mx_creative_console/providers/inspector_prop_provider.gd")
const ParticlesProviderScript: Script = preload("res://addons/mx_creative_console/providers/particles_provider.gd")
const CollisionLayersProviderScript: Script = preload("res://addons/mx_creative_console/providers/collision_layers_provider.gd")
const RenderLayersProviderScript: Script = preload("res://addons/mx_creative_console/providers/render_layers_provider.gd")
const EditorShortcutsProviderScript: Script = preload("res://addons/mx_creative_console/providers/editor_shortcuts_provider.gd")
const SceneTreeProviderScript: Script = preload("res://addons/mx_creative_console/providers/scene_tree_provider.gd")
const ScriptProviderScript: Script = preload("res://addons/mx_creative_console/providers/script_provider.gd")
const DebugProviderScript: Script = preload("res://addons/mx_creative_console/providers/debug_provider.gd")
## Side-effect preload: registers [class_name MXAnimationProvider] before [method _enter_tree] uses it.
const AnimationProviderScript: Script = preload("res://addons/mx_creative_console/providers/animation_provider.gd")

var _bus: RefCounted
var _bridge_service: Node

## ── Timers ──────────────────────────────────────────────────────────────────
var _event_poll: Timer       ## consumes HTTP events from the bridge service (every 0.15s)
var _context_poll: Timer     ## medium: refreshes context.json with live node data (every 0.35s)

## ── State tracking ─────────────────────────────────────────────────────────
var _main_screen: String = ""
var _focused_inspector_prop: Dictionary = {}
var _connected_inspectors: Array = []
## Change detection: avoid writing a new snapshot if nothing changed
var _last_ctx_hash: int = 0
## Track play state transitions to trigger immediate refresh
var _last_is_playing: bool = false
## Track selected node paths for change detection
var _last_selected_paths: PackedStringArray = []
## Track selected Node3D / Node2D transform for live updates
var _last_n3d_pos: Vector3 = Vector3.ZERO
var _last_n3d_rot: Vector3 = Vector3.ZERO
var _last_n3d_scale: Vector3 = Vector3.ONE
var _last_n3d_visible: bool = true
var _last_n2d_pos: Vector2 = Vector2.ZERO
var _last_n2d_rot: float = 0.0
var _last_n2d_scale: Vector2 = Vector2.ONE
var _last_n2d_visible: bool = true
## Last particle node property snapshot (GPU/CPU 2D/3D — Inspector edits don't move the node).
var _last_pt_emitting: bool = false
var _last_pt_amount: int = -1
var _last_pt_amount_ratio: float = -1.0
var _last_pt_lifetime: float = -1.0
var _last_pt_one_shot: bool = false
var _last_pt_speed_scale: float = -1.0
var _last_pt_explosiveness: float = -1.0
var _last_pt_randomness: float = -1.0
## CollisionObject2D/3D: Inspector layer & mask toggles (not detected by transform poll).
var _last_col_layer: int = -1
var _last_col_mask: int = -1
## CanvasItem visibility_layer / light_mask (Inspector).
var _last_canvas_vis: int = -1
var _last_canvas_light: int = -1
## VisualInstance3D.layers
var _last_vi_layers: int = -1
## While playing: Run-bar pause + time_scale (Game tab may change effective scale without touching Engine.time_scale).
var _last_runtime_paused: bool = false
var _last_playing_time_scale: float = -1.0
var _last_playing_effective_time_scale: float = -1.0
## TileMap editor toolbar / layer (no public editor signals — polled here).
var _last_tm_tool: String = ""
var _last_tm_layer: int = -1
var _last_tm_layer_count: int = -1
## Eraser / picker / random tile can change without moving the active_tool (still shows paint).
var _last_tm_toolbar_sig: String = ""
var _last_tm_random_scatter: float = -1.0
## Smart / grid / 3D snap (no editor signals — must be polled like TileMap).
var _last_canvas_smart_snap := false
var _last_canvas_grid_snap := false
var _last_spatial_snap := false
var _snap_poll_reader: RefCounted
## AnimationPlayer state (polled — no editor signals).
var _last_anim_name: String = ""
var _last_anim_playing: bool = false
var _last_anim_loop_mode: int = -1
var _last_anim_track_count: int = -1
var _last_anim_selected_track: int = -1


func _ei() -> EditorInterface:
	return get_editor_interface()


func _mx_touch_preloads() -> void:
	if _MxOption == null or _MxOptionProvider == null or _MxEditorRunHelper == null \
			or _MxEditorSnapStateHelperLoad == null or _MxTileMapProviderLoad == null \
			or _MxEditorShortcutHelperLoad == null or _MxEditorViewport3dHelperLoad == null \
			or _MxEditorPluginHostLoad == null or EditorShortcutsProviderScript == null \
			or SceneTreeProviderScript == null or AnimationProviderScript == null:
		push_error("[MX] One or more required scripts failed to preload — addon may not work correctly.")


# ═══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _enter_tree() -> void:
	_mx_touch_preloads()
	MXEditorPluginHost.instance = self
	_bus = _MxContextBus.new() as RefCounted
	_bus.register_provider(NodeTransformProviderScript.new())
	_bus.register_provider(PlayModeProviderScript.new())
	_bus.register_provider(InspectorPropProviderScript.new())
	_bus.register_provider(ParticlesProviderScript.new())
	_bus.register_provider(CollisionLayersProviderScript.new())
	_bus.register_provider(RenderLayersProviderScript.new())
	_bus.register_provider(MXTileMapProvider.new())
	_bus.register_provider(EditorShortcutsProviderScript.new())
	_bus.register_provider(DebugProviderScript.new())
	_bus.register_provider(ScriptProviderScript.new())
	_bus.register_provider(SceneTreeProviderScript.new())
	_bus.register_provider(AnimationProviderScript.new())

	_bridge_service = _MxBridgeService.new()
	add_child(_bridge_service)
	_MxBridge.register_bridge_service(_bridge_service)
	# ── Signal connections ───────────────────────────────────────────────
	_ei().get_selection().selection_changed.connect(_on_selection_changed)
	_ei().get_inspector().resource_selected.connect(_on_inspector_resource_selected)
	_scan_and_connect_inspectors()
	if not main_screen_changed.is_connected(_on_main_screen_changed):
		main_screen_changed.connect(_on_main_screen_changed)

	# ── Event poll (fast — reads hardware events) ────────────────────────
	_event_poll = Timer.new()
	_event_poll.wait_time = 0.02
	_event_poll.timeout.connect(_on_poll_bridge_events)
	add_child(_event_poll)
	_event_poll.start()

	# ── Context poll (medium — refreshes context for live selection / transform) ──
	_context_poll = Timer.new()
	_context_poll.wait_time = 0.35
	_context_poll.timeout.connect(_on_context_poll)
	add_child(_context_poll)
	_context_poll.start()

	if not ProjectSettings.settings_changed.is_connected(_on_project_settings_changed):
		ProjectSettings.settings_changed.connect(_on_project_settings_changed)

	_force_refresh()


func _exit_tree() -> void:
	if ProjectSettings.settings_changed.is_connected(_on_project_settings_changed):
		ProjectSettings.settings_changed.disconnect(_on_project_settings_changed)
	if _bridge_service:
		_MxBridge.unregister_bridge_service(_bridge_service)
		_bridge_service.queue_free()
		_bridge_service = null
	if _event_poll:
		_event_poll.queue_free()
		_event_poll = null
	if _context_poll:
		_context_poll.queue_free()
		_context_poll = null
	var sel := _ei().get_selection()
	if sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.disconnect(_on_selection_changed)
	var root_insp := _ei().get_inspector()
	if root_insp.resource_selected.is_connected(_on_inspector_resource_selected):
		root_insp.resource_selected.disconnect(_on_inspector_resource_selected)
	_disconnect_all_inspectors()
	if main_screen_changed.is_connected(_on_main_screen_changed):
		main_screen_changed.disconnect(_on_main_screen_changed)
	_bus = null
	MXEditorPluginHost.instance = null



# ═══════════════════════════════════════════════════════════════════════════════
#  CHANGE DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _on_selection_changed() -> void:
	_focused_inspector_prop = {}
	_force_refresh()


func _on_main_screen_changed(screen_name: String) -> void:
	_main_screen = screen_name
	_force_refresh()


## Project → Project Settings (layer names, etc.): poll does not see these edits.
func _on_project_settings_changed() -> void:
	_force_refresh()


## Called every ~0.35s — detects live changes that don't have signals:
##   • Play state transitions (game started/stopped)
##   • Node3D / Node2D transform changes (user dragging in viewport)
##   • Particle node property changes (Inspector: amount, lifetime, emitting, etc.)
##   • Selection changes that signals may have missed
##   • Physics layer display names: see _on_project_settings_changed (not this timer).
##   • Collision layer/mask bits on selected body: tracked below (Inspector).
##   • Smart / grid / 3D snap toggles (toolbar; no editor signals).
##   • TileMap: toolbar + scatter + layer (same layer resolution as context: selection or scene).
func _on_context_poll() -> void:
	if _bus == null:
		return

	var ei := _ei()
	var changed := false

	# ── Play state transition ────────────────────────────────────────────
	var playing := ei.is_playing_scene()
	if playing != _last_is_playing:
		_last_is_playing = playing
		changed = true
		if playing:
			_last_runtime_paused = _MxEditorRunHelper.get_runtime_paused(ei)
			_last_playing_time_scale = Engine.time_scale
			if Engine.has_method("get_effective_time_scale"):
				_last_playing_effective_time_scale = float(Engine.call("get_effective_time_scale"))
			else:
				_last_playing_effective_time_scale = _last_playing_time_scale
		else:
			_last_playing_time_scale = -1.0
			_last_playing_effective_time_scale = -1.0
			_last_runtime_paused = false

	# ── Selection change (backup detection) ──────────────────────────────
	var nodes := ei.get_selection().get_selected_nodes()
	var paths: PackedStringArray = []
	for n in nodes:
		paths.append(String(n.get_path()))
	if paths != _last_selected_paths:
		_last_selected_paths = paths
		changed = true

	# ── Transform live tracking (Node3D preferred over Node2D) ───────────
	var tracked_3d := false
	for n in nodes:
		if n is Node3D:
			var t := n as Node3D
			if t.position != _last_n3d_pos or t.rotation != _last_n3d_rot \
			   or t.scale != _last_n3d_scale or t.visible != _last_n3d_visible:
				_last_n3d_pos = t.position
				_last_n3d_rot = t.rotation
				_last_n3d_scale = t.scale
				_last_n3d_visible = t.visible
				changed = true
			tracked_3d = true
			break
	if not tracked_3d:
		for n in nodes:
			if n is Node2D:
				var t2 := n as Node2D
				if t2.position != _last_n2d_pos or t2.rotation != _last_n2d_rot \
				   or t2.scale != _last_n2d_scale or t2.visible != _last_n2d_visible:
					_last_n2d_pos = t2.position
					_last_n2d_rot = t2.rotation
					_last_n2d_scale = t2.scale
					_last_n2d_visible = t2.visible
					changed = true
				break

	# ── Particles live tracking (amount / lifetime / etc. in Inspector) ─
	var tracked_pt := false
	var pn := _first_particle_in_selection(nodes)
	if pn != null:
		var v := _particle_poll_values(pn)
		if v.emitting != _last_pt_emitting or v.amount != _last_pt_amount \
				or not is_equal_approx(v.ratio, _last_pt_amount_ratio) or v.lifetime != _last_pt_lifetime \
				or v.one_shot != _last_pt_one_shot \
				or not is_equal_approx(v.speed_scale, _last_pt_speed_scale) \
				or not is_equal_approx(v.explosiveness, _last_pt_explosiveness) \
				or not is_equal_approx(v.randomness, _last_pt_randomness):
			_last_pt_emitting = v.emitting
			_last_pt_amount = v.amount
			_last_pt_amount_ratio = v.ratio
			_last_pt_lifetime = v.lifetime
			_last_pt_one_shot = v.one_shot
			_last_pt_speed_scale = v.speed_scale
			_last_pt_explosiveness = v.explosiveness
			_last_pt_randomness = v.randomness
			changed = true
		tracked_pt = true
	if not tracked_pt:
		_last_pt_emitting = false
		_last_pt_amount = -1
		_last_pt_amount_ratio = -1.0
		_last_pt_lifetime = -1.0
		_last_pt_one_shot = false
		_last_pt_speed_scale = -1.0
		_last_pt_explosiveness = -1.0
		_last_pt_randomness = -1.0

	# ── Collision layer / mask (Inspector — same pattern as particles) ───
	var tracked_col := false
	var coln := _first_collision_in_selection(nodes)
	if coln != null:
		var cl := int(coln.collision_layer)
		var cm := int(coln.collision_mask)
		if cl != _last_col_layer or cm != _last_col_mask:
			_last_col_layer = cl
			_last_col_mask = cm
			changed = true
		tracked_col = true
	if not tracked_col:
		_last_col_layer = -1
		_last_col_mask = -1

	# ── CanvasItem: visibility_layer + light_mask ─────────────────────────
	var tracked_canvas := false
	var canvas_n := _first_canvas_item_in_selection(nodes)
	if canvas_n != null:
		var ci := canvas_n as CanvasItem
		var vl := int(ci.visibility_layer)
		var lm := int(ci.light_mask)
		if vl != _last_canvas_vis or lm != _last_canvas_light:
			_last_canvas_vis = vl
			_last_canvas_light = lm
			changed = true
		tracked_canvas = true
	if not tracked_canvas:
		_last_canvas_vis = -1
		_last_canvas_light = -1

	# ── VisualInstance3D render layers ──────────────────────────────────
	var tracked_vi := false
	var vi_n := _first_visual_instance_in_selection(nodes)
	if vi_n != null:
		var vlayers := int((vi_n as VisualInstance3D).layers)
		if vlayers != _last_vi_layers:
			_last_vi_layers = vlayers
			changed = true
		tracked_vi = true
	if not tracked_vi:
		_last_vi_layers = -1

	# ── Run bar: pause / Engine.time_scale (+ effective scale when API exists, e.g. Game tab debugger speed)
	if playing:
		var paused_now := _MxEditorRunHelper.get_runtime_paused(ei)
		if paused_now != _last_runtime_paused:
			_last_runtime_paused = paused_now
			changed = true
		var ts := Engine.time_scale
		if not is_equal_approx(ts, _last_playing_time_scale):
			_last_playing_time_scale = ts
			changed = true
		var ts_eff := ts
		if Engine.has_method("get_effective_time_scale"):
			ts_eff = float(Engine.call("get_effective_time_scale"))
		if not is_equal_approx(ts_eff, _last_playing_effective_time_scale):
			_last_playing_effective_time_scale = ts_eff
			changed = true

	# ── TileMap: tool, layer, toolbar (eraser/picker/random...), scatter ─
	if MXTileMapProvider.screen_allows_tilemap(_main_screen):
		var tm_layer := MXTileMapProvider.resolve_tilemap_layer(ei, nodes)
		if tm_layer != null:
			var tm_snap: Dictionary = MXTileMapProvider._build_snapshot(tm_layer, ei)
			var tm_tool := str(tm_snap.get("active_tool", "unknown"))
			var tli := int(tm_snap.get("current_layer", 0))
			var tlc := int(tm_snap.get("layer_count", 0))
			var tb_sig := _tm_toolbar_signature(tm_snap.get("toolbar", {}))
			var trs: float = float(tm_snap.get("random_scatter", 0.0))
			if tm_tool != _last_tm_tool or tli != _last_tm_layer or tlc != _last_tm_layer_count \
					or tb_sig != _last_tm_toolbar_sig \
					or not is_equal_approx(trs, _last_tm_random_scatter):
				_last_tm_tool = tm_tool
				_last_tm_layer = tli
				_last_tm_layer_count = tlc
				_last_tm_toolbar_sig = tb_sig
				_last_tm_random_scatter = trs
				changed = true
		else:
			if _reset_tilemap_state():
				changed = true
	else:
		if _reset_tilemap_state():
			changed = true

	# ── AnimationPlayer state ────────────────────────────────────────────────
	var anim_snap: Variant = MXAnimationProvider.extend_context(ei, _main_screen, nodes).get("animation_snapshot", null)
	if typeof(anim_snap) == TYPE_DICTIONARY:
		var anim_d := anim_snap as Dictionary
		var an   := str(anim_d.get("animation_name", ""))
		var apl  := bool(anim_d.get("is_playing", false))
		var alm  := int(anim_d.get("loop_mode", 0))
		var atc  := int(anim_d.get("track_count", 0))
		var ast  := int(anim_d.get("selected_track", 0))
		if an != _last_anim_name or apl != _last_anim_playing or alm != _last_anim_loop_mode \
				or atc != _last_anim_track_count or ast != _last_anim_selected_track:
			_last_anim_name           = an
			_last_anim_playing        = apl
			_last_anim_loop_mode      = alm
			_last_anim_track_count    = atc
			_last_anim_selected_track = ast
			changed = true
	else:
		if _last_anim_name != "" or _last_anim_playing or _last_anim_track_count >= 0:
			_last_anim_name           = ""
			_last_anim_playing        = false
			_last_anim_loop_mode      = -1
			_last_anim_track_count    = -1
			_last_anim_selected_track = -1
			changed = true

	# ── Canvas / 3D snap toggles (editor toolbar; no signals) ─────────────
	if _snap_poll_reader == null:
		_snap_poll_reader = _MxEditorSnapStateHelperLoad.new() as RefCounted
	var snap_d: Dictionary = _snap_poll_reader.call("read_for_context", ei, _main_screen) as Dictionary
	var cs := bool(snap_d.get("canvas_smart_snap_active", false))
	var cg := bool(snap_d.get("canvas_grid_snap_active", false))
	var sp := bool(snap_d.get("spatial_snap_active", false))
	if cs != _last_canvas_smart_snap or cg != _last_canvas_grid_snap or sp != _last_spatial_snap:
		_last_canvas_smart_snap = cs
		_last_canvas_grid_snap = cg
		_last_spatial_snap = sp
		changed = true

	if changed:
		_refresh_context_impl()


## Force an immediate context refresh (used on selection/tab changes)
func _force_refresh() -> void:
	call_deferred("_refresh_context_impl")


## Returns true when tilemap tracking was dirty and needed to be cleared.
func _reset_tilemap_state() -> bool:
	if _last_tm_tool == "" and _last_tm_layer < 0 and _last_tm_toolbar_sig == "" \
			and _last_tm_random_scatter < 0.0:
		return false
	_last_tm_tool = ""
	_last_tm_layer = -1
	_last_tm_layer_count = -1
	_last_tm_toolbar_sig = ""
	_last_tm_random_scatter = -1.0
	return true

func _on_mx_hardware_event_emulated(ev: Dictionary) -> void:
	if _bus == null:
		return
	var batch: Array = [ev]
	_bus.apply_events(_ei(), get_undo_redo(), batch, _main_screen,
		{"focused_inspector_prop": _focused_inspector_prop})
	if str(ev.get("kind", "")) != "range_value":
		_force_refresh()


# ═══════════════════════════════════════════════════════════════════════════════
#  INSPECTOR TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func _connect_inspector(insp: EditorInspector) -> void:
	if _connected_inspectors.has(insp):
		return
	insp.property_selected.connect(_on_inspector_property_selected_on.bind(insp))
	_connected_inspectors.append(insp)


func _disconnect_all_inspectors() -> void:
	for insp in _connected_inspectors:
		if is_instance_valid(insp):
			var cb := _on_inspector_property_selected_on.bind(insp)
			if (insp as EditorInspector).property_selected.is_connected(cb):
				(insp as EditorInspector).property_selected.disconnect(cb)
	_connected_inspectors.clear()


func _scan_and_connect_inspectors() -> void:
	_walk_for_inspectors(_ei().get_inspector())


func _walk_for_inspectors(node: Node) -> void:
	if node is EditorInspector:
		_connect_inspector(node as EditorInspector)
	for child in node.get_children():
		_walk_for_inspectors(child)


func _on_inspector_resource_selected(_resource: Resource, _prop: String) -> void:
	call_deferred("_scan_and_connect_inspectors")


func _on_inspector_property_selected_on(property: String, insp: EditorInspector) -> void:
	var obj := insp.get_edited_object()
	if not is_instance_valid(obj):
		_focused_inspector_prop = {}
		_force_refresh()
		return
	_focused_inspector_prop = {}
	var prop_key: String = str(property)
	for p in obj.get_property_list():
		if str(p.get("name", "")) != prop_key:
			continue
		var ptype: int = int(p.get("type", TYPE_NIL))
		var phint: int = int(p.get("hint", PROPERTY_HINT_NONE))
		if (ptype == TYPE_FLOAT or ptype == TYPE_INT) and phint == PROPERTY_HINT_RANGE:
			var parts := str(p.get("hint_string", "")).split(",")
			var mn := float(parts[0]) if parts.size() > 0 else 0.0
			var mx := float(parts[1]) if parts.size() > 1 else 1.0
			var st := float(parts[2]) if parts.size() > 2 else (1.0 if ptype == TYPE_INT else 0.001)
			_focused_inspector_prop = {
				"object": obj,
				"property": prop_key,
				"label": prop_key.replace("_", " ").capitalize(),
				"min": mn,
				"max": mx,
				"step": st,
			}
		break
	_force_refresh()



#  CONTEXT REFRESH + BRIDGE COMMUNICATION
# ═══════════════════════════════════════════════════════════════════════════════

func _tm_toolbar_signature(tb: Variant) -> String:
	if typeof(tb) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = tb
	var keys: Array = d.keys()
	keys.sort()
	var acc := ""
	for k in keys:
		if acc != "":
			acc += "|"
		acc += "%s=%s" % [str(k), "1" if bool(d[k]) else "0"]
	return acc


func _refresh_context_impl() -> void:
	if _bus == null:
		return
	var ei := _ei()
	var ctx: Dictionary = _bus.build_context(ei, _main_screen)
	ctx["focused_inspector_prop"] = _focused_inspector_prop
	var options: Array = _bus.collect_options(ctx)

	# ── Write only if something changed (hash comparison) ────────────────
	var ctx_hash := _compute_ctx_hash(ctx, options)
	if ctx_hash != _last_ctx_hash:
		_last_ctx_hash = ctx_hash
		_MxBridge.write_snapshot(ctx, options)


func _first_particle_in_selection(nodes: Array) -> Node:
	for n in nodes:
		if n is GPUParticles3D or n is GPUParticles2D or n is CPUParticles3D or n is CPUParticles2D:
			return n
	return null


## Same priority as MXContextBus.build_context: first CollisionObject3D, else CollisionObject2D.
func _first_collision_in_selection(nodes: Array) -> Node:
	for n in nodes:
		if n is CollisionObject3D:
			return n
	for n in nodes:
		if n is CollisionObject2D:
			return n
	return null


func _first_canvas_item_in_selection(nodes: Array) -> CanvasItem:
	for n in nodes:
		if n is CanvasItem:
			return n
	return null


func _first_visual_instance_in_selection(nodes: Array) -> VisualInstance3D:
	for n in nodes:
		if n is VisualInstance3D:
			return n
	return null


func _particle_poll_values(n: Node) -> Dictionary:
	var ratio := 0.0
	if n is GPUParticles2D:
		ratio = (n as GPUParticles2D).amount_ratio
	elif n is GPUParticles3D:
		ratio = (n as GPUParticles3D).amount_ratio
	return {
		"emitting": n.emitting,
		"amount": n.amount,
		"ratio": ratio,
		"lifetime": n.lifetime,
		"one_shot": n.one_shot,
		"speed_scale": n.speed_scale,
		"explosiveness": n.explosiveness,
		"randomness": n.randomness,
	}


## Simple hash to detect context changes without writing identical files.
func _compute_ctx_hash(ctx: Dictionary, options: Array) -> int:
	var h := 17
	h = h * 31 + hash(ctx.get("main_screen", ""))
	h = h * 31 + hash(bool(ctx.get("canvas_smart_snap_active", false)))
	h = h * 31 + hash(bool(ctx.get("canvas_grid_snap_active", false)))
	h = h * 31 + hash(bool(ctx.get("spatial_snap_active", false)))
	h = h * 31 + hash(ctx.get("is_playing", false))
	h = h * 31 + hash(ctx.get("runtime_paused", false))
	h = h * 31 + hash(ctx.get("engine_time_scale", 1.0))
	h = h * 31 + hash(ctx.get("runtime_time_scale_effective", ctx.get("engine_time_scale", 1.0)))
	h = h * 31 + hash(ctx.get("has_node3d", false))
	h = h * 31 + hash(ctx.get("has_node2d", false))
	h = h * 31 + hash(ctx.get("has_particles", false))
	h = h * 31 + hash(ctx.get("is_script_tab", false))
	# Include transform data for Node3D
	var n3d: Variant = ctx.get("node3d_snapshot", null)
	if typeof(n3d) == TYPE_DICTIONARY:
		h = h * 31 + hash(str(n3d.get("path", "")))
		h = h * 31 + hash(n3d.get("position", []))
		h = h * 31 + hash(n3d.get("rotation_deg", []))
		h = h * 31 + hash(n3d.get("scale_uniform", 1.0))
		h = h * 31 + hash(n3d.get("visible", true))
	# Node2D snapshot
	var n2d: Variant = ctx.get("node2d_snapshot", null)
	if typeof(n2d) == TYPE_DICTIONARY:
		h = h * 31 + hash(str(n2d.get("path", "")))
		h = h * 31 + hash(n2d.get("position", []))
		h = h * 31 + hash(n2d.get("rotation_deg", []))
		h = h * 31 + hash(n2d.get("scale_uniform", 1.0))
		h = h * 31 + hash(n2d.get("visible", true))
	# Include particles data (path distinguishes two nodes with identical numeric state)
	var pt: Variant = ctx.get("particles_snapshot", null)
	if typeof(pt) == TYPE_DICTIONARY:
		h = h * 31 + hash(str(pt.get("path", "")))
		h = h * 31 + hash(pt.get("emitting", false))
		h = h * 31 + hash(pt.get("amount", 0))
		h = h * 31 + hash(pt.get("amount_ratio", 1.0))
		h = h * 31 + hash(pt.get("supports_amount_ratio", true))
		h = h * 31 + hash(pt.get("lifetime", 1.0))
		h = h * 31 + hash(pt.get("speed_scale", 1.0))
		h = h * 31 + hash(pt.get("explosiveness", 0.0))
		h = h * 31 + hash(pt.get("randomness", 0.0))
		h = h * 31 + hash(pt.get("one_shot", false))
	# Collision layers / mask on selected body
	var col: Variant = ctx.get("collision_snapshot", null)
	if typeof(col) == TYPE_DICTIONARY:
		h = h * 31 + hash(str(col.get("path", "")))
		h = h * 31 + hash(col.get("collision_layer", 0))
		h = h * 31 + hash(col.get("collision_mask", 0))
		h = h * 31 + hash(str(col.get("dimension", "")))
		h = h * 31 + hash(col.get("layer_names", []))
	var cv_item: Variant = ctx.get("canvas_item_snapshot", null)
	if typeof(cv_item) == TYPE_DICTIONARY:
		h = h * 31 + hash(str(cv_item.get("path", "")))
		h = h * 31 + hash(cv_item.get("visibility_layer", 0))
		h = h * 31 + hash(cv_item.get("light_mask", 0))
		h = h * 31 + hash(cv_item.get("layer_names", []))
	var vi_snap: Variant = ctx.get("visual_instance_snapshot", null)
	if typeof(vi_snap) == TYPE_DICTIONARY:
		h = h * 31 + hash(str(vi_snap.get("path", "")))
		h = h * 31 + hash(vi_snap.get("layers", 0))
		h = h * 31 + hash(vi_snap.get("layer_names", []))
	var tm_snap: Variant = ctx.get("tilemap_snapshot", null)
	if typeof(tm_snap) == TYPE_DICTIONARY:
		h = h * 31 + hash(bool(ctx.get("has_tilemap", false)))
		h = h * 31 + hash(str(tm_snap.get("path", "")))
		h = h * 31 + hash(tm_snap.get("current_layer", 0))
		h = h * 31 + hash(tm_snap.get("layer_count", 0))
		h = h * 31 + hash(str(tm_snap.get("active_tool", "")))
		h = h * 31 + hash(float(tm_snap.get("random_scatter", 0.0)))
		var tm_tb: Variant = tm_snap.get("toolbar", {})
		if typeof(tm_tb) == TYPE_DICTIONARY:
			var tb_keys: Array = (tm_tb as Dictionary).keys()
			tb_keys.sort()
			for tbk in tb_keys:
				h = h * 31 + hash(str(tbk))
				h = h * 31 + hash(bool((tm_tb as Dictionary)[tbk]))
		h = h * 31 + hash(tm_snap.get("layer_names", []))
	else:
		h = h * 31 + hash(bool(ctx.get("has_tilemap", false)))
	# AnimationPlayer snapshot
	var anim_snap: Variant = ctx.get("animation_snapshot", null)
	if typeof(anim_snap) == TYPE_DICTIONARY:
		h = h * 31 + hash(bool(ctx.get("has_animation", false)))
		h = h * 31 + hash(str(anim_snap.get("animation_name", "")))
		h = h * 31 + hash(bool(anim_snap.get("is_playing", false)))
		h = h * 31 + hash(int(anim_snap.get("loop_mode", 0)))
		h = h * 31 + hash(int(anim_snap.get("track_count", 0)))
		h = h * 31 + hash(int(anim_snap.get("selected_track", 0)))
		h = h * 31 + hash(anim_snap.get("animation_names", []))
		h = h * 31 + hash(float(anim_snap.get("position", 0.0)))
	else:
		h = h * 31 + hash(bool(ctx.get("has_animation", false)))
	# Include selected paths
	h = h * 31 + hash(ctx.get("selected_paths", []))
	h = h * 31 + hash(options.size())
	return h


func _on_poll_bridge_events() -> void:
	var events: Array = _MxBridge.read_and_clear_events()
	if events.is_empty():
		return
	_bus.apply_events(_ei(), get_undo_redo(), events, _main_screen,
		{"focused_inspector_prop": _focused_inspector_prop})

	var needs_refresh := false
	for ev in events:
		if str(ev.get("kind", "")) != "range_value":
			needs_refresh = true
			break
	if needs_refresh:
		_force_refresh()

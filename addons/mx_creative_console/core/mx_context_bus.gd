class_name MXContextBus
extends RefCounted
## Builds editor context, merges options from registered providers, dispatches inbound events.

const _RunHelper := preload("res://addons/mx_creative_console/core/mx_editor_run_helper.gd")
const _TileMapProvider := preload("res://addons/mx_creative_console/providers/tile_map_provider.gd")
const _AnimationProvider := preload("res://addons/mx_creative_console/providers/animation_provider.gd")
## Loaded here so this script compiles even if global load order fails.
const _SnapStateScript := preload("res://addons/mx_creative_console/core/mx_editor_snap_state_helper.gd")
## Render visibility: 20 slots (2D names: layer_names/2d_render; 3D: layer_names/3d_render).
## 3D: https://docs.godotengine.org/en/4.6/classes/class_visualinstance3d.html — set_layer_mask_value(layer 1–20).
const RENDER_LAYER_SLOT_COUNT := 20

var _providers: Array = []
var _snap_state_reader: RefCounted


func register_provider(provider: Variant) -> void:
	_providers.append(provider)
	_providers.sort_custom(func(a, b) -> bool: return a.priority > b.priority)


## [param main_screen] Tab name from [signal EditorPlugin.main_screen_changed] (e.g. "2D", "3D", "Script", "Game").
## Empty until the user switches main screen at least once after the plugin loads, or if the editor has not notified yet.
func build_context(editor: EditorInterface, main_screen: String = "", full_ui_poll: bool = true) -> Dictionary:
	var nodes := editor.get_selection().get_selected_nodes()
	var paths: PackedStringArray = []
	var classes: PackedStringArray = []
	var has_3d := false
	var has_2d := false
	var has_particles := false
	for n in nodes:
		paths.append(String(n.get_path()))
		classes.append(n.get_class())
		if n is Node3D:
			has_3d = true
		if n is Node2D:
			has_2d = true
		if n is GPUParticles3D or n is GPUParticles2D or n is CPUParticles3D or n is CPUParticles2D:
			has_particles = true
	var edited := editor.get_edited_scene_root()
	var scene_path := ""
	if edited and String(edited.scene_file_path) != "":
		scene_path = edited.scene_file_path
	var playing := editor.is_playing_scene()
	var ts_game := Engine.time_scale
	# Game tab speed uses the debugger path (user time scale); Engine.time_scale is the project/script multiplier.
	# Effective simulation speed is their product. GDScript historically only exposes time_scale; some builds add get_effective_time_scale().
	var ts_effective := ts_game
	if playing and Engine.has_method("get_effective_time_scale"):
		ts_effective = float(Engine.call("get_effective_time_scale"))
	var node3d_snapshot: Variant = null
	for n in nodes:
		if n is Node3D:
			var t := n as Node3D
			node3d_snapshot = {
				"path": str(n.get_path()),
				"position": [t.position.x, t.position.y, t.position.z],
				"rotation_deg": [
					rad_to_deg(t.rotation.x),
					rad_to_deg(t.rotation.y),
					rad_to_deg(t.rotation.z),
				],
				"scale_uniform": (t.scale.x + t.scale.y + t.scale.z) / 3.0,
				"visible": t.visible,
			}
			break
	var node2d_snapshot: Variant = null
	if node3d_snapshot == null:
		for n in nodes:
			if n is Node2D:
				var t2 := n as Node2D
				node2d_snapshot = {
					"path": str(n.get_path()),
					"position": [t2.position.x, t2.position.y, 0.0],
					"rotation_deg": [0.0, 0.0, rad_to_deg(t2.rotation)],
					"scale_uniform": (t2.scale.x + t2.scale.y) / 2.0,
					"visible": t2.visible,
				}
				break
	# ── GPU/CPU particles (2D & 3D) ─────────────────────────────────────────
	var particles_snapshot: Variant = null
	for n in nodes:
		if n is GPUParticles3D or n is GPUParticles2D or n is CPUParticles3D or n is CPUParticles2D:
			particles_snapshot = _particles_snapshot_dict(n)
			break
	# ── CollisionObject2D / CollisionObject3D (physics layers & mask) ─────
	var collision_snapshot: Variant = null
	var has_collision_object := false
	for n in nodes:
		if n is CollisionObject3D:
			var co3 := n as CollisionObject3D
			collision_snapshot = {
				"path": str(n.get_path()),
				"dimension": "3d",
				"collision_layer": int(co3.collision_layer),
				"collision_mask": int(co3.collision_mask),
				"layer_names": _physics_layer_names_3d(),
			}
			has_collision_object = true
			break
	if collision_snapshot == null:
		for n in nodes:
			if n is CollisionObject2D:
				var co2 := n as CollisionObject2D
				collision_snapshot = {
					"path": str(n.get_path()),
					"dimension": "2d",
					"collision_layer": int(co2.collision_layer),
					"collision_mask": int(co2.collision_mask),
					"layer_names": _physics_layer_names_2d(),
				}
				has_collision_object = true
				break
	# ── CanvasItem (2D): visibility_layer + light_mask ─────────────────────
	var canvas_item_snapshot: Variant = null
	var has_canvas_item := false
	for n in nodes:
		if n is CanvasItem:
			var ci := n as CanvasItem
			canvas_item_snapshot = {
				"path": str(n.get_path()),
				"visibility_layer": int(ci.visibility_layer),
				"light_mask": int(ci.light_mask),
				"layer_names": _render_layer_names_2d(),
			}
			has_canvas_item = true
			break
	# ── VisualInstance3D: render layers ────────────────────────────────────
	var visual_instance_snapshot: Variant = null
	var has_visual_instance_3d := false
	for n in nodes:
		if n is VisualInstance3D:
			var vi := n as VisualInstance3D
			visual_instance_snapshot = {
				"path": str(n.get_path()),
				"layers": int(vi.layers),
				"layer_names": _render_layer_names_3d(),
			}
			has_visual_instance_3d = true
			break
	# ── Script tab detection ──────────────────────────────────────────────
	var is_script_tab := main_screen == "Script" or main_screen == tr("Script")
	var script_file := ""
	if is_script_tab:
		var se := editor.get_script_editor()
		if se:
			var current := se.get_current_script()
			if current:
				script_file = current.resource_path
	var tm_ctx: Dictionary = _TileMapProvider.extend_context(editor, main_screen, nodes, full_ui_poll)
	var anim_ctx: Dictionary = _AnimationProvider.extend_context(editor, main_screen, nodes, full_ui_poll)
	var snap_ctx: Dictionary = {}
	if full_ui_poll:
		if _snap_state_reader == null:
			_snap_state_reader = _SnapStateScript.new() as RefCounted
		snap_ctx = _snap_state_reader.call("read_for_context", editor, main_screen) as Dictionary
	return {
		"main_screen": main_screen,
		"is_playing": playing,
		"playing_scene": editor.get_playing_scene() if playing else "",
		"runtime_paused": _RunHelper.get_runtime_paused(editor) if playing else false,
		"engine_time_scale": ts_game,
		"runtime_time_scale_effective": ts_effective,
		"has_node3d": has_3d,
		"has_node2d": has_2d and node2d_snapshot != null,
		"has_particles": has_particles,
		"is_script_tab": is_script_tab,
		"script_file": script_file,
		"selected_paths": paths,
		"selected_classes": classes,
		"scene_path": scene_path,
		"selected_nodes": nodes,
		"node3d_snapshot": node3d_snapshot,
		"node2d_snapshot": node2d_snapshot,
		"particles_snapshot": particles_snapshot,
		"has_collision_object": has_collision_object,
		"collision_snapshot": collision_snapshot,
		"has_canvas_item": has_canvas_item,
		"canvas_item_snapshot": canvas_item_snapshot,
		"has_visual_instance_3d": has_visual_instance_3d,
		"visual_instance_snapshot": visual_instance_snapshot,
		"has_tilemap": bool(tm_ctx.get("has_tilemap", false)),
		"tilemap_snapshot": tm_ctx.get("tilemap_snapshot", null),
		"has_animation": bool(anim_ctx.get("has_animation", false)),
		"animation_snapshot": anim_ctx.get("animation_snapshot", null),
		"canvas_smart_snap_active": bool(snap_ctx.get("canvas_smart_snap_active", false)),
		"canvas_grid_snap_active": bool(snap_ctx.get("canvas_grid_snap_active", false)),
		"spatial_snap_active": bool(snap_ctx.get("spatial_snap_active", false)),
	}


func _physics_layer_names_2d() -> Array:
	var out: Array = []
	for i in range(1, 33):
		var key := "layer_names/2d_physics/layer_%d" % i
		out.append(str(ProjectSettings.get_setting(key, "")))
	return out


func _physics_layer_names_3d() -> Array:
	var out: Array = []
	for i in range(1, 33):
		var key := "layer_names/3d_physics/layer_%d" % i
		out.append(str(ProjectSettings.get_setting(key, "")))
	return out


func _render_layer_names_2d() -> Array:
	var out: Array = []
	for i in range(1, RENDER_LAYER_SLOT_COUNT + 1):
		var key := "layer_names/2d_render/layer_%d" % i
		out.append(str(ProjectSettings.get_setting(key, "")))
	return out


func _render_layer_names_3d() -> Array:
	var out: Array = []
	for i in range(1, RENDER_LAYER_SLOT_COUNT + 1):
		var key := "layer_names/3d_render/layer_%d" % i
		out.append(str(ProjectSettings.get_setting(key, "")))
	return out


func _particles_snapshot_dict(n: Node) -> Dictionary:
	var supports_ratio := n is GPUParticles2D or n is GPUParticles3D
	var ar := 1.0
	if n is GPUParticles2D:
		ar = (n as GPUParticles2D).amount_ratio
	elif n is GPUParticles3D:
		ar = (n as GPUParticles3D).amount_ratio
	return {
		"path": str(n.get_path()),
		"emitting": n.emitting,
		"amount": n.amount,
		"amount_ratio": ar,
		"supports_amount_ratio": supports_ratio,
		"lifetime": n.lifetime,
		"speed_scale": n.speed_scale,
		"explosiveness": n.explosiveness,
		"randomness": n.randomness,
		"one_shot": n.one_shot,
	}


## First registered provider with higher priority wins per option id.
func collect_options(context: Dictionary) -> Array:
	var merged: Dictionary = {}
	var order: PackedStringArray = []
	for p in _providers:
		var opts: Array = p.build_options(context)
		for o in opts:
			if typeof(o) != TYPE_DICTIONARY:
				continue
			var id: String = str(o.get("id", ""))
			if id.is_empty():
				continue
			if not merged.has(id):
				merged[id] = o
				order.append(id)
	var out: Array = []
	for id in order:
		out.append(merged[id])
	return out


func apply_events(
	editor: EditorInterface,
	undo: EditorUndoRedoManager,
	events: Array,
	main_screen: String = "",
	extra_context: Dictionary = {},
) -> void:
	if events.is_empty():
			return
	## Build lean context once (skip heavy UI snapshotting) and reuse across all events in the batch.
	var ctx := build_context(editor, main_screen, false)
	ctx.merge(extra_context, true)
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		for p in _providers:
			if p.apply_event(ev, ctx, editor, undo):
				break

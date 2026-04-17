class_name MXBridge
extends RefCounted
## Bridge: context snapshot + inbound hardware events (HTTP loopback only).
## All communication goes through mx_bridge_service.gd (TCPServer on 127.0.0.1:17421).
## The file-based fallback (context.json / events.json) has been removed.

## Matches [VisualInstance3D] render layers (1–20) in Godot 4.6+.
const _RENDER_LAYER_SLOTS := 20
const _RENDER_LAYER_MASK := (1 << _RENDER_LAYER_SLOTS) - 1

## Set by the editor plugin — serves GET /context and queues POST /events.
static var _bridge_service: Node = null


static func register_bridge_service(node: Node) -> void:
	_bridge_service = node


static func unregister_bridge_service(node: Node) -> void:
	if _bridge_service == node:
		_bridge_service = null


# ── Snapshot serialization helpers ───────────────────────────────────────────

## Converts any array Variant to a plain string Array, optionally padded/trimmed to [target_size].
## Pass target_size = 0 to skip size normalization.
static func _sanitize_string_array(arr: Variant, target_size: int = 0) -> Array:
	var out: Array = []
	if typeof(arr) == TYPE_ARRAY or typeof(arr) == TYPE_PACKED_STRING_ARRAY:
		for nm in arr:
			out.append(str(nm))
	if target_size > 0:
		while out.size() < target_size:
			out.append("")
		if out.size() > target_size:
			out = out.slice(0, target_size)
	return out


static func _sanitize_node3d_snapshot(d: Dictionary) -> Dictionary:
	return {
		"path": str(d.get("path", "")),
		"position": d.get("position", [0.0, 0.0, 0.0]),
		"rotation_deg": d.get("rotation_deg", [0.0, 0.0, 0.0]),
		"scale_uniform": float(d.get("scale_uniform", 1.0)),
		"visible": bool(d.get("visible", true)),
	}


static func _sanitize_node2d_snapshot(d: Dictionary) -> Dictionary:
	return {
		"path": str(d.get("path", "")),
		"position": d.get("position", [0.0, 0.0, 0.0]),
		"rotation_deg": d.get("rotation_deg", [0.0, 0.0, 0.0]),
		"scale_uniform": float(d.get("scale_uniform", 1.0)),
		"visible": bool(d.get("visible", true)),
	}


static func _sanitize_particles_snapshot(d: Dictionary) -> Dictionary:
	return {
		"path": str(d.get("path", "")),
		"emitting": bool(d.get("emitting", false)),
		"amount": int(d.get("amount", 8)),
		"amount_ratio": float(d.get("amount_ratio", 1.0)),
		"supports_amount_ratio": bool(d.get("supports_amount_ratio", true)),
		"lifetime": float(d.get("lifetime", 1.0)),
		"speed_scale": float(d.get("speed_scale", 1.0)),
		"explosiveness": float(d.get("explosiveness", 0.0)),
		"randomness": float(d.get("randomness", 0.0)),
		"one_shot": bool(d.get("one_shot", false)),
	}


static func _sanitize_collision_snapshot(d: Dictionary) -> Dictionary:
	return {
		"path": str(d.get("path", "")),
		"dimension": str(d.get("dimension", "")),
		"collision_layer": int(d.get("collision_layer", 0)),
		"collision_mask": int(d.get("collision_mask", 0)),
		"layer_names": _sanitize_string_array(d.get("layer_names", []), 32),
	}


static func _sanitize_canvas_item_snapshot(d: Dictionary) -> Dictionary:
	return {
		"path": str(d.get("path", "")),
		"visibility_layer": int(d.get("visibility_layer", 0)) & _RENDER_LAYER_MASK,
		"light_mask": int(d.get("light_mask", 0)) & _RENDER_LAYER_MASK,
		"layer_names": _sanitize_string_array(d.get("layer_names", []), _RENDER_LAYER_SLOTS),
	}


static func _sanitize_visual_instance_snapshot(d: Dictionary) -> Dictionary:
	return {
		"path": str(d.get("path", "")),
		"layers": int(d.get("layers", 0)) & _RENDER_LAYER_MASK,
		"layer_names": _sanitize_string_array(d.get("layer_names", []), _RENDER_LAYER_SLOTS),
	}


static func _sanitize_tilemap_snapshot(d: Dictionary) -> Dictionary:
	var tb_out: Dictionary = {}
	var tb_in: Variant = d.get("toolbar", {})
	if typeof(tb_in) == TYPE_DICTIONARY:
		for k in (tb_in as Dictionary).keys():
			tb_out[str(k)] = bool((tb_in as Dictionary)[k])
	return {
		"path": str(d.get("path", "")),
		"tilemap_path": str(d.get("tilemap_path", "")),
		"current_layer": int(d.get("current_layer", 0)),
		"layer_count": int(d.get("layer_count", 0)),
		"layer_names": _sanitize_string_array(d.get("layer_names", [])),
		"active_tool": str(d.get("active_tool", "unknown")),
		"toolbar": tb_out,
		"random_scatter": float(d.get("random_scatter", 0.0)),
	}


static func _sanitize_animation_snapshot(d: Dictionary) -> Dictionary:
	return {
		"path": str(d.get("path", "")),
		"animation_name": str(d.get("animation_name", "")),
		"position": float(d.get("position", 0.0)),
		"length": float(d.get("length", 1.0)),
		"step": float(d.get("step", 1.0 / 60.0)),
		"is_playing": bool(d.get("is_playing", false)),
		"is_paused": bool(d.get("is_paused", false)),
		"loop": bool(d.get("loop", false)),
		"loop_mode": int(d.get("loop_mode", 0)),
		"track_count": int(d.get("track_count", 0)),
		"selected_track": int(d.get("selected_track", -1)),
		"track_names": _sanitize_string_array(d.get("track_names", [])),
		"animation_names": _sanitize_string_array(d.get("animation_names", [])),
	}


## Context subset safe to serialize (no Node references).
static func sanitize_context(context: Dictionary) -> Dictionary:
	var paths: Array = []
	for p in context.get("selected_paths", []):
		paths.append(str(p))
	var classes: Array = []
	for c in context.get("selected_classes", []):
		classes.append(str(c))

	var snap_in: Variant  = context.get("node3d_snapshot", null)
	var snap2_in: Variant = context.get("node2d_snapshot", null)
	var pt_in: Variant    = context.get("particles_snapshot", null)
	var col_in: Variant   = context.get("collision_snapshot", null)
	var cvi: Variant      = context.get("canvas_item_snapshot", null)
	var vii: Variant      = context.get("visual_instance_snapshot", null)
	var tm_in: Variant    = context.get("tilemap_snapshot", null)
	var anim_in: Variant  = context.get("animation_snapshot", null)

	return {
		"main_screen": str(context.get("main_screen", "")),
		"is_playing": bool(context.get("is_playing", false)),
		"playing_scene": str(context.get("playing_scene", "")),
		"runtime_paused": bool(context.get("runtime_paused", false)),
		"engine_time_scale": float(context.get("engine_time_scale", 1.0)),
		"runtime_time_scale_effective": float(
			context.get("runtime_time_scale_effective", context.get("engine_time_scale", 1.0))
		),
		"has_node3d": bool(context.get("has_node3d", false)),
		"has_node2d": bool(context.get("has_node2d", false)),
		"has_particles": bool(context.get("has_particles", false)),
		"is_script_tab": bool(context.get("is_script_tab", false)),
		"script_file": str(context.get("script_file", "")),
		"selected_paths": paths,
		"selected_classes": classes,
		"scene_path": str(context.get("scene_path", "")),
		"node3d_snapshot": _sanitize_node3d_snapshot(snap_in) if typeof(snap_in) == TYPE_DICTIONARY else null,
		"node2d_snapshot": _sanitize_node2d_snapshot(snap2_in) if typeof(snap2_in) == TYPE_DICTIONARY else null,
		"particles_snapshot": _sanitize_particles_snapshot(pt_in) if typeof(pt_in) == TYPE_DICTIONARY else null,
		"has_collision_object": bool(context.get("has_collision_object", false)),
		"collision_snapshot": _sanitize_collision_snapshot(col_in) if typeof(col_in) == TYPE_DICTIONARY else null,
		"has_canvas_item": bool(context.get("has_canvas_item", false)),
		"canvas_item_snapshot": _sanitize_canvas_item_snapshot(cvi) if typeof(cvi) == TYPE_DICTIONARY else null,
		"has_visual_instance_3d": bool(context.get("has_visual_instance_3d", false)),
		"visual_instance_snapshot": _sanitize_visual_instance_snapshot(vii) if typeof(vii) == TYPE_DICTIONARY else null,
		"has_tilemap": bool(context.get("has_tilemap", false)),
		"tilemap_snapshot": _sanitize_tilemap_snapshot(tm_in) if typeof(tm_in) == TYPE_DICTIONARY else null,
		"has_animation": bool(context.get("has_animation", false)),
		"animation_snapshot": _sanitize_animation_snapshot(anim_in) if typeof(anim_in) == TYPE_DICTIONARY else null,
		"canvas_smart_snap_active": bool(context.get("canvas_smart_snap_active", false)),
		"canvas_grid_snap_active": bool(context.get("canvas_grid_snap_active", false)),
		"spatial_snap_active": bool(context.get("spatial_snap_active", false)),
	}


static func write_snapshot(context: Dictionary, options: Array) -> void:
	var payload := {
		"schema": 2,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"context": sanitize_context(context),
		"options": options,
	}
	var json := JSON.stringify(payload)
	if _bridge_service and _bridge_service.has_method("set_snapshot_json"):
		_bridge_service.call("set_snapshot_json", json)


## Returns hardware-originated events from the HTTP bridge only.
static func read_and_clear_events() -> Array:
	if _bridge_service and _bridge_service.has_method("take_pending_events"):
		var from_http: Array = _bridge_service.call("take_pending_events") as Array
		if not from_http.is_empty():
			return from_http
	return []

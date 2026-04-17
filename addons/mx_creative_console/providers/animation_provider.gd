extends MXOptionProvider
class_name MXAnimationProvider
## AnimationPlayer: play/pause/stop, scrub timeline, insert key, loop toggle,
## new animation, new track, goto start/end, track selection (scroll / absolute pick).
##
## AnimationPlayer resolution order:
##   1. AnimationPlayerEditor.get_player()  ← most reliable (tracks editor selection)
##   2. Directly selected AnimationPlayer in the scene tree
##   3. AnimationPlayer ancestor of the selected node
##   4. AnimationPlayer as immediate child of the selected node

const GRP := "Animation"

const _TIMELINE_EDIT_CLASS := "AnimationTimelineEdit"
const _TRACK_EDIT_CLASS    := "AnimationTrackEdit"

const ID_PLAY         := "mx.anim.play"
const ID_PAUSE        := "mx.anim.pause"
const ID_STOP         := "mx.anim.stop"
const ID_GOTO_START   := "mx.anim.goto_start"
const ID_GOTO_END     := "mx.anim.goto_end"
const ID_PLAY_REVERSE := "mx.anim.play_reverse"
const ID_INSERT_KEY   := "mx.anim.insert_key"
const ID_NEW_ANIM     := "mx.anim.new_animation"
const ID_NEW_TRACK    := "mx.anim.new_track"
const ID_TOGGLE_LOOP  := "mx.anim.toggle_loop"
const ID_SCRUB         := "mx.anim.scrub"
const ID_TRACK_SCROLL  := "mx.anim.track_scroll"
const ID_TRACK_SELECT  := "mx.anim.track_select"
const ID_CLIP_SELECT   := "mx.anim.clip_select"
const ID_STEP_FORWARD  := "mx.anim.step_forward"
const ID_STEP_BACKWARD := "mx.anim.step_backward"

## Fallback when [member Animation.step] is 0 (Godot default for new anims is often 1/60 or project FPS).
const DEFAULT_ANIM_FRAME_STEP := 1.0 / 60.0
const _ANIM_EDITOR_CLASS  := "AnimationPlayerEditor"
const _TRACK_EDITOR_CLASS := "AnimationTrackEditor"

static var _selected_track: int = 0
## Cached AnimationPlayerEditor node (avoids re-scanning on every poll).
static var _cached_anim_editor: Node = null
## Cached seek SpinBox inside AnimationPlayerEditor's toolbar.
static var _cached_seek_spinbox: SpinBox = null
## Last animation name we knew was selected — survives stop().
static var _last_known_animation: String = ""
## Authoritative scrub/step position tracker.
## In Godot 4, ap.current_animation returns "" when paused (is_playing=false),
## so ap.current_animation_position is unreliable as a base for incremental moves.
## We maintain our own value, updated every time _seek_animation is called.
static var _tracked_position: float = 0.0


func _init() -> void:
	priority = 16


# ═══════════════════════════════════════════════════════════════════════════
#  Finding the active AnimationPlayer
# ═══════════════════════════════════════════════════════════════════════════

static func _find_animation_player(editor: EditorInterface) -> AnimationPlayer:
	var from_panel := _get_player_from_editor_panel(editor)
	if from_panel != null:
		return from_panel
	for n in editor.get_selection().get_selected_nodes():
		if n is AnimationPlayer:
			return n as AnimationPlayer
	var scene_root := editor.get_edited_scene_root()
	for n in editor.get_selection().get_selected_nodes():
		var p := n.get_parent()
		while p != null and p != scene_root:
			if p is AnimationPlayer:
				return p as AnimationPlayer
			p = p.get_parent()
	for n in editor.get_selection().get_selected_nodes():
		for child in n.get_children():
			if child is AnimationPlayer:
				return child as AnimationPlayer
	return null


static func _get_player_from_editor_panel(editor: EditorInterface) -> AnimationPlayer:
	var ae := _get_anim_editor_node(editor)
	if ae == null:
		return null
	if ae.has_method("get_player"):
		var p = ae.call("get_player")
		if p is AnimationPlayer:
			return p as AnimationPlayer
	return null


static func _get_anim_editor_node(editor: EditorInterface) -> Node:
	if is_instance_valid(_cached_anim_editor):
		return _cached_anim_editor
	var base := editor.get_base_control()
	if base == null:
		return null
	_cached_anim_editor = _find_node_by_class(base, _ANIM_EDITOR_CLASS, 30)
	return _cached_anim_editor


## Reads the currently selected animation from the AnimationPlayerEditor's OptionButton.
## This is the dropdown the user uses to switch animations even when stopped.
static func _get_editor_selected_anim(editor: EditorInterface, ap: AnimationPlayer) -> String:
	var ae := _get_anim_editor_node(editor)
	if ae == null:
		return ""
	# Find the OptionButton whose items include animation names from this player.
	var combo := _find_anim_combo(ae, ap, 6)
	if combo == null:
		return ""
	var sel := combo.selected
	if sel < 0 or sel >= combo.item_count:
		return ""
	var text := combo.get_item_text(sel)
	if ap.has_animation(text):
		return text
	return ""


static func _find_anim_combo(node: Node, ap: AnimationPlayer, depth: int) -> OptionButton:
	if depth <= 0:
		return null
	if node is OptionButton:
		var btn := node as OptionButton
		# Heuristic: verify at least one item matches an animation in this player.
		for i in range(min(btn.item_count, 8)):
			if ap.has_animation(btn.get_item_text(i)):
				return btn
	for child in node.get_children():
		var r := _find_anim_combo(child, ap, depth - 1)
		if r != null:
			return r
	return null


## Reads the timeline time (seconds) from the Animation panel seek SpinBox when available.
## That control is the same value the user sees; it updates when they scrub in the editor,
## so the HTTP bridge snapshot and Loupedeck stay aligned with Godot.
## Falls back to [method AnimationPlayer.current_animation_position] while an animation
## is active, then to [member _tracked_position] (last known from MX seeks).
static func _read_editor_timeline_seconds(editor: EditorInterface, ap: AnimationPlayer) -> float:
	var ae := _get_anim_editor_node(editor)
	if ae != null:
		var sb := _find_seek_spinbox(ae)
		if sb != null:
			return float(sb.value)
	if not ap.current_animation.is_empty():
		return ap.current_animation_position
	return _tracked_position


# ═══════════════════════════════════════════════════════════════════════════
#  Context extension
# ═══════════════════════════════════════════════════════════════════════════

static func extend_context(editor: EditorInterface, _main_screen: String, _nodes: Array, full_ui_poll: bool = true) -> Dictionary:
	var ap := _find_animation_player(editor)
	if ap == null:
		return {"has_animation": false, "animation_snapshot": null}

	var current := ap.current_animation

	# When stopped, ask the editor which animation is selected in the dropdown.
	if current.is_empty():
		current = _get_editor_selected_anim(editor, ap)

	# Fall back to last known, then first in list.
	if current.is_empty() and not _last_known_animation.is_empty() \
			and ap.has_animation(_last_known_animation):
		current = _last_known_animation
	if current.is_empty():
		var list: PackedStringArray = ap.get_animation_list()
		if list.size() > 0:
			current = list[0]
	if current.is_empty():
		return {"has_animation": false, "animation_snapshot": null}

	# Cache it for when the player is fully stopped.
	_last_known_animation = current

	var anim_res: Animation = null
	if ap.has_animation(current):
		anim_res = ap.get_animation(current)

	var is_loop := false
	var loop_mode := Animation.LOOP_NONE
	var track_count := 0
	# Avoid calling current_animation_length / current_animation_position when
	# no animation is assigned to the player — Godot prints engine errors for those.
	var anim_length: float = 0.0
	var track_names: Array = []
	if anim_res != null:
		loop_mode = anim_res.loop_mode
		is_loop = loop_mode != Animation.LOOP_NONE
		track_count = anim_res.get_track_count()
		anim_length = anim_res.length
		for i in range(track_count):
			track_names.append(str(anim_res.track_get_path(i)))

	# Time cursor: read from editor SpinBox (tracks manual scrub) + sync bridge tracker.
	var position: float = _read_editor_timeline_seconds(editor, ap)
	_tracked_position = position

	var anim_step: float = DEFAULT_ANIM_FRAME_STEP
	if anim_res != null:
		anim_step = _animation_frame_step_seconds(anim_res)

	var sel := clampi(_selected_track, 0, max(0, track_count - 1))
	var snap = null
	if full_ui_poll:
		snap = {
			"path": str(ap.get_path()),
			"animation_name": current,
			"position": position,
			"length": anim_length,
			"step": anim_step,
			"is_playing": ap.is_playing(),
			"is_paused": false,
			"loop": is_loop,
			"loop_mode": loop_mode,
			"track_count": track_count,
			"selected_track": sel,
			"track_names": track_names,
			"animation_names": ap.get_animation_list(),
		}

	return {
		"has_animation": true,
		"animation_snapshot": snap,
	}


# ═══════════════════════════════════════════════════════════════════════════
#  Options
# ═══════════════════════════════════════════════════════════════════════════

func build_options(context: Dictionary) -> Array:
	if not bool(context.get("has_animation", false)):
		return []
	var snap: Dictionary = context.get("animation_snapshot", {})
	var looping := int(snap.get("loop_mode", 0)) != Animation.LOOP_NONE
	var pos     := float(snap.get("position", 0.0))
	var length  := float(snap.get("length", 1.0))
	var step_sec := float(snap.get("step", DEFAULT_ANIM_FRAME_STEP))
	var tracks  := int(snap.get("track_count", 0))
	return [
		MXOption.trigger(ID_PLAY,         "Play",                    GRP),
		MXOption.trigger(ID_PAUSE,        "Pause",                   GRP),
		MXOption.trigger(ID_STOP,         "Stop",                    GRP),
		MXOption.trigger(ID_GOTO_START,   "Play from Start",         GRP),
		MXOption.trigger(ID_GOTO_END,     "Play Backwards from End", GRP),
		MXOption.trigger(ID_PLAY_REVERSE, "Play Reverse",            GRP),
		MXOption.trigger(ID_INSERT_KEY,   "Insert Key",      GRP),
		MXOption.trigger(ID_NEW_ANIM,     "New Animation",   GRP),
		MXOption.trigger(ID_NEW_TRACK,    "New Track",       GRP),
		MXOption.toggle(ID_TOGGLE_LOOP,   "Loop", looping,   GRP),
		MXOption.range_option(ID_SCRUB,        "Scrub Time",     0.0, maxf(length, 0.001), step_sec, pos, GRP),
		MXOption.range_option(ID_TRACK_SCROLL, "Selected Track", 0, max(0, tracks - 1), 1, _selected_track, GRP),
	]


# ═══════════════════════════════════════════════════════════════════════════
#  Event handling
# ═══════════════════════════════════════════════════════════════════════════

func apply_event(
	event: Dictionary,
	context: Dictionary,
	editor: EditorInterface,
	undo: EditorUndoRedoManager,
) -> bool:
	var id   := str(event.get("id",   ""))
	var kind := str(event.get("kind", ""))

	var ap := _find_animation_player(editor)
	if ap == null:
		return false

	match id:
		ID_PLAY:
			if kind == "trigger":
				var anim := _resolve_anim(ap, context, editor)
				if not anim.is_empty():
					ap.play(anim, 0.0)
				return true

		ID_PAUSE:
			if kind == "trigger":
				ap.pause()
				return true

		ID_STOP:
			if kind == "trigger":
				ap.stop(true)
				return true

		ID_GOTO_START:
			if kind == "trigger":
				var anim := _resolve_anim(ap, context, editor)
				if not anim.is_empty():
					# play() on a paused animation resumes from the current position,
					# so we must seek to 0 explicitly after setting up playback.
					ap.play(anim, 0.0)
					ap.seek(0.0, false)
				return true

		ID_GOTO_END:
			if kind == "trigger":
				var anim := _resolve_anim(ap, context, editor)
				if not anim.is_empty():
					var end := _anim_length(ap, anim, context)
					# play_backwards() on a paused animation resumes from current position,
					# so we must seek to the end explicitly.
					ap.play_backwards(anim, 0.0)
					ap.seek(end, false)
				return true

		ID_PLAY_REVERSE:
			if kind == "trigger":
				var anim := _resolve_anim(ap, context, editor)
				if not anim.is_empty():
					if ap.is_playing():
						ap.pause()
						return true
					var pos := _read_editor_timeline_seconds(editor, ap)
					# play() with speed=-1 / from_end=true starts at the end of the animation.
					# seek(pos, true) immediately repositions to the current scrub position
					# so reverse playback begins from where the user left the cursor.
					# update=true is required — update=false does not apply immediately.
					ap.play(anim, 0.0, -1.0, true)
					ap.seek(pos, true)
				return true

		ID_INSERT_KEY:
			if kind == "trigger":
				_insert_key_on_track(ap, context, editor, undo)
				return true

		ID_NEW_ANIM:
			if kind == "trigger":
				_open_new_animation_dialog(ap, editor, undo)
				return true

		ID_NEW_TRACK:
			if kind == "trigger":
				_open_add_track_menu(editor, ap, undo, context)
				return true

		ID_TOGGLE_LOOP:
			if kind == "trigger" or kind == "set_bool":
				var anim := _resolve_anim(ap, context, editor)
				if ap.has_animation(anim):
					var res := ap.get_animation(anim)
					var cur_loop := res.loop_mode
					var new_loop: int
					if typeof(event.get("value")) == TYPE_BOOL:
						new_loop = Animation.LOOP_LINEAR if bool(event.get("value")) else Animation.LOOP_NONE
					else:
						match int(cur_loop):
							Animation.LOOP_NONE:
								new_loop = Animation.LOOP_LINEAR
							Animation.LOOP_LINEAR:
								new_loop = Animation.LOOP_PINGPONG
							_:
								new_loop = Animation.LOOP_NONE
					undo.create_action("MX: Toggle Animation Loop")
					undo.add_do_property(res, "loop_mode", new_loop)
					undo.add_undo_property(res, "loop_mode", cur_loop)
					undo.commit_action()
				return true

		ID_SCRUB:
			if kind == "set_float" or kind == "set_int":
				var delta    := float(event.get("value", 0.0))
				var anim     := _resolve_anim(ap, context, editor)
				var anim_len := _anim_length(ap, anim, context)
				# Base = live editor time (SpinBox) so scrub stays aligned if the user moved the playhead in Godot.
				var base_pos := _read_editor_timeline_seconds(editor, ap)
				var frame_step := DEFAULT_ANIM_FRAME_STEP
				if ap.has_animation(anim):
					frame_step = _animation_frame_step_seconds(ap.get_animation(anim))
				var new_pos  := clampf(base_pos + delta * frame_step, 0.0, anim_len)
				_seek_animation(ap, anim, new_pos, editor)
				return true

		ID_TRACK_SELECT:
			if kind == "set_int":
				var idx := int(event.get("value", 0))
				var snap_d: Dictionary = context.get("animation_snapshot", {})
				var track_count := int(snap_d.get("track_count", 0))
				if track_count > 0:
					_selected_track = clampi(idx, 0, track_count - 1)
				return true

		ID_CLIP_SELECT:
			if kind == "set_int":
				var idx_clip := int(event.get("value", 0))
				_select_animation_clip_index(ap, editor, idx_clip)
				return true

		ID_TRACK_SCROLL:
			if kind == "set_float" or kind == "set_int":
				var delta := int(event.get("value", 0.0))
				var snap_d: Dictionary = context.get("animation_snapshot", {})
				var track_count := int(snap_d.get("track_count", 0))
				if track_count > 0:
					_selected_track = clampi(_selected_track + delta, 0, track_count - 1)
				return true

		ID_STEP_FORWARD, ID_STEP_BACKWARD:
			if kind == "trigger":
				var anim := _resolve_anim(ap, context, editor)
				if not anim.is_empty() and ap.has_animation(anim):
					var anim_res := ap.get_animation(anim)
					# Use the animation's own step size; fall back to 1/30 s (30 fps).
					var step := anim_res.step
					if step <= 0.0:
						step = DEFAULT_ANIM_FRAME_STEP
					var pos := _read_editor_timeline_seconds(editor, ap)
					var dir := 1.0 if id == ID_STEP_FORWARD else -1.0
					# snappedf aligns to the step grid so repeated presses stay on frame boundaries.
					var new_pos := snappedf(pos + dir * step, step)
					new_pos = clampf(new_pos, 0.0, anim_res.length)
					_seek_animation(ap, anim, new_pos, editor)
				return true

	return false


# ═══════════════════════════════════════════════════════════════════════════
#  Core helpers
# ═══════════════════════════════════════════════════════════════════════════

static func _select_animation_clip_index(ap: AnimationPlayer, editor: EditorInterface, idx: int) -> void:
	var list: PackedStringArray = ap.get_animation_list()
	if list.is_empty():
		return
	if idx < 0 or idx >= list.size():
		return
	var anim_name := str(list[idx])
	if anim_name.is_empty() or not ap.has_animation(anim_name):
		return
	_select_animation_clip_by_name(ap, editor, anim_name)


static func _select_animation_clip_by_name(ap: AnimationPlayer, editor: EditorInterface, anim_name: String) -> void:
	if anim_name.is_empty() or not ap.has_animation(anim_name):
		return
	_last_known_animation = anim_name
	editor.edit_node(ap)
	_sync_anim_combo_to_name(ap, editor, anim_name)
	var switching := ap.current_animation != anim_name
	if switching:
		ap.stop(true)
		_seek_animation(ap, anim_name, 0.0, editor)
	else:
		var t := _read_editor_timeline_seconds(editor, ap)
		_seek_animation(ap, anim_name, t, editor)


static func _sync_anim_combo_to_name(ap: AnimationPlayer, editor: EditorInterface, anim_name: String) -> void:
	var ae := _get_anim_editor_node(editor)
	if ae == null:
		return
	var combo := _find_anim_combo(ae, ap, 6)
	if combo == null:
		return
	for i in combo.item_count:
		if combo.get_item_text(i) == anim_name:
			combo.select(i)
			break


## Returns the most-specific animation name to act on.
static func _resolve_anim(ap: AnimationPlayer, context: Dictionary, editor: EditorInterface) -> String:
	# 1. Currently playing / paused animation.
	var current := ap.current_animation
	if not current.is_empty():
		return current
	# 2. Editor dropdown selection.
	var from_editor := _get_editor_selected_anim(editor, ap)
	if not from_editor.is_empty():
		return from_editor
	# 3. Last known.
	if not _last_known_animation.is_empty() and ap.has_animation(_last_known_animation):
		return _last_known_animation
	# 4. Context snapshot.
	var snap: Dictionary = context.get("animation_snapshot", {})
	var from_ctx := str(snap.get("animation_name", ""))
	if not from_ctx.is_empty() and ap.has_animation(from_ctx):
		return from_ctx
	# 5. First in list.
	var list: PackedStringArray = ap.get_animation_list()
	return list[0] if list.size() > 0 else ""


static func _anim_length(ap: AnimationPlayer, anim_name: String, context: Dictionary) -> float:
	if ap.has_animation(anim_name):
		return ap.get_animation(anim_name).length
	var snap: Dictionary = context.get("animation_snapshot", {})
	return float(snap.get("length", 1.0))


## One timeline step in seconds — matches the animation editor's snap (usually 1 frame).
static func _animation_frame_step_seconds(anim: Animation) -> float:
	if anim == null:
		return DEFAULT_ANIM_FRAME_STEP
	var s := anim.step
	return s if s > 0.0 else DEFAULT_ANIM_FRAME_STEP


## Seeks to [param pos] in [param anim_name] and updates the editor timeline cursor.
## If the animation is currently stopped (no current_animation), assigns it first
## via play()+pause() so seek() has a valid target and the viewport updates.
static func _seek_animation(
	ap: AnimationPlayer,
	anim_name: String,
	pos: float,
	editor: EditorInterface = null,
) -> void:
	if anim_name.is_empty() or not ap.has_animation(anim_name):
		return
	_tracked_position = pos   # Record before the seek so scrub/step always have a correct base
	if ap.current_animation.is_empty():
		# Assign the animation without triggering the blend-cache system.
		# custom_blend=0.0 means no blend transition → no "must have at least
		# one key to cache for blending" errors on empty tracks.
		#
		# ORDER MATTERS: play() resets position to 0. If we pause() before seek(),
		# the editor captures position=0 from the pause signal and gets stuck there.
		# Instead: play → seek (position=pos) → pause, so when pause fires the
		# position is already correct and the editor display won't show 0.
		ap.play(anim_name, 0.0)
		ap.seek(pos, true)
		ap.pause()
	else:
		ap.seek(pos, true)   # update=true → applies pose immediately
	# Push the new time into the editor's AnimationTimelineEdit so the blue
	# playhead line redraws even while paused (the editor only does this
	# automatically during active playback).
	if editor != null:
		_update_editor_playhead(editor, pos)


# ═══════════════════════════════════════════════════════════════════════════
#  Insert key on selected track
# ═══════════════════════════════════════════════════════════════════════════

func _insert_key_on_track(
	ap: AnimationPlayer,
	context: Dictionary,
	editor: EditorInterface,
	undo: EditorUndoRedoManager,
) -> void:
	var anim_name := _resolve_anim(ap, context, editor)
	if not ap.has_animation(anim_name):
		return

	var anim_res   := ap.get_animation(anim_name)
	var track_count := anim_res.get_track_count()
	if track_count == 0:
		return

	var track_idx   := clampi(_selected_track, 0, track_count - 1)
	var current_time: float = _read_editor_timeline_seconds(editor, ap)

	var track_type := anim_res.track_get_type(track_idx)
	var track_path := anim_res.track_get_path(track_idx)

	# Resolve node and property from the track path.
	# Track paths are relative to ap.root_node (defaults to ".." = AnimationPlayer's parent),
	# NOT relative to the AnimationPlayer itself. Using ap.get_node() directly would give
	# wrong results (e.g. "." would resolve to the AnimationPlayer, not the root scene node).
	var node_path_np := NodePath(track_path.get_concatenated_names())
	var prop_path    := track_path.get_concatenated_subnames()   # e.g. "position" or "visible"

	var root_node: Node = ap.get_node_or_null(ap.root_node)
	if root_node == null:
		root_node = ap.get_parent()
	if root_node == null:
		push_warning("[MX] anim: insert key — cannot resolve AnimationPlayer root node")
		return

	var target_node: Node = root_node.get_node_or_null(node_path_np)
	if target_node == null:
		push_warning("[MX] anim: insert key — node '%s' not found (root='%s')" \
			% [str(node_path_np), str(root_node.name)])
		return

	# Use has_method("get") as a safety check; also accept Variant type != NIL.
	# Note: get() can legitimately return null for Object-type properties, so we
	# verify the property name exists via get_property_list() before rejecting.
	var current_value = target_node.get(prop_path)
	if current_value == null:
		var has_prop := false
		for pd: Dictionary in target_node.get_property_list():
			if pd.get("name", "") == prop_path:
				has_prop = true
				break
		if not has_prop:
			push_warning("[MX] anim: insert key — property '%s' not found on %s" \
				% [prop_path, target_node.name])
			return


	match track_type:
		Animation.TYPE_VALUE:
			undo.create_action("MX: Insert Value Key")
			undo.add_do_method(anim_res, "track_insert_key", track_idx, current_time, current_value, 1.0)
			undo.add_undo_method(anim_res, "track_remove_key_at_time", track_idx, current_time)
			undo.commit_action()

		Animation.TYPE_BEZIER:
			undo.create_action("MX: Insert Bezier Key")
			undo.add_do_method(anim_res, "bezier_track_insert_key", track_idx, current_time, float(current_value))
			undo.add_undo_method(anim_res, "track_remove_key_at_time", track_idx, current_time)
			undo.commit_action()

		Animation.TYPE_ROTATION_3D:
			undo.create_action("MX: Insert Rotation Key")
			undo.add_do_method(anim_res, "rotation_track_insert_key", track_idx, current_time, current_value)
			undo.add_undo_method(anim_res, "track_remove_key_at_time", track_idx, current_time)
			undo.commit_action()

		Animation.TYPE_POSITION_3D:
			undo.create_action("MX: Insert Position Key")
			undo.add_do_method(anim_res, "position_track_insert_key", track_idx, current_time, current_value)
			undo.add_undo_method(anim_res, "track_remove_key_at_time", track_idx, current_time)
			undo.commit_action()

		Animation.TYPE_SCALE_3D:
			undo.create_action("MX: Insert Scale Key")
			undo.add_do_method(anim_res, "scale_track_insert_key", track_idx, current_time, current_value)
			undo.add_undo_method(anim_res, "track_remove_key_at_time", track_idx, current_time)
			undo.commit_action()

		_:
			push_warning("[MX] anim: insert key not supported for track type %d" % track_type)


# ═══════════════════════════════════════════════════════════════════════════
#  New Track — opens the AnimationTrackEditor's "Add Track" menu
# ═══════════════════════════════════════════════════════════════════════════

## Imported glTF/GLB/FBX data is tied to the importer; the editor shows a banner / dialog when
## [method Animation.track_is_imported] is true on any track. A duplicate alone still copies those
## flags — [AnimationTrackEditor] only hides the warning when no track is imported
## (see Godot AnimationTrackEditor::set_animation). We clear imported flags on the duplicate so
## MX-driven edits match a normal scene-owned animation.
func _ensure_animation_local_for_custom_tracks(
	ap: AnimationPlayer,
	anim_name: String,
	undo: EditorUndoRedoManager,
) -> void:
	if anim_name.is_empty() or not ap.has_animation(anim_name):
		return
	var anim: Animation = ap.get_animation(anim_name)
	if not _animation_should_localize_for_scene_edits(anim):
		return
	# Default library key is "" — do not use StringName emptiness as "not found".
	var lib: AnimationLibrary = null
	for k in ap.get_animation_library_list():
		var candidate: AnimationLibrary = ap.get_animation_library(k)
		if candidate.has_animation(anim_name):
			lib = candidate
			break
	if lib == null:
		push_warning("[MX] anim: could not find library for '%s'" % anim_name)
		return
	var dup := anim.duplicate(true) as Animation
	if dup == null:
		push_warning("[MX] anim: duplicate() failed for '%s'" % anim_name)
		return
	# Ensure the copy is treated as owned by the scene, not the importer file.
	if dup.resource_path != "":
		dup.resource_path = ""
	for ti in range(dup.get_track_count()):
		if dup.track_is_imported(ti):
			dup.track_set_imported(ti, false)
	undo.create_action("MX: Localize animation for custom tracks")
	undo.add_do_method(lib, "add_animation", anim_name, dup)
	undo.add_undo_method(lib, "add_animation", anim_name, anim)
	undo.commit_action()


static func _animation_should_localize_for_scene_edits(anim: Animation) -> bool:
	if _animation_resource_path_is_external_model_file(anim):
		return true
	for ti in range(anim.get_track_count()):
		if anim.track_is_imported(ti):
			return true
	return false


static func _animation_resource_path_is_external_model_file(anim: Animation) -> bool:
	var rp := anim.resource_path
	if rp.is_empty():
		return false
	var lower := rp.to_lower()
	if ".gltf" in lower or ".glb" in lower or ".fbx" in lower or ".dae" in lower:
		return true
	if "::" in rp:
		var base := rp.split("::")[0]
		var lb := base.to_lower()
		return ".gltf" in lb or ".glb" in lb or ".fbx" in lb or ".dae" in lb
	return false


func _open_add_track_menu(
	editor: EditorInterface,
	ap: AnimationPlayer,
	undo: EditorUndoRedoManager,
	context: Dictionary,
) -> void:
	var anim_name := _resolve_anim(ap, context, editor)
	_ensure_animation_local_for_custom_tracks(ap, anim_name, undo)

	# So AnimationPlayerEditor::get_player() matches [param ap] inside editor code paths
	# (see AnimationTrackEditor::_add_track in the engine).
	editor.edit_node(ap)

	var ae := _get_anim_editor_node(editor)
	if ae == null:
		push_warning("[MX] anim: AnimationPlayerEditor not found")
		return

	var track_editor := _find_node_by_class(ae, _TRACK_EDITOR_CLASS, 20)
	if track_editor == null:
		push_warning("[MX] anim: AnimationTrackEditor not found inside AnimationPlayerEditor")
		return

	# Open the same dropdown as the (+) "Add Track" MenuButton (Property / 3D / Bezier / …).
	# Do NOT call AnimationTrackEditor._add_track() or emit index_pressed — that skips the menu and
	# jumps straight into "Property Track" node picking.
	var mb := _find_timeline_add_track_menubutton(track_editor)
	if mb == null:
		mb = _find_toolbar_menu_button(track_editor, 10)
	if mb != null:
		var popup := mb.get_popup()
		mb.call_deferred("show_popup")
		call_deferred("_select_first_add_track_item", popup)
		return

	# Fallback: engine build without MenuButton (unlikely): direct Property Track flow.
	if track_editor.has_method("_add_track"):
		track_editor.call("_add_track", Animation.TYPE_VALUE)
		return

	var plain_btn := _find_first_add_track_button(track_editor, 8)
	if plain_btn != null:
		plain_btn.emit_signal("pressed")
		return

	push_warning("[MX] anim: could not find any Add Track control in AnimationTrackEditor")
	_debug_print_children(track_editor, 3)


## Godot's [code]AnimationTimelineEdit[/code] puts the (+) Add Track control as the first
## [MenuButton] inside the first toolbar [HBoxContainer] ([code]animation_timeline_edit.cpp[/code]).
static func _find_timeline_add_track_menubutton(anim_track_editor: Node) -> MenuButton:
	var timeline := _find_node_by_class(anim_track_editor, _TIMELINE_EDIT_CLASS, 22)
	if timeline == null:
		return null
	for child in timeline.get_children():
		if child is HBoxContainer:
			for c in child.get_children():
				if c is MenuButton:
					return c as MenuButton
	return null


func _select_first_add_track_item(popup: PopupMenu) -> void:
	if popup == null or not is_instance_valid(popup):
		return
	if popup.item_count <= 0:
		return
	# Open menu behavior, then activate first entry (Property Track).
	popup.emit_signal("index_pressed", 0)


static func _debug_print_children(node: Node, depth: int, prefix: String = "") -> void:
	if depth <= 0:
		return
	for child in node.get_children():
		_debug_print_children(child, depth - 1, prefix + "  ")


## Finds the first non-MenuButton Button in [param node]'s subtree at shallow depth.
## Used as a fallback for Godot builds where "Add Track" became a plain Button.
static func _find_first_add_track_button(node: Node, depth: int) -> Button:
	if depth <= 0:
		return null
	# Accept Button but NOT MenuButton (which is a subclass of Button).
	if node is Button and not (node is MenuButton) and not (node is CheckButton) \
			and not (node is CheckBox) and not (node is OptionButton):
		return node as Button
	for child in node.get_children():
		var r := _find_first_add_track_button(child, depth - 1)
		if r != null:
			return r
	return null


## Like _find_first_menu_button but skips AnimationTrackEdit subtrees.
## Used to find the toolbar "Add Track" MenuButton without accidentally picking up
## the per-row "..." option MenuButtons that live inside AnimationTrackEdit nodes.
static func _find_toolbar_menu_button(node: Node, depth: int) -> MenuButton:
	if depth <= 0:
		return null
	if node.get_class() == _TRACK_EDIT_CLASS:
		return null   # Don't descend into track rows
	if node is MenuButton:
		return node as MenuButton
	for child in node.get_children():
		var r := _find_toolbar_menu_button(child, depth - 1)
		if r != null:
			return r
	return null


static func _find_first_menu_button(node: Node, depth: int) -> MenuButton:
	if depth <= 0:
		return null
	if node is MenuButton:
		return node as MenuButton
	for child in node.get_children():
		var r := _find_first_menu_button(child, depth - 1)
		if r != null:
			return r
	return null


# ═══════════════════════════════════════════════════════════════════════════
#  New Animation dialog
# ═══════════════════════════════════════════════════════════════════════════

func _open_new_animation_dialog(ap: AnimationPlayer, editor: EditorInterface, undo: EditorUndoRedoManager) -> void:
	# Attempt 1: use the editor's built-in dialog.
	var ae := _get_anim_editor_node(editor)
	if ae != null and ae.has_method("_animation_new"):
		ae.call("_animation_new")
		return
	# Attempt 2: custom dialog.
	call_deferred("_show_new_anim_dialog_deferred", ap, editor, undo)


func _show_new_anim_dialog_deferred(ap: AnimationPlayer, editor: EditorInterface, undo: EditorUndoRedoManager) -> void:
	if not is_instance_valid(ap):
		return
	var base_name := "NewAnimation"
	var i := 0
	var anim_name := base_name
	while ap.has_animation(anim_name):
		i += 1
		anim_name = "%s%d" % [base_name, i]

	var dialog := ConfirmationDialog.new()
	dialog.title = "New Animation"
	dialog.ok_button_text = "Create"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = "Animation name:"
	vbox.add_child(lbl)

	var input := LineEdit.new()
	input.text = anim_name
	input.select_all_on_focus = true
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(input)

	dialog.add_child(vbox)
	dialog.min_size = Vector2i(320, 90)
	editor.get_base_control().add_child(dialog)
	dialog.popup_centered()
	input.call_deferred("grab_focus")
	input.call_deferred("select_all")

	await dialog.confirmed
	if not is_instance_valid(ap):
		dialog.queue_free()
		return
	var final_name := input.text.strip_edges()
	if not final_name.is_empty() and not ap.has_animation(final_name):
		_create_named_animation(ap, final_name, undo)
	dialog.queue_free()


func _create_named_animation(ap: AnimationPlayer, anim_name: String, undo: EditorUndoRedoManager) -> void:
	var new_anim := Animation.new()
	new_anim.length = 1.0
	if not ap.has_animation_library(""):
		var lib := AnimationLibrary.new()
		undo.create_action("MX: Add Default Animation Library")
		undo.add_do_method(ap, "add_animation_library", "", lib)
		undo.add_undo_method(ap, "remove_animation_library", "")
		undo.commit_action()
	var library: AnimationLibrary = ap.get_animation_library("")
	undo.create_action("MX: New Animation '%s'" % anim_name)
	undo.add_do_method(library, "add_animation", anim_name, new_anim)
	undo.add_undo_method(library, "remove_animation", anim_name)
	undo.commit_action()


# ═══════════════════════════════════════════════════════════════════════════
#  Editor playhead update
# ═══════════════════════════════════════════════════════════════════════════

## Updates the AnimationPlayerEditor's blue playhead line and time display to [param pos].
##
## Godot only auto-moves the cursor while actively playing.
## We update manually after every seek/step/scrub so the user sees the blue line move.
##
## Strategy order:
##   1. Set the seek SpinBox value — triggers _seek_value_changed (official Godot path)
##      which updates the time display, ruler, and all track row playheads at once.
##   2. Fallback: push pos directly to each AnimationTrackEdit row (set_play_position
##      IS bound in Godot 4 ClassDB for AnimationTrackEdit; NOT for AnimationTimelineEdit).
static func _update_editor_playhead(editor: EditorInterface, pos: float) -> void:
	var ae := _get_anim_editor_node(editor)
	if ae == null:
		return

	# Strategy 1 — seek SpinBox (most complete: updates time display + ruler + track rows).
	var seek_spin := _find_seek_spinbox(ae)
	if seek_spin != null:
		# Setting .value emits value_changed → C++ _seek_value_changed() which calls
		# player->seek_delta() again (idempotent) and updates the full editor display.
		# If the player is actively playing, _seek_value_changed returns early but the
		# SpinBox number display still updates — which is exactly what we want.
		seek_spin.value = pos
		return

	# Strategy 2 — direct per-row update.
	# AnimationTrackEdit.set_play_position IS bound to ClassDB in Godot 4.
	# AnimationTimelineEdit.set_play_position is NOT bound in all builds (guard with has_method).
	_find_and_set_play_position(ae, _TRACK_EDIT_CLASS, pos, 15)
	var timeline_edit := _find_node_by_class(ae, _TIMELINE_EDIT_CLASS, 15)
	if timeline_edit != null:
		if timeline_edit.has_method("set_play_position"):
			timeline_edit.call("set_play_position", pos)
		else:
			timeline_edit.queue_redraw()


## Finds the seek SpinBox in AnimationPlayerEditor's own toolbar.
## Searches all children of [param ae] except AnimationTrackEditor (to avoid picking up
## unrelated SpinBoxes inside the track editing controls).
static func _find_seek_spinbox(ae: Node) -> SpinBox:
	if is_instance_valid(_cached_seek_spinbox):
		return _cached_seek_spinbox
	for child in ae.get_children():
		# Skip AnimationTrackEditor — its subtree may contain unrelated SpinBoxes.
		if child.get_class() == _TRACK_EDITOR_CLASS:
			continue
		var sb := _find_first_spinbox(child, 5)
		if sb != null:
			_cached_seek_spinbox = sb
			return sb
	return null


static func _find_first_spinbox(node: Node, depth: int) -> SpinBox:
	if depth <= 0:
		return null
	if node is SpinBox:
		return node as SpinBox
	for child in node.get_children():
		var r := _find_first_spinbox(child, depth - 1)
		if r != null:
			return r
	return null


## Calls set_play_position(pos) on every node of [param target_class] in the tree,
## then queues a redraw so the new position is painted immediately.
static func _find_and_set_play_position(node: Node, target_class: String, pos: float, depth: int) -> void:
	if depth <= 0:
		return
	if node.get_class() == target_class:
		if node.has_method("set_play_position"):
			node.call("set_play_position", pos)
		node.queue_redraw()
	for child in node.get_children():
		_find_and_set_play_position(child, target_class, pos, depth - 1)


# ═══════════════════════════════════════════════════════════════════════════
#  Generic node-tree helpers
# ═══════════════════════════════════════════════════════════════════════════

static func _find_node_by_class(node: Node, target_class: String, max_depth: int) -> Node:
	if max_depth <= 0:
		return null
	if node.get_class() == target_class:
		return node
	for child in node.get_children():
		var r := _find_node_by_class(child, target_class, max_depth - 1)
		if r != null:
			return r
	return null

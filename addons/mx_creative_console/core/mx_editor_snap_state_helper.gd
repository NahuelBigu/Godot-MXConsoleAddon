class_name MXEditorSnapStateHelper
extends RefCounted
## Reads pressed state of Smart Snap / Grid Snap (2D) and Use Snap (3D) toggles
## by inspecting the editor toolbar (same theme icons [code]Snap[/code] / [code]SnapGrid[/code]).


const ED_ICONS := &"EditorIcons"


## [param main_screen] Current tab ([signal EditorPlugin.main_screen_changed]) to prioritize the correct viewport.
func read_for_context(editor: EditorInterface, main_screen: String = "") -> Dictionary:
	var smart := false
	var grid := false
	var spatial := false
	var th := editor.get_editor_theme()
	if th == null:
		return _pack(smart, grid, spatial)
	var snap_tex: Texture2D = th.get_icon("Snap", ED_ICONS)
	var grid_tex: Texture2D = th.get_icon("SnapGrid", ED_ICONS)
	if snap_tex == null or grid_tex == null:
		return _pack(smart, grid, spatial)
	var base := editor.get_base_control()
	if base == null:
		return _pack(smart, grid, spatial)
	var cur := editor.get_editor_main_screen()
	var msl := main_screen.strip_edges().to_lower()
	## Prioritize active-tab tree (fewer "ghost" buttons from other views).
	var root_2d: Node = base
	var root_3d: Node = base
	if cur != null:
		if msl == "2d":
			root_2d = cur
		if msl == "3d":
			root_3d = cur
	var grid_btn := _find_toggle_with_icon(root_2d, grid_tex)
	if grid_btn == null and root_2d != base:
		grid_btn = _find_toggle_with_icon(base, grid_tex)
	if grid_btn != null:
		grid = grid_btn.button_pressed
		var parent := grid_btn.get_parent()
		if parent:
			var smart_btn := _find_toggle_snap_on_row(parent, snap_tex, grid_tex)
			if smart_btn != null:
				smart = smart_btn.button_pressed
	var spatial_btn := _find_spatial_use_snap_toggle(root_3d, snap_tex, grid_tex)
	if spatial_btn == null and root_3d != base:
		spatial_btn = _find_spatial_use_snap_toggle(base, snap_tex, grid_tex)
	if spatial_btn != null:
		spatial = spatial_btn.button_pressed
	return _pack(smart, grid, spatial)


func _pack(smart: bool, grid: bool, spatial: bool) -> Dictionary:
	return {
		"canvas_smart_snap_active": smart,
		"canvas_grid_snap_active": grid,
		"spatial_snap_active": spatial,
	}


func _find_toggle_with_icon(n: Node, want: Texture2D) -> Button:
	if n is Button:
		var b := n as Button
		if b.toggle_mode and b.icon != null and b.icon == want:
			return b
	for c in n.get_children():
		var f := _find_toggle_with_icon(c, want)
		if f != null:
			return f
	return null


## 2D row: one [Button] with Snap icon (smart) next to SnapGrid.
func _find_toggle_snap_on_row(parent: Node, snap_tex: Texture2D, grid_tex: Texture2D) -> Button:
	for c in parent.get_children():
		if c is Button:
			var b := c as Button
			if b.toggle_mode and b.icon == snap_tex:
				return b
	return null


## 3D: Snap-icon toggle whose row (same parent) does not include SnapGrid.
func _find_spatial_use_snap_toggle(root: Node, snap_tex: Texture2D, grid_tex: Texture2D) -> Button:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is Button:
			var b := n as Button
			if b.toggle_mode and b.icon == snap_tex:
				var p := b.get_parent()
				if p != null and not _row_has_toggle_with_icon(p, grid_tex):
					return b
		for c in n.get_children():
			stack.append(c)
	return null


func _row_has_toggle_with_icon(parent: Node, icon: Texture2D) -> bool:
	for c in parent.get_children():
		if c is Button:
			var bb := c as Button
			if bb.icon == icon:
				return true
	return false

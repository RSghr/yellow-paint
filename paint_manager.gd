class_name PaintManager
extends Node3D
## Owns every yellow paint splat in the level.
## Splats on upward-facing surfaces become navigation points the AI runner will trust blindly.

signal paint_changed
signal splat_added(mark: PaintMark)
signal paint_denied  ## Tried to paint with an empty can.
signal scrape_denied  ## Tried to scrape while scraping is locked (during a playtest).
signal hotfix_mode_changed(on: bool)

@export var nav_merge_radius := 0.8  ## Splats closer than this to an existing nav point don't add a new one.
@export var scrape_radius := 1.0
@export var floor_min_normal_y := 0.7  ## How flat a surface must be to count as "walkable" paint.
@export var splat_texture: Texture2D = preload("res://art/paint_splat.png")  ## White image, tinted by paint_color. Swap the file for your spray image.
@export var paint_color := Color(1.0, 0.82, 0.05)
@export var hotfix_color := Color(0.9, 0.1, 0.08)  ## Hotfix splats (and the can in Hotfix mode) so you can see what you patched.

@export var paint_limit := -1  ## Max splats on the level at once. -1 = unlimited. Set by the level.

## While true, paint can still be added but not scraped or cleared (no refunds mid-playtest).
var scrape_locked := false

## True during a playtest: new splats are flagged as hotfixes. They ignore the paint limit, don't
## count in splats_used (they're scored separately) and are removed on reset.
var hotfix_mode := false:
	set(v):
		if v == hotfix_mode:
			return
		hotfix_mode = v
		hotfix_mode_changed.emit(v)

## Splats currently "spent". Scraping refunds; paint lost to smashed planks or opened doors doesn't.
var splats_used := 0
var _stashed: Array[PaintMark] = []  ## Paint on objects that broke/opened this run (see remove_marks_on).

static var _splat_texture: ImageTexture


func _ready() -> void:
	add_to_group("paint_manager")


## Spray a splat. `collider` is what was hit, so interactables can say what the paint means.
func paint(hit_position: Vector3, hit_normal: Vector3, collider: Object = null) -> PaintMark:
	# Hotfixes (painted during a playtest) come from outside the can: no limit, not in splats_used.
	if not hotfix_mode:
		if not can_paint():
			paint_denied.emit()
			return null
		splats_used += 1
	var host := _find_interactable(collider)
	var role: String
	if host:
		role = host.paint_role(hit_normal)  # e.g. side of a crate = "interact", top = "nav"
	else:
		role = "nav" if hit_normal.y >= floor_min_normal_y else "none"
	var is_nav := role == "nav" and _nearest_nav(hit_position, nav_merge_radius, host) == null

	var mark := PaintMark.new()
	add_child(mark)
	mark.global_position = hit_position
	mark.normal = hit_normal
	mark.role = role
	mark.host = host
	mark.is_nav = is_nav
	mark.is_floor = role == "nav"
	mark.stand_point = _safe_stand_point(hit_position) if is_nav else hit_position
	if role == "interact":
		mark.interact_point = host.interact_point(hit_position, hit_normal)
	mark.hotfix = hotfix_mode
	if host and host.has_method("carries_paint") and host.carries_paint():
		mark.attach_to(host)  # Moving platform: the paint rides along.
	mark.build_visual(hit_normal, splat_texture if splat_texture else _get_splat_texture(),
		hotfix_color if hotfix_mode else paint_color)
	splat_added.emit(mark)
	paint_changed.emit()
	return mark


## Remove the paint on something (it broke, or a door slid away).
## The paint on something that just broke or opened (planks, a door) is put aside, not deleted: it's gone for
## the rest of this run, but it comes back with the object on reset (restore_stashed), so splats_used stays right.
func remove_marks_on(host: Node) -> void:
	var removed := false
	for mark in get_marks():
		if mark.host == host:
			remove_child(mark)
			_stashed.append(mark)
			removed = true
	if removed:
		paint_changed.emit()


## Reset (R / next tester): the paint that went away with broken or opened objects comes back.
## Hotfixes among them are dropped, like every other hotfix.
func restore_stashed() -> void:
	if _stashed.is_empty():
		return
	for mark in _stashed:
		if mark.hotfix:
			mark.free()
		else:
			add_child(mark)
	_stashed.clear()
	paint_changed.emit()


func _exit_tree() -> void:
	for mark in _stashed:
		mark.free()
	_stashed.clear()


func _find_interactable(collider: Object) -> Node:
	var node := collider as Node
	while node:
		if node.is_in_group("interactable"):
			return node
		node = node.get_parent()
	return null


func can_paint() -> bool:
	return paint_limit < 0 or splats_used < paint_limit


func paint_left() -> int:
	return -1 if paint_limit < 0 else paint_limit - splats_used


## Remove all paint near a point (the scraper / right click). Free undo: the paint goes back in the can.
func scrape(hit_position: Vector3) -> int:
	if scrape_locked:
		scrape_denied.emit()
		return 0
	var removed := 0
	for mark: PaintMark in get_marks():
		if mark.global_position.distance_to(hit_position) <= scrape_radius:
			mark.queue_free()
			remove_child(mark)
			removed += 1
	if removed > 0:
		splats_used = maxi(splats_used - removed, 0)
		paint_changed.emit()
	return removed


## Remove every hotfix splat (on reset). They were never in splats_used, so nothing is refunded.
func remove_hotfixes() -> void:
	var removed := false
	for mark in get_marks():
		if mark.hotfix:
			mark.queue_free()
			remove_child(mark)
			removed = true
	if removed:
		paint_changed.emit()


func clear_all() -> void:
	if scrape_locked:
		scrape_denied.emit()
		return
	for mark in get_marks():
		mark.queue_free()
		remove_child(mark)
	for mark in _stashed:
		mark.free()
	_stashed.clear()
	splats_used = 0
	paint_changed.emit()


func get_marks() -> Array[PaintMark]:
	var result: Array[PaintMark] = []
	for child in get_children():
		if child is PaintMark:
			result.append(child)
	return result


## Points on the ground the runner is allowed to go to.
func nav_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for mark in get_marks():
		if mark.is_nav:
			result.append(mark.stand_point)
	return result


## `host`: paint on a moving platform only merges with paint on the same platform (and vice versa).
func _nearest_nav(pos: Vector3, max_dist: float, host: Node = null) -> PaintMark:
	var best: PaintMark = null
	var best_d := max_dist
	for mark in get_marks():
		if not mark.is_nav:
			continue
		if mark.host != host and (mark.follows() or (host and host.has_method("carries_paint") and host.carries_paint())):
			continue
		var d := mark.global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = mark
	return best


## Paint on the very lip of a ledge would make the runner stand half in the void.
## Nudge the standing point away from any nearby drop.
func _safe_stand_point(pos: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var missing := Vector3.ZERO
	var missing_count := 0
	for i in 8:
		var angle := TAU * i / 8.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		if _ground_y(space, pos + dir * 0.6, pos.y) == null:
			missing += dir
			missing_count += 1
	if missing_count == 0 or missing_count == 8:
		return pos
	var shifted := pos - missing.normalized() * 0.5
	var y = _ground_y(space, shifted, pos.y)
	if y != null:
		shifted.y = y
	return shifted


func _ground_y(space: PhysicsDirectSpaceState3D, pos: Vector3, ref_y: float) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, ref_y + 0.5, pos.z), Vector3(pos.x, ref_y - 0.5, pos.z), 1)
	var hit := space.intersect_ray(query)
	return hit.position.y if hit else null


## Fallback if no splat image is set: a procedural lumpy white blob with soft edges.
static func _get_splat_texture() -> ImageTexture:
	if _splat_texture:
		return _splat_texture
	var res := 64
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 3.0
	var c := Vector2(res, res) * 0.5
	for y in res:
		for x in res:
			var p := (Vector2(x, y) - c) / (res * 0.5)
			var ang := p.angle()
			var radius := 0.7 + 0.18 * noise.get_noise_2d(cos(ang), sin(ang))
			var a := clampf((radius - p.length()) * 12.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_splat_texture = ImageTexture.create_from_image(img)
	return _splat_texture

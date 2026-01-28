extends Node2D

@export var mask_path: String = ""
@export var epsilon: float = 2.0

# When set, we align the collision geometry to this Sprite2D (typically the map background).
@export var sprite_path: NodePath

func polygons_from_mask() -> Array:
	if mask_path.strip_edges() == "":
		return []
	var tex := load(mask_path) as Texture2D
	if tex == null:
		return []
	var img := tex.get_image()
	if img == null:
		return []
	return _polygons_from_image(img)

func rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var polys := polygons_from_mask()
	if polys.is_empty():
		return

	_align_to_sprite()

	var body := StaticBody2D.new()
	body.name = "StaticBody2D"
	add_child(body)

	for p in polys:
		if not (p is PackedVector2Array):
			continue
		var poly := p as PackedVector2Array
		if poly.size() < 3:
			continue
		var cp := CollisionPolygon2D.new()
		cp.polygon = poly
		body.add_child(cp)

func _ready() -> void:
	rebuild()

func _align_to_sprite() -> void:
	if sprite_path.is_empty():
		return
	var sprite := get_node_or_null(sprite_path) as Sprite2D
	if sprite == null or sprite.texture == null:
		return

	var tex_size := sprite.texture.get_size()
	var top_left := sprite.position
	if sprite.centered:
		top_left -= tex_size * sprite.scale / 2.0

	position = top_left
	scale = sprite.scale

func _polygons_from_image(img: Image) -> Array:
	# Expect an RGBA mask where obstacles are opaque (alpha>0). We'll use alpha only.
	var rgba := img
	if rgba.get_format() != Image.FORMAT_RGBA8:
		rgba = img.duplicate()
		rgba.convert(Image.FORMAT_RGBA8)

	var bm := BitMap.new()
	bm.create_from_image_alpha(rgba)

	var rect := Rect2i(Vector2i.ZERO, rgba.get_size())
	var polys: Array = bm.opaque_to_polygons(rect, epsilon)
	return polys

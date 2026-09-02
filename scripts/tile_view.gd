class_name LinkTileView
extends Control

signal tile_pressed(cell: Vector2i)

var cell := Vector2i.ZERO
var tile_type: int = -1

@onready var _frame: Panel = $Frame
@onready var _icon: TextureRect = $Frame/Icon
@onready var _ring: Panel = $Ring

func configure(p_cell: Vector2i, p_type: int, tex: Texture2D, tile_px: float, gap: float) -> void:
	cell = p_cell
	tile_type = p_type
	custom_minimum_size = Vector2(tile_px, tile_px)
	size = Vector2(tile_px, tile_px)
	position = Vector2(p_cell.x * (tile_px + gap), p_cell.y * (tile_px + gap))
	_frame.add_theme_stylebox_override("panel", LinkUi.peach_box(8))
	_icon.texture = tex
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pivot_offset = Vector2(tile_px, tile_px) * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ring.visible = false


func set_highlight(selected: bool, hint: bool) -> void:
	_ring.visible = selected or hint
	var box := StyleBoxFlat.new()
	var tint: Color = LinkUi.GOLD if hint else LinkUi.GREEN
	box.bg_color = Color(tint.r, tint.g, tint.b, 0.18)
	box.set_border_width_all(2)
	box.border_color = tint
	box.set_corner_radius_all(10)
	box.draw_center = true
	_ring.add_theme_stylebox_override("panel", box)


func play_exit() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.parallel().tween_property(self, "scale", Vector2(0.25, 0.25), 0.15)
	tw.tween_callback(queue_free)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.96, 0.96) if mb.pressed else Vector2.ONE, 0.1)
		if not mb.pressed and mb.canceled == false:
			tile_pressed.emit(cell)

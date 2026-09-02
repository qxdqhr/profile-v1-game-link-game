class_name LinkUi
extends RefCounted
## Shared control styles for the restored 葱韵环京连连看 UI.

const FONT := preload("res://addons/sa2kit_godot/fonts/SourceHanSansCN-Regular.otf")
const CREAM := Color(1, 1, 1, 0.94)
const INK := Color(0.2, 0.2, 0.22, 1)
const MUTED := Color(0.29, 0.333, 0.388, 1)
const ACCENT := Color(0.231, 0.510, 0.965, 1)
const ACCENT_HOVER := Color(0.145, 0.388, 0.922, 1)
const PEACH := Color(1.0, 0.855, 0.725, 1)
const GREEN := Color(0.298, 0.686, 0.314, 1)
const GOLD := Color(1.0, 0.843, 0.0, 1)
const SHADOW := Color(0, 0, 0, 0.12)


static func apply_font(node: Control, size: int, color: Color = INK) -> void:
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", size)
	if node is Label:
		node.add_theme_color_override("font_color", color)
	elif node is Button:
		node.add_theme_color_override("font_color", color)
		node.add_theme_color_override("font_hover_color", color)
		node.add_theme_color_override("font_pressed_color", color)
		node.add_theme_color_override("font_disabled_color", Color(color.r, color.g, color.b, 0.45))


static func card_box(radius: int = 16, pad: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CREAM
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	s.shadow_color = SHADOW
	s.anti_aliasing = true
	return s


static func peach_box(radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PEACH
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(3)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 1)
	s.shadow_color = Color(0, 0, 0, 0.10)
	return s


static func accent_button(radius: int = 10) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT
	normal.set_corner_radius_all(radius)
	normal.set_content_margin_all(8)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 1)
	normal.shadow_color = Color(0, 0, 0, 0.16)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT_HOVER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT.darkened(0.08)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.55, 0.58, 0.62, 1)
	disabled.shadow_size = 0
	return {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}


static func style_button(btn: Button, radius: int = 10) -> void:
	var skins: Dictionary = accent_button(radius)
	btn.add_theme_stylebox_override("normal", skins["normal"])
	btn.add_theme_stylebox_override("hover", skins["hover"])
	btn.add_theme_stylebox_override("pressed", skins["pressed"])
	btn.add_theme_stylebox_override("disabled", skins["disabled"])
	btn.add_theme_stylebox_override("focus", skins["hover"])
	apply_font(btn, 14, Color.WHITE)
	btn.custom_minimum_size.y = 40
	bind_press_scale(btn)


static func bind_press_scale(ctrl: Control) -> void:
	if ctrl.has_meta("press_scale_bound"):
		return
	ctrl.set_meta("press_scale_bound", true)
	var rest := Vector2.ONE
	var pressed := Vector2(0.96, 0.96)
	ctrl.resized.connect(func() -> void:
		ctrl.pivot_offset = ctrl.size * 0.5
	)
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			ctrl.pivot_offset = ctrl.size * 0.5
			var tw := ctrl.create_tween()
			tw.tween_property(ctrl, "scale", pressed if mb.pressed else rest, 0.12)
	)

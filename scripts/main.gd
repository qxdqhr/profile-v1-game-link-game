extends Control
## Restored original tile art + background; HUD matches the old 葱韵环京连连看 layout.

const COLS := 8
const ROWS := 8
const TYPES := 21
const TILE := 38.0
const GAP := 4.0
const GAME_DURATION := 300
const SHUFFLE_MAX := 5
const MATCH_SCORE := 10
const TIME_BONUS_PER_SEC := 2
const TILE_SCENE := preload("res://scenes/tile.tscn")
const CLICK_SFX := preload("res://assets/sfx/click.mp3")
const MATCH_SFX := preload("res://assets/sfx/match.mp3")

@onready var _menu: Control = $Menu
@onready var _menu_list: VBoxContainer = $Menu/Scroll/List
@onready var _play: Control = $Play
@onready var _board_ui: Control = $Play/Layout/BoardSlot/BoardPanel/Board
@onready var _board_panel: PanelContainer = $Play/Layout/BoardSlot/BoardPanel
@onready var _hud: PanelContainer = $Play/Layout/HUD
@onready var _title: Label = $Play/Layout/HUD/HudInner/Title
@onready var _credit: Label = $Play/Layout/HUD/HudInner/Credit
@onready var _score_lab: Label = $Play/Layout/HUD/HudInner/Stats/ScoreCard/ScoreCol/ScoreLab
@onready var _score_val: Label = $Play/Layout/HUD/HudInner/Stats/ScoreCard/ScoreCol/ScoreVal
@onready var _shuffle_lab: Label = $Play/Layout/HUD/HudInner/Stats/ShuffleCard/ShuffleCol/ShuffleLab
@onready var _shuffle_val: Label = $Play/Layout/HUD/HudInner/Stats/ShuffleCard/ShuffleCol/ShuffleVal
@onready var _time_lab: Label = $Play/Layout/HUD/HudInner/Stats/TimeCard/TimeCol/TimeLab
@onready var _time_val: Label = $Play/Layout/HUD/HudInner/Stats/TimeCard/TimeCol/TimeVal
@onready var _time_bar: ProgressBar = $Play/Layout/HUD/HudInner/TimeBar
@onready var _line: Line2D = $Play/Layout/BoardSlot/BoardPanel/Board/PathLine
@onready var _overlay: ColorRect = $Play/Overlay
@onready var _over_card: PanelContainer = $Play/Overlay/Card
@onready var _over_msg: Label = $Play/Overlay/Card/VBox/Msg
@onready var _retry: Button = $Play/Overlay/Card/VBox/Retry
@onready var _menu_btn: Button = $Play/Overlay/Card/VBox/ToMenu
@onready var _shuffle: Button = $Play/Layout/HUD/HudInner/Controls/Shuffle
@onready var _hint: Button = $Play/Layout/HUD/HudInner/Controls/Hint
@onready var _back: Button = $Play/Layout/HUD/HudInner/Controls/Back
@onready var _click_sfx: AudioStreamPlayer = $ClickSfx
@onready var _match_sfx: AudioStreamPlayer = $MatchSfx

var _mode: String = LinkModes.CLASSIC
var _board: Array = []
var _selected: Vector2i = Vector2i(-1, -1)
var _matched: int = 0
var _total: int = COLS * ROWS
var _score: int = 0
var _time_left: int = GAME_DURATION
var _shuffle_used: int = 0
var _timer_started: bool = false
var _busy: bool = false
var _status: String = "menu"
var _tiles: Dictionary = {}
var _hint_cells: Array = []
var _tick: Timer
var _textures: Array[Texture2D] = []
var _stat_boxes: Array[PanelContainer] = []

func _ready() -> void:
	for i in TYPES:
		_textures.append(load("res://assets/tiles/icon_%d.png" % i) as Texture2D)
	_click_sfx.stream = CLICK_SFX
	_match_sfx.stream = MATCH_SFX
	_retry.pressed.connect(_restart_play)
	_menu_btn.pressed.connect(_show_menu)
	_shuffle.pressed.connect(_do_shuffle)
	_hint.pressed.connect(_do_hint)
	_back.pressed.connect(_show_menu)
	_line.width = 3.0
	_line.default_color = Color(0.0, 1.0, 0.0, 1.0)
	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	_style_chrome()
	_build_menu()
	_show_menu()


func _style_chrome() -> void:
	_hud.add_theme_stylebox_override("panel", LinkUi.card_box(18, 12))
	_board_panel.add_theme_stylebox_override("panel", LinkUi.card_box(16, 8))
	_over_card.add_theme_stylebox_override("panel", LinkUi.card_box(20, 18))
	LinkUi.apply_font(_title, 18, LinkUi.INK)
	LinkUi.apply_font(_credit, 11, LinkUi.MUTED)
	for lab in [_score_lab, _shuffle_lab, _time_lab]:
		LinkUi.apply_font(lab, 11, LinkUi.MUTED)
	LinkUi.apply_font(_score_val, 20, Color(0.298, 0.686, 0.314, 1))
	LinkUi.apply_font(_shuffle_val, 20, Color(1.0, 0.596, 0.0, 1))
	LinkUi.apply_font(_time_val, 20, Color(0.129, 0.588, 0.953, 1))
	LinkUi.apply_font(_over_msg, 16, LinkUi.INK)
	_stat_boxes = [
		$Play/Layout/HUD/HudInner/Stats/ScoreCard,
		$Play/Layout/HUD/HudInner/Stats/ShuffleCard,
		$Play/Layout/HUD/HudInner/Stats/TimeCard,
	]
	var inner := LinkUi.card_box(12, 8)
	inner.shadow_size = 0
	inner.bg_color = Color(1, 1, 1, 0.72)
	for box in _stat_boxes:
		box.add_theme_stylebox_override("panel", inner)
	LinkUi.style_button(_back)
	LinkUi.style_button(_shuffle)
	LinkUi.style_button(_hint)
	LinkUi.style_button(_retry)
	LinkUi.style_button(_menu_btn)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.298, 0.686, 0.314, 1)
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.93, 0.93, 0.93, 1)
	bg.set_corner_radius_all(4)
	_time_bar.add_theme_stylebox_override("fill", fill)
	_time_bar.add_theme_stylebox_override("background", bg)


func _build_menu() -> void:
	for c in _menu_list.get_children():
		c.queue_free()
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", LinkUi.card_box(18, 16))
	var hero_col := VBoxContainer.new()
	hero_col.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "葱韵环京连连看"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	LinkUi.apply_font(title, 22, LinkUi.INK)
	var sub := Label.new()
	sub.text = "Created by 焦糖布丁忆梦梦 皋月朔星"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	LinkUi.apply_font(sub, 12, LinkUi.MUTED)
	var score := Label.new()
	score.text = "最高分 %d" % SaveData.high_score
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	LinkUi.apply_font(score, 14, Color(0.298, 0.686, 0.314, 1))
	hero_col.add_child(title)
	hero_col.add_child(sub)
	hero_col.add_child(score)
	hero.add_child(hero_col)
	_menu_list.add_child(hero)
	_fade_in(hero, 0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_list.add_child(grid)
	var idx := 1
	for m in LinkModes.ALL:
		var card := Button.new()
		card.text = "%s\n%s" % [str(m["name"]), str(m["desc"])]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.custom_minimum_size = Vector2(0, 88)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := LinkUi.card_box(14, 12)
		box.border_color = LinkUi.ACCENT
		box.set_border_width_all(2)
		var hover := box.duplicate() as StyleBoxFlat
		hover.shadow_size = 10
		hover.shadow_offset = Vector2(0, 4)
		card.add_theme_stylebox_override("normal", box)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		LinkUi.apply_font(card, 13, LinkUi.INK)
		card.add_theme_color_override("font_hover_color", LinkUi.INK)
		var mode_id: String = str(m["id"])
		card.pressed.connect(func() -> void: _start_mode(mode_id, str(m["name"])))
		LinkUi.bind_press_scale(card)
		grid.add_child(card)
		_fade_in(card, idx)
		idx += 1


func _fade_in(node: Control, index: int) -> void:
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.32).set_delay(index * 0.1)


func _show_menu() -> void:
	_tick.stop()
	_status = "menu"
	_menu.visible = true
	_play.visible = false
	_busy = false
	_clear_tiles()
	_build_menu()


func _start_mode(mode: String, title_name: String) -> void:
	_mode = mode
	_title.text = "葱韵环京连连看 · %s" % title_name
	_menu.visible = false
	_play.visible = true
	_restart_play()


func _restart_play() -> void:
	_status = "playing"
	_matched = 0
	_score = 0
	_time_left = GAME_DURATION
	_shuffle_used = 0
	_timer_started = false
	_busy = false
	_selected = Vector2i(-1, -1)
	_hint_cells.clear()
	_overlay.visible = false
	_line.points = PackedVector2Array()
	_tick.stop()
	_build_board()
	_sync_tiles(true)
	_update_hud()


func _build_board() -> void:
	var types: Array[int] = []
	for i in _total / 2:
		types.append(i % TYPES)
		types.append(i % TYPES)
	types.shuffle()
	_board.clear()
	var idx := 0
	for y in ROWS:
		var row: Array = []
		for x in COLS:
			row.append(types[idx])
			idx += 1
		_board.append(row)


func _on_tick() -> void:
	if _status != "playing":
		return
	_time_left = maxi(0, _time_left - 1)
	_update_hud()
	if _time_left <= 0:
		_fail("时间到！")


func _ensure_timer() -> void:
	if _timer_started or _status != "playing":
		return
	_timer_started = true
	_tick.start()


func _do_shuffle() -> void:
	if _status != "playing" or _busy:
		return
	if _shuffle_used >= SHUFFLE_MAX:
		return
	_play_click()
	_shuffle_board()
	_shuffle_used += 1
	_selected = Vector2i(-1, -1)
	_hint_cells.clear()
	_line.points = PackedVector2Array()
	_sync_tiles(true)
	_update_hud()


func _shuffle_board() -> void:
	var vals: Array[int] = []
	for y in ROWS:
		for x in COLS:
			var v: int = int((_board[y] as Array)[x])
			if v >= 0:
				vals.append(v)
	vals.shuffle()
	var i := 0
	for y in ROWS:
		for x in COLS:
			if int((_board[y] as Array)[x]) >= 0:
				(_board[y] as Array)[x] = vals[i]
				i += 1


func _do_hint() -> void:
	if _status != "playing" or _busy:
		return
	_play_click()
	_ensure_timer()
	_hint_cells = LinkLogic.find_hint(_board)
	_selected = Vector2i(-1, -1)
	_refresh_highlights()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if _status == "playing":
			_hint_cells.clear()
			_refresh_highlights()
	)


func _format_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


func _update_hud() -> void:
	_score_val.text = str(_score)
	_shuffle_val.text = str(SHUFFLE_MAX - _shuffle_used)
	_time_val.text = _format_time(_time_left)
	_time_bar.value = _time_left
	var warn := _time_left <= 10
	LinkUi.apply_font(_time_val, 20, Color(1.0, 0.267, 0.267, 1) if warn else Color(0.129, 0.588, 0.953, 1))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.933, 0.267, 0.267, 1) if warn else Color(0.298, 0.686, 0.314, 1)
	fill.set_corner_radius_all(4)
	_time_bar.add_theme_stylebox_override("fill", fill)
	_shuffle.disabled = _shuffle_used >= SHUFFLE_MAX or _status != "playing"
	_hint.disabled = _status != "playing"


func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * (TILE + GAP) + TILE * 0.5, c.y * (TILE + GAP) + TILE * 0.5)


func _board_size() -> Vector2:
	return Vector2(COLS * TILE + (COLS - 1) * GAP, ROWS * TILE + (ROWS - 1) * GAP)


func _clear_tiles() -> void:
	for key in _tiles.keys():
		var n: Node = _tiles[key]
		if is_instance_valid(n):
			n.queue_free()
	_tiles.clear()


func _sync_tiles(reset: bool) -> void:
	var dim := _board_size()
	_board_ui.custom_minimum_size = dim
	_board_ui.size = dim
	if reset:
		_clear_tiles()
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var t: int = int((_board[y] as Array)[x])
			if t < 0:
				if _tiles.has(cell) and is_instance_valid(_tiles[cell]):
					(_tiles[cell] as LinkTileView).play_exit()
					_tiles.erase(cell)
				continue
			if reset or not _tiles.has(cell) or not is_instance_valid(_tiles[cell]):
				var view: LinkTileView = TILE_SCENE.instantiate()
				_board_ui.add_child(view)
				view.configure(cell, t, _textures[t], TILE, GAP)
				view.tile_pressed.connect(_on_cell)
				_tiles[cell] = view
			else:
				var existing: LinkTileView = _tiles[cell]
				if existing.tile_type != t:
					existing.configure(cell, t, _textures[t], TILE, GAP)
	_refresh_highlights()
	_board_ui.move_child(_line, _board_ui.get_child_count() - 1)


func _refresh_highlights() -> void:
	for key in _tiles.keys():
		var view: LinkTileView = _tiles[key]
		if not is_instance_valid(view):
			continue
		var cell: Vector2i = key
		view.set_highlight(cell == _selected, cell in _hint_cells)


func _on_cell(cell: Vector2i) -> void:
	if _status != "playing" or _busy:
		return
	if int((_board[cell.y] as Array)[cell.x]) < 0:
		return
	_play_click()
	_ensure_timer()
	_hint_cells.clear()
	if _selected.x < 0:
		_selected = cell
		_refresh_highlights()
		return
	if _selected == cell:
		_selected = Vector2i(-1, -1)
		_line.points = PackedVector2Array()
		_refresh_highlights()
		return
	var result: Dictionary = LinkLogic.try_link(_board, _selected, cell)
	if bool(result.get("ok", false)):
		_busy = true
		var path: Array = result["path"] as Array
		_draw_path(path)
		(_board[_selected.y] as Array)[_selected.x] = -1
		(_board[cell.y] as Array)[cell.x] = -1
		_matched += 2
		_score += MATCH_SCORE
		_selected = Vector2i(-1, -1)
		_match_sfx.play()
		_sync_tiles(false)
		get_tree().create_timer(0.28).timeout.connect(func() -> void:
			_line.points = PackedVector2Array()
			LinkModes.apply_gravity(_board, _mode)
			_sync_tiles(true)
			_update_hud()
			_busy = false
			_after_match()
		)
	else:
		_selected = cell
		_line.points = PackedVector2Array()
		_refresh_highlights()


func _after_match() -> void:
	if _matched >= _total:
		_win()
		return
	if LinkLogic.has_matchable_pairs(_board):
		return
	if _shuffle_used < SHUFFLE_MAX:
		_shuffle_board()
		_shuffle_used += 1
		_sync_tiles(true)
		_update_hud()
		if not LinkLogic.has_matchable_pairs(_board) and _shuffle_used >= SHUFFLE_MAX:
			_fail("无解且洗牌用尽")
	else:
		_fail("无解且洗牌用尽")


func _win() -> void:
	_tick.stop()
	_status = "success"
	var bonus := _time_left * TIME_BONUS_PER_SEC
	_score += bonus
	var best: int = SaveData.record(_score)
	_over_msg.text = "通关！\n得分 %d（含时间奖励 %d）\n最高 %d" % [_score, bonus, best]
	_overlay.visible = true
	_update_hud()


func _fail(reason: String) -> void:
	_tick.stop()
	_status = "failed"
	SaveData.record(_score)
	_over_msg.text = "%s\n得分 %d\n最高 %d" % [reason, _score, SaveData.high_score]
	_overlay.visible = true
	_update_hud()


func _draw_path(path: Array) -> void:
	var pts := PackedVector2Array()
	for p in path:
		var v: Vector2i = p as Vector2i
		pts.append(_cell_pos(v))
	_line.points = pts


func _play_click() -> void:
	if _click_sfx.playing:
		_click_sfx.stop()
	_click_sfx.play()

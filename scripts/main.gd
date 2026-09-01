extends Control
## Stage-C: 6 modes, timer/score, hint, limited shuffle, high score.

const COLS := 8
const ROWS := 8
const TYPES := 12
const TILE := 36.0
const GAP := 3.0
const GAME_DURATION := 300
const SHUFFLE_MAX := 5
const MATCH_SCORE := 10
const TIME_BONUS_PER_SEC := 2
const COLORS: Array[Color] = [
	Color(0.90, 0.32, 0.32), Color(0.95, 0.55, 0.20), Color(0.95, 0.82, 0.25),
	Color(0.40, 0.78, 0.38), Color(0.30, 0.68, 0.88), Color(0.48, 0.42, 0.92),
	Color(0.88, 0.38, 0.72), Color(0.55, 0.55, 0.60), Color(0.25, 0.82, 0.72),
	Color(0.82, 0.45, 0.55), Color(0.65, 0.78, 0.35), Color(0.70, 0.55, 0.35),
]

@onready var _menu: Control = $Menu
@onready var _menu_list: VBoxContainer = $Menu/Scroll/List
@onready var _play: Control = $Play
@onready var _board_ui: Control = $Play/BoardWrap/Board
@onready var _hud: Label = $Play/UI/HUD
@onready var _line: Line2D = $Play/UI/PathLine
@onready var _overlay: ColorRect = $Play/UI/Overlay
@onready var _over_msg: Label = $Play/UI/Overlay/VBox/Msg
@onready var _retry: Button = $Play/UI/Overlay/VBox/Retry
@onready var _menu_btn: Button = $Play/UI/Overlay/VBox/ToMenu
@onready var _shuffle: Button = $Play/UI/Shuffle
@onready var _hint: Button = $Play/UI/Hint
@onready var _back: Button = $Play/UI/Back

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
var _status: String = "menu" ## menu | playing | success | failed
var _buttons: Dictionary = {}
var _hint_cells: Array = []
var _tick: Timer

func _ready() -> void:
	_retry.pressed.connect(_restart_play)
	_menu_btn.pressed.connect(_show_menu)
	_shuffle.pressed.connect(_do_shuffle)
	_hint.pressed.connect(_do_hint)
	_back.pressed.connect(_show_menu)
	_line.width = 3.0
	_line.default_color = Color(1.0, 0.92, 0.45, 0.9)
	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	_build_menu()
	_show_menu()

func _build_menu() -> void:
	for c in _menu_list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "葱韵环京连连看"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_menu_list.add_child(title)
	var sub := Label.new()
	sub.text = "最高分 %d" % SaveData.high_score
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	_menu_list.add_child(sub)
	for m in LinkModes.ALL:
		var b := Button.new()
		b.text = "%s\n%s" % [str(m["name"]), str(m["desc"])]
		b.custom_minimum_size = Vector2(300, 56)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var mode_id: String = str(m["id"])
		b.pressed.connect(func() -> void: _start_mode(mode_id))
		_menu_list.add_child(b)

func _show_menu() -> void:
	_tick.stop()
	_status = "menu"
	_menu.visible = true
	_play.visible = false
	_busy = false
	_build_menu()

func _start_mode(mode: String) -> void:
	_mode = mode
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
	_rebuild_ui()
	_update_hud()

func _build_board() -> void:
	var types: Array[int] = []
	for i in _total / 2:
		var t: int = i % TYPES
		types.append(t)
		types.append(t)
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
	_shuffle_board()
	_shuffle_used += 1
	_selected = Vector2i(-1, -1)
	_hint_cells.clear()
	_line.points = PackedVector2Array()
	_rebuild_ui()
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
	_ensure_timer()
	_hint_cells = LinkLogic.find_hint(_board)
	_selected = Vector2i(-1, -1)
	_rebuild_ui()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if _status == "playing":
			_hint_cells.clear()
			_rebuild_ui()
	)

func _update_hud() -> void:
	var remain := _total - _matched
	_hud.text = "得分 %d  最高 %d\n时间 %d  剩余 %d\n洗牌 %d" % [
		_score, SaveData.high_score, _time_left, remain, SHUFFLE_MAX - _shuffle_used
	]
	_shuffle.disabled = _shuffle_used >= SHUFFLE_MAX or _status != "playing"
	_hint.disabled = _status != "playing"

func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * (TILE + GAP) + TILE * 0.5, c.y * (TILE + GAP) + TILE * 0.5)

func _rebuild_ui() -> void:
	for c in _board_ui.get_children():
		c.queue_free()
	_buttons.clear()
	var w := COLS * TILE + (COLS - 1) * GAP
	var h := ROWS * TILE + (ROWS - 1) * GAP
	_board_ui.custom_minimum_size = Vector2(w, h)
	_board_ui.size = Vector2(w, h)
	for y in ROWS:
		for x in COLS:
			var t: int = int((_board[y] as Array)[x])
			if t < 0:
				continue
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(TILE, TILE)
			btn.size = Vector2(TILE, TILE)
			btn.position = Vector2(x * (TILE + GAP), y * (TILE + GAP))
			btn.text = str(t + 1)
			btn.add_theme_font_size_override("font_size", 15)
			var cell := Vector2i(x, y)
			_apply_btn_style(btn, t, cell)
			btn.pressed.connect(func() -> void: _on_cell(cell))
			_board_ui.add_child(btn)
			_buttons[cell] = btn

func _apply_btn_style(btn: Button, t: int, cell: Vector2i) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLORS[t % COLORS.size()]
	style.set_corner_radius_all(7)
	if cell == _selected or cell in _hint_cells:
		style.border_color = Color(1, 1, 1, 1)
		style.set_border_width_all(3)
		if cell in _hint_cells:
			style.border_color = Color(1.0, 0.92, 0.2, 1)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _on_cell(cell: Vector2i) -> void:
	if _status != "playing" or _busy:
		return
	if int((_board[cell.y] as Array)[cell.x]) < 0:
		return
	_ensure_timer()
	_hint_cells.clear()
	if _selected.x < 0:
		_selected = cell
		_rebuild_ui()
		return
	if _selected == cell:
		_selected = Vector2i(-1, -1)
		_line.points = PackedVector2Array()
		_rebuild_ui()
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
		get_tree().create_timer(0.28).timeout.connect(func() -> void:
			_line.points = PackedVector2Array()
			LinkModes.apply_gravity(_board, _mode)
			_rebuild_ui()
			_update_hud()
			_busy = false
			_after_match()
		)
	else:
		_selected = cell
		_line.points = PackedVector2Array()
		_rebuild_ui()

func _after_match() -> void:
	if _matched >= _total:
		_win()
		return
	if LinkLogic.has_matchable_pairs(_board):
		return
	if _shuffle_used < SHUFFLE_MAX:
		_shuffle_board()
		_shuffle_used += 1
		_rebuild_ui()
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
	var origin := _board_ui.global_position
	for p in path:
		var v: Vector2i = p as Vector2i
		pts.append(origin + _cell_pos(v))
	_line.points = pts

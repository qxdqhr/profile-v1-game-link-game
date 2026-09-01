class_name LinkModes
extends RefCounted

## Align original GAME_LEVELS gameType ids.
const CLASSIC := "disvariable"
const DOWN := "downfalling"
const UP := "upfalling"
const LR_SPLIT := "leftrightsplit"
const UD_SPLIT := "updownsplit"
const CLOCKWISE := "clockwise"

const ALL: Array[Dictionary] = [
	{"id": CLASSIC, "name": "经典模式", "desc": "消除后方块保持不动"},
	{"id": DOWN, "name": "向下掉落", "desc": "消除后方块向下掉落"},
	{"id": UP, "name": "向上浮动", "desc": "消除后方块向上浮动"},
	{"id": LR_SPLIT, "name": "左右分裂", "desc": "消除后向两侧分裂"},
	{"id": UD_SPLIT, "name": "上下分裂", "desc": "消除后向上下分裂"},
	{"id": CLOCKWISE, "name": "顺时针旋转", "desc": "消除后按象限顺时针整理"},
]

## Compact remaining tiles after a match. board[y][x] = type or -1.
static func apply_gravity(board: Array, mode: String) -> void:
	var rows: int = board.size()
	var cols: int = (board[0] as Array).size()
	match mode:
		DOWN:
			_gravity_vertical(board, rows, cols, true)
		UP:
			_gravity_vertical(board, rows, cols, false)
		LR_SPLIT:
			_gravity_lr_split(board, rows, cols)
		UD_SPLIT:
			_gravity_ud_split(board, rows, cols)
		CLOCKWISE:
			_gravity_clockwise(board, rows, cols)
		_:
			pass

static func _gravity_vertical(board: Array, rows: int, cols: int, down: bool) -> void:
	for x in cols:
		var vals: Array[int] = []
		for y in rows:
			var v: int = int((board[y] as Array)[x])
			if v >= 0:
				vals.append(v)
		for y in rows:
			(board[y] as Array)[x] = -1
		if down:
			var start := rows - vals.size()
			for i in vals.size():
				(board[start + i] as Array)[x] = vals[i]
		else:
			for i in vals.size():
				(board[i] as Array)[x] = vals[i]

static func _gravity_lr_split(board: Array, rows: int, cols: int) -> void:
	var mid := cols / 2
	for y in rows:
		var left_vals: Array[int] = []
		var right_vals: Array[int] = []
		for x in cols:
			var v: int = int((board[y] as Array)[x])
			if v < 0:
				continue
			if x < mid:
				left_vals.append(v)
			else:
				right_vals.append(v)
		for x in cols:
			(board[y] as Array)[x] = -1
		for i in left_vals.size():
			(board[y] as Array)[i] = left_vals[i]
		var rstart := cols - right_vals.size()
		for i in right_vals.size():
			(board[y] as Array)[rstart + i] = right_vals[i]

static func _gravity_ud_split(board: Array, rows: int, cols: int) -> void:
	var mid := rows / 2
	for x in cols:
		var top_vals: Array[int] = []
		var bot_vals: Array[int] = []
		for y in rows:
			var v: int = int((board[y] as Array)[x])
			if v < 0:
				continue
			if y < mid:
				top_vals.append(v)
			else:
				bot_vals.append(v)
		for y in rows:
			(board[y] as Array)[x] = -1
		for i in top_vals.size():
			(board[i] as Array)[x] = top_vals[i]
		var bstart := rows - bot_vals.size()
		for i in bot_vals.size():
			(board[bstart + i] as Array)[x] = bot_vals[i]

static func _gravity_clockwise(board: Array, rows: int, cols: int) -> void:
	## Approximate original quadrant settle: TR→right, BR→down, BL→left, TL→up.
	var cx := (cols - 1) / 2.0
	var cy := (rows - 1) / 2.0
	var q_tr: Array = [] ## Vector2i cells then pack by row right
	var q_br: Array = []
	var q_bl: Array = []
	var q_tl: Array = []
	for y in rows:
		for x in cols:
			var v: int = int((board[y] as Array)[x])
			if v < 0:
				continue
			var cell := {"x": x, "y": y, "v": v}
			if float(x) >= cx and float(y) < cy:
				q_tr.append(cell)
			elif float(x) > cx and float(y) >= cy:
				q_br.append(cell)
			elif float(x) <= cx and float(y) > cy:
				q_bl.append(cell)
			else:
				q_tl.append(cell)
			(board[y] as Array)[x] = -1
	_pack_rows_right(board, rows, cols, q_tr, 0, int(floor(cy)))
	_pack_cols_down(board, rows, cols, q_br, int(ceil(cx)), cols)
	_pack_rows_left(board, rows, cols, q_bl, int(ceil(cy)), rows)
	_pack_cols_up(board, rows, cols, q_tl, 0, int(floor(cx)) + 1)

static func _pack_rows_right(board: Array, _rows: int, cols: int, cells: Array, y0: int, y1: int) -> void:
	var by_row: Dictionary = {}
	for c in cells:
		var y: int = int(c["y"])
		if not by_row.has(y):
			by_row[y] = [] as Array
		(by_row[y] as Array).append(int(c["v"]))
	for y in range(y0, y1):
		if not by_row.has(y):
			continue
		var vals: Array = by_row[y] as Array
		var start := cols - vals.size()
		for i in vals.size():
			(board[y] as Array)[start + i] = int(vals[i])

static func _pack_rows_left(board: Array, _rows: int, _cols: int, cells: Array, y0: int, y1: int) -> void:
	var by_row: Dictionary = {}
	for c in cells:
		var y: int = int(c["y"])
		if not by_row.has(y):
			by_row[y] = [] as Array
		(by_row[y] as Array).append(int(c["v"]))
	for y in range(y0, y1):
		if not by_row.has(y):
			continue
		var vals: Array = by_row[y] as Array
		for i in vals.size():
			(board[y] as Array)[i] = int(vals[i])

static func _pack_cols_down(board: Array, rows: int, _cols: int, cells: Array, x0: int, x1: int) -> void:
	var by_col: Dictionary = {}
	for c in cells:
		var x: int = int(c["x"])
		if not by_col.has(x):
			by_col[x] = [] as Array
		(by_col[x] as Array).append(int(c["v"]))
	for x in range(x0, x1):
		if not by_col.has(x):
			continue
		var vals: Array = by_col[x] as Array
		var start := rows - vals.size()
		for i in vals.size():
			(board[start + i] as Array)[x] = int(vals[i])

static func _pack_cols_up(board: Array, _rows: int, _cols: int, cells: Array, x0: int, x1: int) -> void:
	var by_col: Dictionary = {}
	for c in cells:
		var x: int = int(c["x"])
		if not by_col.has(x):
			by_col[x] = [] as Array
		(by_col[x] as Array).append(int(c["v"]))
	for x in range(x0, x1):
		if not by_col.has(x):
			continue
		var vals: Array = by_col[x] as Array
		for i in vals.size():
			(board[i] as Array)[x] = int(vals[i])

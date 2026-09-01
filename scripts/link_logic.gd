class_name LinkLogic
extends RefCounted

## Occupied cells are true. Path may use empty cells; ≤2 corners.
## pad=4 aligns original BOUNDARY_SPACE.

static func can_connect_directly(start: Vector2i, end: Vector2i, grid: Array) -> bool:
	if start.x == end.x:
		var min_y := mini(start.y, end.y)
		var max_y := maxi(start.y, end.y)
		for y in range(min_y + 1, max_y):
			if bool((grid[y] as Array)[start.x]):
				return false
		return true
	if start.y == end.y:
		var min_x := mini(start.x, end.x)
		var max_x := maxi(start.x, end.x)
		for x in range(min_x + 1, max_x):
			if bool((grid[start.y] as Array)[x]):
				return false
		return true
	return false

static func one_corner(start: Vector2i, end: Vector2i, grid: Array) -> Array:
	var c1 := Vector2i(end.x, start.y)
	if _in_bounds(c1, grid) and not bool((grid[c1.y] as Array)[c1.x]) \
			and can_connect_directly(start, c1, grid) and can_connect_directly(c1, end, grid):
		return [start, c1, end]
	var c2 := Vector2i(start.x, end.y)
	if _in_bounds(c2, grid) and not bool((grid[c2.y] as Array)[c2.x]) \
			and can_connect_directly(start, c2, grid) and can_connect_directly(c2, end, grid):
		return [start, c2, end]
	return []

static func two_corner(start: Vector2i, end: Vector2i, grid: Array) -> Array:
	var h: int = grid.size()
	var w: int = (grid[0] as Array).size()
	for x in w:
		if x == start.x or x == end.x:
			continue
		var c1 := Vector2i(x, start.y)
		var c2 := Vector2i(x, end.y)
		if not bool((grid[c1.y] as Array)[c1.x]) and not bool((grid[c2.y] as Array)[c2.x]):
			if can_connect_directly(start, c1, grid) and can_connect_directly(c1, c2, grid) \
					and can_connect_directly(c2, end, grid):
				return [start, c1, c2, end]
	for y in h:
		if y == start.y or y == end.y:
			continue
		var c1 := Vector2i(start.x, y)
		var c2 := Vector2i(end.x, y)
		if not bool((grid[c1.y] as Array)[c1.x]) and not bool((grid[c2.y] as Array)[c2.x]):
			if can_connect_directly(start, c1, grid) and can_connect_directly(c1, c2, grid) \
					and can_connect_directly(c2, end, grid):
				return [start, c1, c2, end]
	return []

static func _in_bounds(p: Vector2i, grid: Array) -> bool:
	return p.y >= 0 and p.y < grid.size() and p.x >= 0 and p.x < (grid[0] as Array).size()

static func find_path(start: Vector2i, end: Vector2i, grid: Array) -> Array:
	if can_connect_directly(start, end, grid):
		return [start, end]
	var one: Array = one_corner(start, end, grid)
	if not one.is_empty():
		return one
	return two_corner(start, end, grid)

static func try_link(board: Array, a: Vector2i, b: Vector2i, pad: int = 4) -> Dictionary:
	if a == b:
		return {"ok": false}
	var rows: int = board.size()
	var cols: int = (board[0] as Array).size()
	var ta: int = int((board[a.y] as Array)[a.x])
	var tb: int = int((board[b.y] as Array)[b.x])
	if ta < 0 or tb < 0 or ta != tb:
		return {"ok": false}
	var gh := rows + pad * 2
	var gw := cols + pad * 2
	var grid: Array = []
	for y in gh:
		var row: Array = []
		for x in gw:
			row.append(false)
		grid.append(row)
	for y in rows:
		for x in cols:
			if int((board[y] as Array)[x]) >= 0:
				(grid[y + pad] as Array)[x + pad] = true
	var start := Vector2i(a.x + pad, a.y + pad)
	var end := Vector2i(b.x + pad, b.y + pad)
	(grid[start.y] as Array)[start.x] = false
	(grid[end.y] as Array)[end.x] = false
	var path: Array = find_path(start, end, grid)
	if path.is_empty():
		return {"ok": false}
	var out: Array = []
	for p in path:
		var v: Vector2i = p as Vector2i
		out.append(Vector2i(v.x - pad, v.y - pad))
	return {"ok": true, "path": out}

static func has_matchable_pairs(board: Array) -> bool:
	return not find_hint(board).is_empty()

static func find_hint(board: Array) -> Array:
	var rows: int = board.size()
	var cols: int = (board[0] as Array).size()
	var cells: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			if int((board[y] as Array)[x]) >= 0:
				cells.append(Vector2i(x, y))
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			var a: Vector2i = cells[i]
			var b: Vector2i = cells[j]
			if int((board[a.y] as Array)[a.x]) != int((board[b.y] as Array)[b.x]):
				continue
			var result: Dictionary = try_link(board, a, b)
			if bool(result.get("ok", false)):
				return [a, b]
	return []

extends TileMap

const DIRECTIONS := [
		Vector2(0, -1),
		Vector2(0, 1),
		Vector2(-1, 0),
		Vector2(1, 0)
	]

export var map_size := Vector2(63, 35)
export var room_place_tries := 200
export var room_max_base_size := 2
export var room_size_deviation := 0.5
export var extra_connector_chance := 0.05

var _rand := RandomNumberGenerator.new()
var _regions := {} # to keep track of what region a tile is in
var _curRegion := 0

func _ready() -> void:
	if (int(map_size.x) % 2 == 0 or int(map_size.y) % 2 == 0):
		printerr("map_size must have two odd numbers!")
		return
	_rand.randomize()
	randomize()
	clear()
	_place_rooms()
	_place_passages()
	_connect_regions()
	_remove_dead_ends()
	update_bitmask_region(Vector2(0, 0), map_size)

func _remove_dead_ends():
	var done := false
	
	while (!done):
		done = true
		
		for y in range (1, map_size.y + 1):
			for x in range(1, map_size.x + 1):
				if get_cell(x, y) == -1:
					continue
					
				# find tile's exits - if 1 then dead end and must be removed
				var exits = 0
				for dir in DIRECTIONS:
					var target = Vector2(x, y) + dir
					if get_cellv(target) != -1 and _in_bounds(target):
						exits += 1
				
				if exits != 1:
					continue
					
				done = false
				set_cell(x, y, -1)

func _connect_regions() -> void:
	var connectors := _find_connectors()
	var connectorLocs := connectors.keys()

	# map the old index to its connected region
	var toConnected := {}
	var unconnectedRegions := []
	for i in range(0, _curRegion):
		toConnected[i] = i
		unconnectedRegions.append(i)
	
	while unconnectedRegions.size() > 1:
		var connector: Vector2 = connectorLocs[randi() % connectorLocs.size()]
		
		set_cellv(connector, 0)
		
		var regions: Array = connectors[connector]
		# map connected regions
		for i in range(0, regions.size()):
			regions[i] = toConnected[regions[i]]
		
		var destination = regions[0]
		var sources = regions.slice(1, regions.size())
		
		# actually merge the regions
		for i in range(0, _curRegion):
			if sources.has(toConnected[i]):
				toConnected[i] = destination
				
		# remove connected regions from unconnected ones
		for region in sources:
			unconnectedRegions.erase(region)
			
		# remove (most) orphaned connectors
		for pos in connectorLocs:
			if (connector - pos).length() < 2:
				connectorLocs.erase(pos)
				continue
				
			var posRegions = connectors[pos]
			var filteredPosRegions = []
			for region in posRegions:
				var connected = toConnected[region]
				if not filteredPosRegions.has(connected):
					filteredPosRegions.append(connected)
			
			if filteredPosRegions.size() <= 1:
				if _rand.randf() < extra_connector_chance:
					set_cellv(pos, 0)
				connectorLocs.erase(pos)


func _find_connectors() -> Dictionary:
	var connectors := {}
	for y in range(1, map_size.y + 1):
		for x in range(1, map_size.x + 1):
			if get_cell(x, y) != -1:
				continue
			
			var pos = Vector2(x, y)
			
			var regions := []
			var directions := DIRECTIONS.duplicate()
			for dir in directions:
				if _regions.has(pos + dir):
					var region: int = _regions[pos + dir]
					if not regions.has(region):
						regions.append(region)
					
			if (regions.size() < 2):
				continue
				
			connectors[pos] = regions
	return connectors
	
func _place_passages() -> void:
	for y in range(1, map_size.y, 2):
		for x in range(1, map_size.x, 2):
			if get_cell(x, y) == -1:
				_maze_fill(Vector2(x, y))
				_curRegion += 1

# TODO: make this non-recusive to support larger maps (stack overflow)
func _maze_fill(pos: Vector2) -> void:
	var directions := DIRECTIONS.duplicate()
	directions.shuffle()
	
	for dir in directions:
		var next = pos + dir * 2
		# TODO: try to find a way w/o destructoring the vector
		if get_cellv(next) == -1 \
			and _in_bounds(next):
			_set_regioned_cellv(pos, 0)
			_set_regioned_cellv(pos + dir, 0)
			_set_regioned_cellv(next, 0)
			_maze_fill(next)

func _in_bounds(pos: Vector2) -> bool:
	return 0 <= pos.x and pos.x <= map_size.x \
			and 0 <= pos.y and pos.y <= map_size.y

func _place_rooms() -> void:
	var rooms := []
	for _i in range(0, room_place_tries):
		var squareSize: int = _rand.randi_range(1, room_max_base_size) * 2 + 1
		var sizeDeviation: int = \
				_rand.randi_range(0, 1 + int(squareSize * room_size_deviation)) * 2
		
		var width := squareSize
		var height := squareSize
		if (_rand.randi() % 2):
			width += sizeDeviation
		else:
			height += sizeDeviation
		
		var x: int = _rand.randi_range(0, int(map_size.x - width) / 2) * 2 + 1
		var y: int = _rand.randi_range(0, int(map_size.y - height) / 2) * 2 + 1
		
		var room := Rect2(x, y, width, height)
		
		if _is_room_overlapping(room, rooms):
			continue
		
		rooms.append(room)
		
	_set_rooms(rooms)
		
func _is_room_overlapping(room: Rect2, rooms: Array) -> bool:
	var overlapping := false
	for other in rooms:
		if room.intersects(other):
			overlapping = true
			break
	return overlapping

func _set_rooms(rooms: Array) -> void:
	for room in rooms:
		_set_rect(room)
		_curRegion += 1
		
func _set_rect(rect: Rect2) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_set_regioned_cell(x, y, 0)
			
func _set_regioned_cell(x: int, y: int, tile: int):
	_set_regioned_cellv(Vector2(x, y), tile)

func _set_regioned_cellv(pos: Vector2, tile: int):
	_regions[pos] = _curRegion
	set_cellv(pos, tile)

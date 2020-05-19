extends Sprite

# must be tilemap
export var tiles: NodePath
export var inputs := {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_down": Vector2.DOWN,
	"ui_up": Vector2.UP
}
export var move_speed := 3

var _queued_input := []

onready var tile_map := get_node(tiles) as Level
onready var tween := $Tween as Tween

func _ready() -> void:
	randomize()
	var start_room = tile_map.rooms[randi() % tile_map.rooms.size()]
	position = tile_map.map_to_world(start_room.position\
			+ (start_room.size / 2.0).floor())\
			+ tile_map.cell_size / 2.0
	
func _unhandled_input(event: InputEvent) -> void:
	_queued_input.push_back(event)
	for input in _queued_input:
		_queued_input.erase(input)
		for dir in inputs.keys():
			if (event.is_action_pressed(dir)):
				move(inputs[dir])
				yield(tween, "tween_completed")

func move(dir: Vector2):
	var cur_pos := tile_map.world_to_map(position)
	var next_pos := cur_pos + dir
	if tile_map.get_cellv(next_pos) == -1:
		return
		
	_tween_move(tile_map.map_to_world(next_pos) + tile_map.cell_size / 2.0)

func _tween_move(final_pos: Vector2):
	var _success = tween.interpolate_property(self, "position",
			position, final_pos,
			1.0 / move_speed, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_success = tween.start()

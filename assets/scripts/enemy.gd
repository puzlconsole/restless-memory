class_name StalkerEnemy
extends CharacterBody3D

@export_category("Stalker Settings")
@export var move_speed: float = 3.5
@export var preferred_distance: float = 10.0
@export var distance_tolerance: float = 2.0
@export var player_group_name: String = "player"

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var line_of_sight: RayCast3D = $LineOfSight

var player: Node3D = null
var current_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	var players = get_tree().get_nodes_in_group(player_group_name)
	if players.size() > 0:
		player = players[0]
	else:
		push_warning("StalkerEnemy: No player found in group '" + player_group_name + "'.")

func _physics_process(delta: float) -> void:
	if not player:
		return

	if not is_on_floor():
		velocity.y -= current_gravity * delta

	line_of_sight.target_position = line_of_sight.to_local(player.global_position + Vector3(0, 1, 0))

	var distance_to_player = global_position.distance_to(player.global_position)
	var target_position = global_position

	if distance_to_player > preferred_distance + distance_tolerance:
		target_position = player.global_position
	elif distance_to_player < preferred_distance - distance_tolerance:
		var dir_away = (global_position - player.global_position).normalized()
		target_position = global_position + dir_away * 5.0
	else:
		var to_player = (player.global_position - global_position).normalized()
		var tangent = Vector3(-to_player.z, 0, to_player.x)
		target_position = global_position + tangent * 4.0

	nav_agent.target_position = target_position

	if not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
		direction.y = 0
		
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_to(look_target) > 0.5:
			look_at(look_target, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

class_name StalkerEnemy
extends CharacterBody3D

# --- Movement & Behavior Parameters ---
@export_category("Stalker Settings")
@export var move_speed: float = 3.5
@export var preferred_distance: float = 10.0  # The distance it tries to maintain from the player
@export var distance_tolerance: float = 2.0   # Buffer zone before it reacts to distance changes
@export var player_group_name: String = "player"

# --- Node References ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var line_of_sight: RayCast3D = $LineOfSight

# --- Internal State ---
var player: Node3D = null
var current_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# Automatically find the player by group on startup
	var players = get_tree().get_nodes_in_group(player_group_name)
	if players.size() > 0:
		player = players[0]
	else:
		push_warning("StalkerEnemy: No player found in group '" + player_group_name + "'.")

func _physics_process(delta: float) -> void:
	if not player:
		return

	# Apply gravity if not on the floor
	if not is_on_floor():
		velocity.y -= current_gravity * delta

	# Update Line of Sight raycast to check if it has eyes on the player
	line_of_sight.target_position = line_of_sight.to_local(player.global_position + Vector3(0, 1, 0))

	# Calculate distance to the player
	var distance_to_player = global_position.distance_to(player.global_position)
	var target_position = global_position

	# --- Stalking State Logic ---
	if distance_to_player > preferred_distance + distance_tolerance:
		# Player is too far: move closer
		target_position = player.global_position
	elif distance_to_player < preferred_distance - distance_tolerance:
		# Player is too close: back away safely
		var dir_away = (global_position - player.global_position).normalized()
		target_position = global_position + dir_away * 5.0
	else:
		# Sweet spot: orbit / strafe sideways around the player
		var to_player = (player.global_position - global_position).normalized()
		var tangent = Vector3(-to_player.z, 0, to_player.x) # Perpendicular vector for circling
		target_position = global_position + tangent * 4.0

	# Feed target position into the Navigation Agent
	nav_agent.target_position = target_position

	# Movement execution via Navigation Agent
	if not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
		direction.y = 0
		
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		# Smoothly look at the player while stalking
		var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_to(look_target) > 0.5:
			look_at(look_target, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

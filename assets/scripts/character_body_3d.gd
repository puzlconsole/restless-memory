class_name AdvancedCharacterController
extends CharacterBody3D

# --- ALL THIS CODE IS AI GENERATED JUST TO GET A MOTIVATIONAL TEMPLATE IN. NOT FINAL! ---

@export_category("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var prone_speed: float = 1.2
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var air_control: float = 0.3

@export_category("Stance Heights")
@export var stand_height: float = 2.0
@export var crouch_height: float = 1.2
@export var prone_height: float = 0.6
@export var stance_transition_speed: float = 10.0

@export_category("Physics")
@export var gravity_multiplier: float = 2.0
@export var terminal_velocity: float = 50.0

@export_category("Jump Mechanics")
@export var jump_height: float = 4.5
@export var jump_buffer_time: float = 0.15
@export var coyote_time: float = 0.15

@export_category("Camera & Juice")
@export var mouse_sensitivity: float = 0.002
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.06
@export var base_fov: float = 75.0
@export var fov_change_speed: float = 8.0

@onready var twist_pivot: Node3D = $TwistPivot
@onready var pitch_pivot: Node3D = $TwistPivot/PitchPivot
@onready var camera: Camera3D = $TwistPivot/PitchPivot/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_cast: ShapeCast3D = $CeilingCast

enum Stance { STANDING, CROUCHING, PRONING }
var current_stance: Stance = Stance.STANDING

var current_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var jump_velocity: float
var current_speed: float
var movement_direction: Vector3 = Vector3.ZERO
var camera_bob_timer: float = 0.0
var default_camera_y: float

var jump_buffer_counter: float = 0.0
var coyote_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	jump_velocity = sqrt(2.0 * (current_gravity * gravity_multiplier) * jump_height)
	current_speed = walk_speed
	default_camera_y = twist_pivot.position.y
	setup_shapecast()

func setup_shapecast() -> void:
	if not ceiling_cast:
		ceiling_cast = ShapeCast3D.new()
		add_child(ceiling_cast)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		var check_shape = CapsuleShape3D.new()
		check_shape.radius = capsule.radius * 0.95
		check_shape.height = stand_height
		ceiling_cast.shape = check_shape
		
	ceiling_cast.enabled = true
	ceiling_cast.exclude_parent = true
	ceiling_cast.target_position = Vector3(0, stand_height, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		twist_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		pitch_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, deg_to_rad(-85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	handle_timers(delta)
	handle_stance(delta)
	handle_gravity(delta)
	handle_input_and_movement(delta)
	handle_juice(delta)
	
	move_and_slide()

func handle_timers(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_counter = jump_buffer_time
	else:
		jump_buffer_counter -= delta

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

func handle_stance(delta: float) -> void:
	var target_stance: Stance = Stance.STANDING

	if Input.is_action_pressed("prone"):
		target_stance = Stance.PRONING
	elif Input.is_action_pressed("crouch"):
		target_stance = Stance.CROUCHING
	else:
		if current_stance == Stance.PRONING:
			if is_ceiling_blocked(stand_height):
				if is_ceiling_blocked(crouch_height):
					target_stance = Stance.PRONING
				else:
					target_stance = Stance.CROUCHING
			else:
				target_stance = Stance.STANDING
		elif current_stance == Stance.CROUCHING:
			if is_ceiling_blocked(stand_height):
				target_stance = Stance.CROUCHING
			else:
				target_stance = Stance.STANDING
		else:
			target_stance = Stance.STANDING

	if Input.is_action_pressed("sprint") and movement_direction.length() > 0.1 and is_on_floor():
		if not is_ceiling_blocked(stand_height):
			target_stance = Stance.STANDING

	current_stance = target_stance

	var target_height: float = stand_height
	match current_stance:
		Stance.CROUCHING: target_height = crouch_height
		Stance.PRONING: target_height = prone_height

	var capsule = collision_shape.shape as CapsuleShape3D
	if capsule:
		var old_height = capsule.height
		capsule.height = lerp(capsule.height, target_height, stance_transition_speed * delta)
		
		var height_difference = old_height - capsule.height
		if is_on_floor() and abs(height_difference) > 0.001:
			position.y += height_difference * 0.5
		
		collision_shape.position.y = capsule.height / 2.0

	var target_cam_y = default_camera_y * (target_height / stand_height)
	twist_pivot.position.y = lerp(twist_pivot.position.y, target_cam_y, stance_transition_speed * delta)

func is_ceiling_blocked(check_height: float) -> bool:
	var current_capsule = collision_shape.shape as CapsuleShape3D
	
	ceiling_cast.position.y = 0.1 
	ceiling_cast.target_position.y = check_height - 0.1
	ceiling_cast.force_shapecast_update()
	
	return ceiling_cast.is_colliding()

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= current_gravity * gravity_multiplier * delta
		velocity.y = max(velocity.y, -terminal_velocity)
		
		if Input.is_action_just_released("jump") and velocity.y > 0.0:
			velocity.y *= 0.5

func handle_input_and_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "back")
	movement_direction = (twist_pivot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_speed: float = walk_speed
	match current_stance:
		Stance.STANDING:
			target_speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
		Stance.CROUCHING:
			target_speed = crouch_speed
		Stance.PRONING:
			target_speed = prone_speed

	current_speed = lerp(current_speed, target_speed, acceleration * delta)

	if jump_buffer_counter > 0.0 and coyote_timer > 0.0 and current_stance == Stance.STANDING:
		velocity.y = jump_velocity
		jump_buffer_counter = 0.0
		coyote_timer = 0.0

	var horizontal_lerp: float = acceleration if is_on_floor() else (acceleration * air_control)
	
	if movement_direction:
		velocity.x = lerp(velocity.x, movement_direction.x * current_speed, horizontal_lerp * delta)
		velocity.z = lerp(velocity.z, movement_direction.z * current_speed, horizontal_lerp * delta)
	else:
		var friction_lerp: float = deceleration if is_on_floor() else (deceleration * air_control)
		velocity.x = lerp(velocity.x, 0.0, friction_lerp * delta)
		velocity.z = lerp(velocity.z, 0.0, friction_lerp * delta)

func handle_juice(delta: float) -> void:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var target_fov: float = base_fov + (horizontal_velocity.length() * 1.5)
	camera.fov = lerp(camera.fov, target_fov, fov_change_speed * delta)

	if is_on_floor() and horizontal_velocity.length() > 0.1:
		camera_bob_timer += delta * current_speed * bob_frequency
		var target_pos:Vector3 = Vector3.ZERO
		
		var stance_modifier: float = 1.0
		if current_stance == Stance.CROUCHING: stance_modifier = 0.5
		elif current_stance == Stance.PRONING: stance_modifier = 0.2
		
		target_pos.y = sin(camera_bob_timer) * bob_amplitude * stance_modifier
		target_pos.x = cos(camera_bob_timer / 2.0) * bob_amplitude * 0.5 * stance_modifier
		camera.transform.origin = lerp(camera.transform.origin, target_pos, delta * 10.0)
	else:
		camera_bob_timer = 0.0
		camera.transform.origin = lerp(camera.transform.origin, Vector3.ZERO, delta * 10.0)

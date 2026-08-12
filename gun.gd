extends Node3D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.2
@export var bullet_speed: float = 50.0

# Using Node3D instead of Marker3D prevents type-casting crashes if your muzzle is a standard node
@onready var muzzle: Node3D = $Muzzle

var can_fire: bool = true

func _process(_delta: float) -> void:
	if Input.is_action_pressed("shoot") and can_fire:
		shoot()

func shoot() -> void:
	if not bullet_scene:
		print("ERROR: Bullet Scene is missing/null in the Inspector!")
		return
		
	if not muzzle:
		print("ERROR: Muzzle node not found!")
		return

	can_fire = false
	
	# 1. Instantiate the bullet
	var bullet = bullet_scene.instantiate() as RigidBody3D
	if not bullet:
		print("ERROR: Bullet scene root is not a RigidBody3D!")
		can_fire = true
		return
		
	# 2. Get active camera direction (or fallback to muzzle direction)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var target_direction: Vector3 = Vector3.ZERO
	
	if camera != null:
		target_direction = -camera.global_transform.basis.z.normalized()
	else:
		target_direction = -muzzle.global_transform.basis.z.normalized()
		
	# 3. Add to the world root first
	get_tree().root.add_child(bullet)
	
	# 4. Position and align bullet transform
	bullet.global_transform = muzzle.global_transform
	if target_direction != Vector3.ZERO:
		bullet.look_at(bullet.global_position + target_direction, Vector3.UP)
	
	# 5. Apply velocity
	var launch_velocity: Vector3 = target_direction * bullet_speed
	bullet.linear_velocity = launch_velocity
	bullet.sleeping = false
	
	print("Bullet Fired!")
		
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true

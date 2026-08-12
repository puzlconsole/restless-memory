class_name Bullet
extends RigidBody3D

## How many seconds before the bullet automatically disappears
@export var lifetime: float = 4.0

func _ready() -> void:
	# Continuous collision detection prevents fast bullets from passing through walls
	continuous_cd = true
	
	# Ensure the body wakes up immediately when spawned
	sleeping = false
	
	# Clean fix: Create and connect a timer for lifetime destruction
	get_tree().create_timer(lifetime).timeout.connect(destroy_bullet)

# To use this function, connect the 'body_entered' signal in the Node tab to this script
func _on_body_entered(_body: Node) -> void:
	destroy_bullet()

func destroy_bullet() -> void:
	if is_inside_tree():
		queue_free()

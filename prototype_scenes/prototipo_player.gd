extends CharacterBody3D

# Variables de caminar/velocidad
@export var max_speed := 6.5
@export var acceleration := 14.0
@export var friction := 10.0
@export var jump_force := 5.0
@export var mouse_sensitivity := 0.002
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Variables de agacharse
@export var crouch_speed_multiplier := 0.5
@export var crouch_height := 1.0
@export var stand_height := 1.8
@export var crouch_lerp_speed := 8.0
var is_crouching := false

# Variables de air control
@export var air_acceleration := 6.0
@export var air_speed_cap := 0.8

# Variables de armas
@export var shoot_range := 100.0
@export var shoot_damage := 25

# Camara settings
# Headbob
@export var headbob_frequency := 7.0
@export var headbob_amplitude := 0.04
var headbob_time := 0.0

# Balanceo lateral
@export var sway_amount := 2.0
@export var sway_speed := 6.0

# FOV dinamico al correr
@export var base_fov := 90.0
@export var run_fov := 97.0
@export var fov_lerp_speed := 6.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$Camera3D.fov = base_fov

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event.is_action_pressed("shoot"):
		shoot()

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
	
	# Direccion input
	var input_dir := Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += transform.basis.x

	# ____ AGACHARSE CONFIG (CROUCH) ____ #
	# Leer input
	var wants_to_crouch = Input.is_action_pressed("crouch")

	var capsule = $Collision.shape as CapsuleShape3D

	# Si quiere pararse
	if not wants_to_crouch:
		var height_difference = stand_height - capsule.height

		var can_stand = not test_move(
			global_transform,
			Vector3.UP * height_difference
		)
		
		if can_stand:
			is_crouching = false
		else: 
			is_crouching = true
	else:
		is_crouching = true

	var target_height = crouch_height if is_crouching else stand_height

	capsule.height = lerp(capsule.height, target_height, delta * crouch_lerp_speed)
	$Collision.position.y = capsule.height / 2.0

	# Cámara
	$Camera3D.position.y = lerp(
		$Camera3D.position.y,
		target_height,
		delta * crouch_lerp_speed
	)

	# ____ AGACHARSE CONFIG (CROUCH) ____ #

	input_dir = input_dir.normalized()
	
	# Movimiento horizontal
	var wish_speed = max_speed * (crouch_speed_multiplier if is_crouching else 1.0)
	#var accel = acceleration if is_on_floor() else acceleration * 0.4
	
	if is_on_floor():
		ground_move(input_dir, wish_speed, delta)
	else:
		air_move(input_dir, wish_speed, delta)
	
	move_and_slide()
	apply_camera_effects(delta)

func ground_move(input_dir: Vector3, wish_speed: float, delta: float):
	# Friccion
	if is_on_floor() and input_dir == Vector3.ZERO:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	# Aceleracion
	var current_speed := velocity.dot(input_dir)
	var add_speed = wish_speed - current_speed
	
	if add_speed <= 0:
		return
	
	var accel_speed = acceleration * delta * wish_speed
	accel_speed = min(accel_speed, add_speed)

	velocity += accel_speed * input_dir

	# if add_speed > 0:
	# 	var accel_speed = accel * delta * wish_speed
	# 	if accel_speed > add_speed:
	# 		accel_speed = add_speed
	# 	velocity += accel_speed * input_dir
	
func air_move(input_dir: Vector3, wish_speed: float, delta: float):
	if input_dir == Vector3.ZERO:
		return
	
	# Limitar velocidad en el aire
	wish_speed = min(wish_speed, max_speed * air_speed_cap)

	var current_speed = velocity.dot(input_dir)
	var add_speed = wish_speed - current_speed

	if add_speed <= 0:
		return
	
	var accel_speed = air_acceleration * delta * wish_speed
	accel_speed = min(accel_speed, add_speed)

	velocity += accel_speed * input_dir

func apply_camera_effects(delta):
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var target_height = crouch_height if is_crouching else stand_height
	
	# HEADBOB
	if is_on_floor() and horizontal_speed > 0.2:
		headbob_time += delta * headbob_frequency * horizontal_speed
		var bob_offset = sin(headbob_time) * headbob_amplitude
		$Camera3D.position.y = lerp($Camera3D.position.y, target_height + bob_offset, delta * 10)
	else:
		headbob_time = 0.0
		$Camera3D.position.y = lerp($Camera3D.position.y, target_height, delta * 10)
	
	# Balanceo lateral (roll)
	var input_axis = Input.get_axis("move_left", "move_right")
	var target_roll = -input_axis * sway_amount
	$Camera3D.rotation_degrees.z = lerp(
		$Camera3D.rotation_degrees.z,
		target_roll,
		sway_speed * delta
	)

	# FOV Dinamico
	var target_fov = run_fov if horizontal_speed > max_speed * 0.8 else base_fov
	$Camera3D.fov = lerp($Camera3D.fov, target_fov, fov_lerp_speed * delta)

func shoot():
	var space_state = get_world_3d().direct_space_state
	
	var from = $Camera3D.global_transform.origin
	var to = from + $Camera3D.global_transform.basis.z * -shoot_range
	$Camera3D.rotate_x(deg_to_rad(0.5))

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]

	var result = space_state.intersect_ray(query)

	if result: 
		print("Hit: ", result.collider.name)

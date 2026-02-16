extends CharacterBody3D

@export var max_speed := 6.5
@export var acceleration := 14.0
@export var friction := 10.0
@export var jump_force := 5.0
@export var mouse_sensitivity := 0.002

var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, deg_to_rad(-89), deg_to_rad(89))

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
	
	input_dir = input_dir.normalized()
	
	# Movimiento horizontal
	var wish_speed = max_speed
	var accel = acceleration if is_on_floor() else acceleration * 0.4
	
	# Aplicamos la aceleracion de antes
	var current_speed := velocity.dot(input_dir)
	var add_speed = wish_speed - current_speed
	
	if add_speed > 0:
		var accel_speed = accel * delta * wish_speed
		if accel_speed > add_speed:
			accel_speed = add_speed
		velocity += accel_speed * input_dir
	
	# Friccion cuando esta en el piso y no hay input
	if is_on_floor() and input_dir == Vector3.ZERO:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	move_and_slide()

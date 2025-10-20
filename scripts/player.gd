extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/mixamo_base/AnimationPlayer
@onready var unlock_timer: Timer = Timer.new()

const JUMP_VELOCITY = 4.5

var SPEED = 2.7
var walking_speed = 3.0
var running_speed = 5.0

var running = false
var is_locked = false

@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Captura o mouse na inicialização do jogo
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	animation_player.animation_finished.connect(on_animation_finished)
	
	add_child(unlock_timer)
	unlock_timer.timeout.connect(on_unlock_timeout)

func on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "kick" or anim_name == "knock_down":
		is_locked = false
		unlock_timer.stop()
	# Adiciona a condição para o pulo
	if anim_name == "jump":
		# Retorna para o idle/andando se a animação de pulo terminar
		if is_on_floor():
			if velocity.length() > 0.1:
				if running:
					animation_player.play("running")
				else:
					animation_player.play("walking")
			else:
				animation_player.play("idle")

func on_unlock_timeout() -> void:
	is_locked = false
	if animation_player.current_animation != "idle":
		animation_player.play("idle")

func _input(event: InputEvent) -> void:
	# Lida com o mouse (Esc) para mostrar/esconder o cursor
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	# Lida com o movimento do mouse para girar a câmera e o corpo do personagem
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Gira o corpo principal do personagem no eixo Y (horizontalmente).
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		
		# Gira o 'camera_mount' no eixo X (verticalmente).
		# A lógica para a rotação vertical já estava correta, garantimos que ela só seja executada
		# quando o mouse estiver capturado.
		camera_mount.rotate_x(deg_to_rad(clamp(camera_mount.rotation.x - event.relative.y * sens_vertical, deg_to_rad(-60), deg_to_rad(60))))

func _physics_process(delta: float) -> void:
	if is_locked:
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	# Lógica para o chute (tecla "kick")
	if Input.is_action_just_pressed("kick"):
		if animation_player.current_animation != "kick":
			animation_player.play("kick")
			is_locked = true
			unlock_timer.wait_time = animation_player.get_animation("kick").length
			unlock_timer.start()
		return

	# Lógica para a animação "knock_down" (tecla "G")
	if Input.is_action_just_pressed("knock_down"):
		if animation_player.current_animation != "knock_down":
			animation_player.play("knock_down")
			is_locked = true
			unlock_timer.wait_time = animation_player.get_animation("knock_down").length
			unlock_timer.start()
		return

	if Input.is_action_pressed("run"):
		SPEED = running_speed
		running = true
	else:
		SPEED = walking_speed
		running = false

	# Lógica de pulo
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Se estiver no chão e pular, toca a animação de pulo
		if Input.is_action_just_pressed("ui_accept"):
			velocity.y = JUMP_VELOCITY
			animation_player.play("jump")

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		$visuals.look_at(position + direction, Vector3.UP)
		
		if running:
			if animation_player.current_animation != "running":
				animation_player.play("running")
		else:
			if animation_player.current_animation != "walking":
				animation_player.play("walking")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
		if animation_player.current_animation != "idle" and is_on_floor():
			animation_player.play("idle")

	move_and_slide()

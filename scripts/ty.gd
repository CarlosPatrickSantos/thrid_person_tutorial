extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_ty: AnimationPlayer = $visuals/ty/AnimationPlayer
@onready var unlock_timer: Timer = Timer.new()

const JUMP_VELOCITY = 4.5

var SPEED = 2.7
var walking_speed = 1.5
var running_speed = 5.0

var running = false
var is_locked = false
var is_crouching = false # NOVA VARIÁVEL: Para rastrear o estado de agachamento

@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	animation_ty.animation_finished.connect(on_animation_finished)
	add_child(unlock_timer)
	unlock_timer.timeout.connect(on_unlock_timeout)

func on_animation_finished(anim_name: StringName) -> void:
	# Desbloqueia e zera o timer após o fim das animações de ataque/hurt
	if anim_name in ["Armature_006|mixamo_com|Layer0", "Armature_002|mixamo_com|Layer0", "Armature|mixamo_com|Layer0"]:
		is_locked = false
		unlock_timer.stop()

func on_unlock_timeout() -> void:
	is_locked = false
	if velocity.length_squared() < 0.1 and is_on_floor():
		animation_ty.play("Armature_001|mixamo_com|Layer0") # Idle

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
	# 1. AÇÕES ESPECIAIS (Prioridade Máxima) - Sem alteração
	
	if Input.is_action_just_pressed("punch") and not is_locked:
		if animation_ty.current_animation != "Armature|mixamo_com|Layer0":
			animation_ty.play("Armature|mixamo_com|Layer0") # Punch
		is_locked = true
		unlock_timer.wait_time = animation_ty.get_animation("Armature|mixamo_com|Layer0").length
		unlock_timer.start()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("special_h") and not is_locked:
		if animation_ty.current_animation != "Armature_006|mixamo_com|Layer0":
			animation_ty.play("Armature_006|mixamo_com|Layer0") # Kick (exemplo para H)
		is_locked = true
		unlock_timer.wait_time = animation_ty.get_animation("Armature_006|mixamo_com|Layer0").length
		unlock_timer.start()
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	if Input.is_action_just_pressed("kick"):
		if animation_ty.current_animation != "Armature_006|mixamo_com|Layer0":
			animation_ty.play("Armature_006|mixamo_com|Layer0") # Kick
			is_locked = true
			unlock_timer.wait_time = animation_ty.get_animation("Armature_006|mixamo_com|Layer0").length
			unlock_timer.start()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("knock_down"):
		if animation_ty.current_animation != "Armature_002|mixamo_com|Layer0":
			animation_ty.play("Armature_002|mixamo_com|Layer0") # Hurt
			is_locked = true
			unlock_timer.wait_time = animation_ty.get_animation("Armature_002|mixamo_com|Layer0").length
			unlock_timer.start()
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	# Se estiver bloqueado de um frame anterior, apenas move e retorna
	if is_locked:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# 2. GRAVIDADE E PULO - Sem alteração
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("ui_accept"):
			velocity.y = JUMP_VELOCITY
			animation_ty.play("Armature_005|mixamo_com|Layer0") # Jump
			
	# --- 2.5 AGACHADO (Tecla X) ---
	if Input.is_action_pressed("agachado") and is_on_floor() and not is_locked:
		# Ativa o estado agachado e toca a animação
		is_crouching = true
		velocity.x = 0
		velocity.z = 0
		if animation_ty.current_animation != "Armature_004|mixamo_com|Layer0":
			animation_ty.play("Armature_004|mixamo_com|Layer0") # Agachado (Armature_004)
	else:
		# Sai do estado agachado
		is_crouching = false
		
	# Bloqueia qualquer movimento e animação de corrida se estiver agachado
	if is_crouching:
		move_and_slide()
		return # Sai do loop para manter o personagem parado e agachado

	# 3. CORRIDA - Sem alteração
	if Input.is_action_pressed("run"):
		SPEED = running_speed
		running = true
	else:
		SPEED = walking_speed
		running = false

	# 4. MOVIMENTO E ANIMAÇÃO
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

		$visuals.look_at(position + direction, Vector3.UP)

		# Só muda para animação de movimento se não estiver pulando e estiver no chão
		if is_on_floor() and animation_ty.current_animation != "Armature_005|mixamo_com|Layer0":
			if running:
				if animation_ty.current_animation != "Armature_003|mixamo_com|Layer0":
					animation_ty.play("Armature_003|mixamo_com|Layer0") # Running
			else:
				if animation_ty.current_animation != "Armature_007|mixamo_com|Layer0":
					animation_ty.play("Armature_007|mixamo_com|Layer0") # Walking
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

		# Só volta para IDLE se não estiver pulando e estiver no chão
		if is_on_floor() and animation_ty.current_animation != "Armature_005|mixamo_com|Layer0":
			animation_ty.play("Armature_001|mixamo_com|Layer0") # Idle

	# 5. FINALIZA MOVIMENTO - Sem alteração
	move_and_slide()

## First-Person Controller for 03:17 vertical slice.
##
## CharacterBody3D-based. WASD movement, mouse look, gravity.
## No sprint, crouch, or jump — horror pacing, apartment building.
##
## Adds self to "player" group so TriggerZone can filter by group membership.

class_name FirstPersonController
extends CharacterBody3D


## Walking speed in meters per second.
@export var move_speed: float = 3.0

## Mouse sensitivity in radians per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.002

## Print debug messages to console.
@export var debug_enabled: bool = true


@onready var _camera: Camera3D = $Camera3D

var _camera_pitch: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_bootstrap_input_actions()
	if debug_enabled:
		print("[FPC] Ready. Position: ", global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)

	# Esc releases mouse — built-in ui_cancel action, always available.
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Click to recapture mouse after Esc release.
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement input.
	var input_dir := Vector2.ZERO
	input_dir.y -= Input.get_action_strength(&"move_forward")
	input_dir.y += Input.get_action_strength(&"move_backward")
	input_dir.x -= Input.get_action_strength(&"move_left")
	input_dir.x += Input.get_action_strength(&"move_right")
	input_dir = input_dir.normalized()

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()


func _rotate_camera(mouse_delta: Vector2) -> void:
	# Yaw: rotate the whole body.
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	# Pitch: rotate only the camera, clamped to straight up/down.
	_camera_pitch = clampf(
		_camera_pitch - mouse_delta.y * mouse_sensitivity,
		-PI / 2.0,
		PI / 2.0,
	)
	_camera.rotation.x = _camera_pitch


## Bootstrap input actions programmatically.
##
## This is temporary scaffolding to avoid hand-authoring serialized InputEvent
## objects in project.godot during bootstrap. Once the project is opened in the
## Godot editor, these should be configured via Project Settings > Input Map and
## this method should be removed.
##
## Action names are fixed and minimal — other scripts should use these same names.
func _bootstrap_input_actions() -> void:
	_add_key_action(&"move_forward", KEY_W)
	_add_key_action(&"move_backward", KEY_S)
	_add_key_action(&"move_left", KEY_A)
	_add_key_action(&"move_right", KEY_D)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

extends Control

## An isolated 3D clinic inside the shared, cursor-driven game shell.

signal care_pressed
signal care_released

const Art := preload("res://games/asmr_doctor/clinic_3d_art.gd")
const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const DOCTOR_POSITION := Vector3(0.0, 1.58, 0.85)
const LOOK_SPEED := 0.003
const YAW_LIMIT := 1.2
const PITCH_LIMIT := 0.6

var patient_id := "mira"
var tool_id := "whisper"
var caring := false
var sleeping := false
var motion_enabled := true
var rhythm := 0.0
var hud_unit := 1.0
var _art := Art.new()
var _viewport: SubViewport
var _camera: Camera3D
var _input_enabled := false
var _looking := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _look_origin := Vector2.ZERO
var _pointer := Vector2.ZERO
var _yaw := 0.0
var _pitch := -0.08
var _time := 0.0
var _night := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_viewport = SubViewport.new()
	_viewport.name = "ClinicViewport"
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	var room := Node3D.new()
	room.name = "Room"
	_viewport.add_child(room)
	_camera = Camera3D.new()
	_camera.name = "DoctorCamera"
	_camera.position = DOCTOR_POSITION
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)
	_camera.fov = 62.0
	_camera.near = 0.04
	_camera.far = 30.0
	_camera.current = true
	room.add_child(_camera)
	_art.build(room, _camera)
	_art.set_patient(patient_id)
	_art.set_tool(tool_id)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = _viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.show_behind_parent = true
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_resize_viewport)
	_resize_viewport()
	_update_visibility()


func update_clinic(
	patient: String,
	tool: String,
	stress: float,
	night: bool,
	resting: bool,
	treating: bool,
	favorite: bool,
	phase: float
) -> void:
	if patient_id != patient:
		patient_id = patient
		_art.set_patient(patient)
	if tool_id != tool:
		tool_id = tool
		_art.set_tool(tool)
	if _night != night:
		_night = night
		_art.set_night(night)
	sleeping = resting
	caring = treating
	rhythm = phase
	_art.patient.visible = not resting
	_art.set_expression(stress, favorite)
	accessibility_name = (
		"First-person doctor view of %s. Hold right mouse to look."
		% Options.PATIENTS[patient_id]["name"]
	)
	queue_redraw()


func set_equipment(plant: String, lamp: String, rug: String) -> void:
	_art.set_equipment(plant, lamp, rug)


func set_active(active: bool) -> void:
	visible = active
	_update_visibility()


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		release_look()


func set_motion(enabled: bool) -> void:
	motion_enabled = enabled
	if not enabled:
		_time = 0.0
		_art.animate(0.0, caring, _pointer, false)
	queue_redraw()


func release_look() -> void:
	if not _looking:
		return
	_looking = false
	Input.mouse_mode = _previous_mouse_mode
	if (
		_previous_mouse_mode == Input.MOUSE_MODE_VISIBLE
		and is_inside_tree()
		and DisplayServer.get_name() != "headless"
	):
		get_viewport().warp_mouse(_look_origin)
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Capture before GUI dispatch so releasing look cannot leave a held GUI drag.
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		if _input_enabled and is_visible_in_tree() and get_global_rect().has_point(event.position):
			_look_origin = event.position
			_previous_mouse_mode = Input.mouse_mode
			_pointer = Vector2.ZERO
			_looking = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			queue_redraw()
		return
	# Captured input must work even when the window center is over the side panel.
	if not _looking:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			release_look()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				care_pressed.emit()
			else:
				care_released.emit()
		else:
			return
	elif event is InputEventMouseMotion:
		_yaw = clampf(_yaw - event.screen_relative.x * LOOK_SPEED, -YAW_LIMIT, YAW_LIMIT)
		_pitch = clampf(_pitch - event.screen_relative.y * LOOK_SPEED, -PITCH_LIMIT, PITCH_LIMIT)
		_camera.rotation = Vector3(_pitch, _yaw, 0.0)
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMouseMotion:
		_pointer = ((event.position / size.max(Vector2.ONE) - Vector2(0.5, 0.5)) * 2.0).clamp(
			-Vector2.ONE, Vector2.ONE
		)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				care_pressed.emit()
			else:
				care_released.emit()
		else:
			return
		accept_event()


func _process(delta: float) -> void:
	if motion_enabled:
		_time += delta
	_art.animate(_time, caring, _pointer, motion_enabled)


func _draw() -> void:
	if sleeping:
		_caption("a moment for you / no goals. just quiet.")
		return
	_caption("Hold right mouse to look / release for menus")
	var radius := minf(28.0 * hud_unit, minf(size.x, size.y) * 0.12)
	var center := Vector2(size.x - radius - 14.0 * hud_unit, radius + 14.0 * hud_unit)
	var color: Color = Options.TOOLS[tool_id]["color"]
	draw_circle(center, radius + 5.0 * hud_unit, Color(0.12, 0.16, 0.16, 0.7))
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.5), 1.5 * hud_unit, true)
	draw_arc(center, radius * (0.25 + rhythm * 0.75), 0.0, TAU, 48, color, 2.0 * hud_unit, true)
	draw_circle(center, 2.0 * hud_unit, color)
	if _looking:
		draw_circle(size * 0.5, 2.0 * hud_unit, Color("f6e5c4"))


func _caption(text: String) -> void:
	var font := get_theme_default_font()
	var pixels := maxi(1, roundi(13.0 * hud_unit))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	if width > size.x - 24.0 * hud_unit:
		text = "RMB: look / release: cursor" if not sleeping else "no goals. just quiet."
	draw_rect(
		Rect2(0.0, size.y - 30.0 * hud_unit, size.x, 30.0 * hud_unit), Color(0.1, 0.14, 0.14, 0.7)
	)
	draw_string(
		font,
		Vector2(12.0 * hud_unit, size.y - 10.0 * hud_unit),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 24.0 * hud_unit,
		pixels,
		Color("f6e5c4")
	)


func _resize_viewport() -> void:
	var dimensions := size.max(Vector2.ONE)
	var scale := minf(1.0, minf(1280.0 / dimensions.x, 1024.0 / dimensions.y))
	_viewport.size = Vector2i((dimensions * scale).max(Vector2.ONE))
	queue_redraw()


func _update_visibility() -> void:
	if _viewport == null:
		return
	var active := is_visible_in_tree()
	set_process(active)
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_WHEN_VISIBLE if active else SubViewport.UPDATE_DISABLED
	)
	if not active:
		release_look()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_visibility()
	elif what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_look()


func _exit_tree() -> void:
	release_look()

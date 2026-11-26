extends RefCounted

## Uses real care inputs and patient transitions, never accelerated treatment.

signal keycap_requested(text: String)

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
var _fresh := false
var _stage := 0
var _next_tap := 16.4
var _held: InputEventKey
var _releases: Array[InputEventKey] = []


func configure(variant: String) -> bool:
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return [
		{"time": 0.0, "title": "Make a little room for quiet",
			"body": "You're the doctor. Hold right mouse to look; C switches views. Choose a gentle tool."},
		{"time": 3.0, "title": "A soft, steady hush",
			"body": "Hold the care button or care key for whispers and brushing."},
		{"time": 9.0, "title": "Listen to their reaction",
			"body": "Favorite sounds calm faster. Your discoveries stay in the patient journal."},
		{"time": 16.0, "title": "Another friend, another favorite",
			"body": "Choose wooden taps. Press once per rhythm ring; long pauses are fine."},
		{"time": 25.0, "title": "New tools arrive gently",
			"body": "Completed care unlocks tools. Finish three appointments for cosmetic tokens."},
		{"time": 29.0, "title": "Make space for yourself",
			"body": "Rest mode suspends care. Mix a soundscape and return whenever you like."},
		{"time": 34.0, "title": "Quiet, on your terms",
			"body": "The microphone is optional and off by default. Every tool works without it."},
	]


func duration() -> float:
	return 39.0


func settings_overrides() -> Dictionary:
	var values := {"ui/scale": 1.0, Options.LIGHTING_KEY: 1}
	for definition: Dictionary in Options.CONTROL_BINDINGS:
		values[str(definition["key"])] = definition["default"]
	return values


func configure_session(session: Node) -> void:
	session.call("configure_single_player")


func start(scene: Node) -> void:
	var progress: RefCounted = scene.get("_progress")
	_fresh = int(progress.get("total_visits")) == 0
	if not _fresh:
		push_error("ASMR Doctor walkthrough requires a fresh, isolated save profile.")
	_reveal(scene, "%Reaction")


func update(scene: Node, time: float, _delta: float) -> void:
	_release_keys()
	if not _fresh or not bool(scene.get("_round_active")):
		return
	match _stage:
		0:
			if time >= 3.0:
				_reveal(scene, "%ToolTray/Tool_whisper")
				_held = _press(Options.TREAT_ACTION, true)
				_stage = 1
		1:
			if time >= 9.0:
				_reveal(scene, "%Reaction")
				_stage = 2
		2:
			if time >= 16.0:
				_release_hold()
				scene.call("_next_patient")
				_press(Options.TOOL_ACTIONS[1])
				_reveal(scene, "%ToolTray/Tool_tap")
				_stage = 3
		3:
			if time >= 25.0:
				_reveal(scene, "%ToolTray/Tool_paper")
				_stage = 4
			elif time >= _next_tap:
				_press(Options.TREAT_ACTION)
				_next_tap += 1.1
		4:
			if time >= 26.0:
				scene.call("_next_patient")
				_press(Options.TOOL_ACTIONS[2])
				_reveal(scene, "%ToolTray/Tool_brush")
				_stage = 5
		5:
			if time >= 26.5:
				_reveal(scene, "%Reaction")
				_held = _press(Options.TREAT_ACTION, true)
				_stage = 6
		6:
			if time >= 29.0:
				_release_hold()
				_press(Options.SLEEP_ACTION)
				_stage = 7
		7:
			if time >= 30.0:
				_press(Options.SOUNDS_ACTION)
				_stage = 8
		8:
			if time >= 34.0:
				scene.call("_close_sheet")
				_stage = 9


func validate_finished(scene: Node) -> bool:
	_release_hold()
	_release_keys()
	var progress: RefCounted = scene.get("_progress")
	var microphone: Node = scene.get("_mic")
	var complete := _fresh and _stage == 9 and int(progress.get("total_visits")) == 2 \
		and (progress.get("favorites") as Array).size() == 3 \
		and bool(scene.get("_sleep_mode")) and not bool(microphone.get("active")) \
		and int(scene.get("_save_error")) == OK
	if not complete:
		push_error("ASMR Doctor walkthrough: stage %d, visits %d, favorites %s, rest %s, focus %s." % [
			_stage, int(progress.get("total_visits")), progress.get("favorites"),
			scene.get("_sleep_mode"), scene.get("_focus_suspended"),
		])
	return complete


func _reveal(scene: Node, target: String) -> void:
	scene.get_node("%PatientScroll").call_deferred("ensure_control_visible", scene.get_node(target))


func _press(action: StringName, hold := false) -> InputEventKey:
	for source in InputMap.action_get_events(action):
		if source is InputEventKey:
			var event := source.duplicate() as InputEventKey
			event.pressed = true
			event.echo = false
			Input.parse_input_event(event)
			if not hold:
				_releases.append(event)
			keycap_requested.emit(OS.get_keycode_string(event.physical_keycode))
			return event
	push_error("ASMR Doctor walkthrough could not resolve action %s." % action)
	return null


func _release_hold() -> void:
	if _held != null:
		_releases.append(_held)
		_held = null
		_release_keys()


func _release_keys() -> void:
	for press in _releases:
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
	_releases.clear()

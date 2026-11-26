extends SceneTree

## Camera switching, real care, six appointments, pause, saves and layouts.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const Fixture := preload("res://games/asmr_doctor/tests/progress_fixture.gd")
var _failures := PackedStringArray()
var _fixture := Fixture.new()
var _packed: PackedScene
var _settings: Node
var _original_settings: Dictionary = {}
var _opened: Array[Node] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	GameCatalog.select(Options.GAME_ID)
	root.get_node("GameSession").call("configure_single_player")
	_settings = root.get_node("Settings")
	for key: String in ["ui/scale", "accessibility/reduced_motion",
		Options.SILENT_KEY, Options.RAIN_KEY, Options.FIRE_KEY, Options.ROOM_KEY,
		"controls/asmr_doctor_camera"]:
		_original_settings[key] = _settings.call("get_value", key)
	_settings.call("set_value", "ui/scale", 1.0)
	_packed = load("res://games/asmr_doctor/gameplay.tscn") as PackedScene
	if _packed == null or _fixture.begin(self) != OK:
		printerr("ASMR Doctor scene fixture could not initialize.")
		quit(1)
		return
	var game := await _open()
	await _test_camera(game)
	await _test_input_and_boundaries(game)
	await _test_layouts(game)
	await _test_two_shifts(game)
	game.free()
	game = await _open()
	var progress: RefCounted = game.get("_progress")
	_expect(int(progress.get("total_visits")) == 6 and int(progress.get("completed_shifts")) == 2,
		"Reopening the clinic must retain all completed care and shifts.")
	_expect(not bool((game.get_node("%Microphone")).get("active")),
		"Reloading must never reopen the microphone.")
	game.free()
	await _test_damaged_save()
	for node in _opened:
		if is_instance_valid(node):
			node.free()
	_expect(_fixture.restore() == OK, "The player's clinic progress must be restored.")
	for key: String in _original_settings:
		_settings.call("set_value", key, _original_settings[key])
	await create_timer(0.3, true, false, true).timeout
	if _failures.is_empty():
		print("ASMR Doctor scene tests passed (%s)." % DisplayServer.get_name())
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _open() -> Node:
	var game := _packed.instantiate()
	root.add_child(game)
	_opened.append(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	return game


func _test_input_and_boundaries(game: Node) -> void:
	var model: RefCounted = game.get("_session")
	var mic := game.get_node("%Microphone")
	_expect(bool(game.get("_round_active")) and (game.get_node("%RoundTimer") as Timer).is_stopped(),
		"The clinic must run without an arcade deadline.")
	var baseline := float(model.get("stress"))
	game.call("_update_round", 30.0, 0.0)
	_expect(float(model.get("stress")) == baseline, "An idle clinic must make no treatment progress.")
	var care := game.get_node("%CareButton") as Button
	await _reveal(game, care)
	_pointer(care, true)
	game.call("_update_round", 1.0, 0.0)
	_pointer(care, false)
	var after_pointer := float(model.get("stress"))
	game.call("_update_round", 1.0, 0.0)
	_expect(after_pointer < baseline and float(model.get("stress")) == after_pointer,
		"Real pointer holding must soothe once and stop on release.")
	_key("controls/asmr_doctor_treat", true)
	game.call("_update_round", 1.0, 0.0)
	_key("controls/asmr_doctor_treat", false)
	_expect(float(model.get("stress")) < after_pointer,
		"The actual rebindable keyboard hold must share the pointer treatment.")
	await _click(game, game.get_node("%MicButton") as Button)
	_expect(bool(game.get_node("%SheetShade").get("visible")) and not bool(mic.get("active")),
		"The microphone button must explain consent before opening hardware.")
	await _click(game, game.get_node("%SheetContent/CloseSheet") as Button)
	await _click(game, game.get_node("%JournalButton") as Button)
	baseline = float(model.get("stress"))
	game.call("_update_round", 50.0, 0.0)
	_expect(float(model.get("stress")) == baseline and not bool(mic.get("active")),
		"Journal reading must suspend care and close capture.")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	_expect(not bool(game.get_node("%SheetShade").get("visible")) and not paused,
		"Escape must close a clinic sheet without also opening pause.")
	await _click(game, game.get_node("%RestButton") as Button)
	game.call("_update_round", 100.0, 0.0)
	_expect(bool(game.get("_sleep_mode")) and float(model.get("stress")) == baseline,
		"Rest mode must have no scoring, care progress or microphone.")
	await _click(game, game.get_node("%ReturnFromRest") as Button)
	_key("controls/asmr_doctor_treat", true)
	game.call("open_pause_menu")
	_expect(paused and not bool(game.get("_key_held")) and not bool(mic.get("active")),
		"Shared pause must release held actions and microphone capture.")
	game.call("_update_round", 10.0, 0.0)
	_expect(float(model.get("stress")) == baseline, "Paused time must not soothe patients.")
	var pause: Node = game.get("_pause_menu")
	pause.call("resume")
	await process_frame
	_key("controls/asmr_doctor_treat", false)
	_key("controls/asmr_doctor_treat", true)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.call("_update_round", 10.0, 0.0)
	_expect(not bool(game.get("_key_held")) and float(model.get("stress")) == baseline,
		"Losing application focus must stop input, not leave a stuck treatment.")
	game.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_key("controls/asmr_doctor_treat", false)
	_key("controls/asmr_doctor_treat", true)
	mic.set("active", true)
	mic.set("normalized_level", 0.4)
	root.focus_exited.emit()
	game.call("_update_round", 10.0, 0.0)
	_expect(bool(game.get("_focus_suspended")) and not bool(game.get("_key_held"))
		and not bool(mic.get("active")) and float(model.get("stress")) == baseline,
		"Window focus signals must stop capture and held care, including on Web.")
	root.focus_entered.emit()
	_expect(not bool(game.get("_focus_suspended")) and not bool(mic.get("active")),
		"Window focus returning must allow care without reopening the microphone.")
	_key("controls/asmr_doctor_treat", false)
	await _click(game, game.get_node("%SoundsButton") as Button)
	var rain := game.get_node("%SheetContent/Mix_rain") as HSlider
	rain.value = 0.65
	_expect(is_equal_approx(float(_settings.call("tunable", Options.RAIN_KEY)), 0.65),
		"The real soundscape slider must update persistent, manifest-owned settings.")
	await _click(game, game.get_node("%SheetContent/CloseSheet") as Button)


func _test_camera(game: Node) -> void:
	var first_person := game.get_node("%Clinic3D") as Control
	var overview := game.get_node("%ClinicView") as Control
	var camera := first_person.get("_camera") as Camera3D
	var viewport := first_person.get("_viewport") as SubViewport
	var model: RefCounted = game.get("_session")
	var position := camera.position
	_expect(first_person.visible and not overview.visible and camera.current
		and viewport.own_world_3d,
		"The clinic must start in an isolated, actual first-person Camera3D view.")
	var baseline := float(model.get("stress"))
	_view_pointer(first_person, MOUSE_BUTTON_LEFT, true)
	game.call("_update_round", 0.5, 0.0)
	var drift := InputEventMouseMotion.new()
	drift.position = first_person.get_global_rect().end + Vector2(1000, 1000)
	drift.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(drift, true)
	var pointer: Vector2 = first_person.get("_pointer")
	_expect(pointer.abs().x <= 1.0 and pointer.abs().y <= 1.0,
		"Dragging care outside the clinic must keep the foreground tools in reach.")
	_view_pointer(first_person, MOUSE_BUTTON_LEFT, false, Vector2(5, 5))
	_expect(float(model.get("stress")) < baseline and not bool(game.get("_pointer_held")),
		"Clicking the 3D clinic must give care and release outside its bounds.")
	_view_pointer(first_person, MOUSE_BUTTON_RIGHT, true)
	var original_rotation := camera.rotation
	_look(Vector2(55, -20))
	_expect(bool(first_person.get("_looking")) and camera.rotation != original_rotation
		and camera.position == position,
		"Right-button mouse-look must rotate a real camera without moving the doctor.")
	_look(Vector2(10000, -10000))
	_expect(absf(camera.rotation.y) <= 1.20001 and absf(camera.rotation.x) <= 0.60001,
		"Mouse-look must stay within comfortable yaw and pitch limits.")
	_key("controls/asmr_doctor_treat", true)
	_key("controls/asmr_doctor_camera", true)
	_key("controls/asmr_doctor_camera", false)
	_key("controls/asmr_doctor_treat", false)
	_expect(not first_person.visible and overview.visible
		and not bool(first_person.get("_looking")) and not bool(game.get("_key_held"))
		and not bool(game.get("_pointer_held")) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Switching cameras must restore the cursor and stop held care.")
	baseline = float(model.get("stress"))
	_view_pointer(overview, MOUSE_BUTTON_LEFT, true)
	game.call("_update_round", 0.5, 0.0)
	_view_pointer(overview, MOUSE_BUTTON_LEFT, false)
	_expect(float(model.get("stress")) < baseline,
		"The preserved illustrated room must still support pointer care.")
	await _click(game, game.get_node("%CameraButton") as Button)
	_expect(first_person.visible and not overview.visible,
		"The on-screen view button must return to the doctor's camera.")
	_settings.call("set_value", "controls/asmr_doctor_camera", KEY_V)
	_expect((game.get_node("%CameraButton") as Button).text.ends_with("/ V"),
		"The camera button must display the shared rebindable camera key.")
	_key("controls/asmr_doctor_camera", true)
	_key("controls/asmr_doctor_camera", false)
	_expect(overview.visible, "Rebinding the camera action must change the actual switch key.")
	_key("controls/asmr_doctor_camera", true)
	_key("controls/asmr_doctor_camera", false)
	_settings.call("set_value", "controls/asmr_doctor_camera",
		_original_settings["controls/asmr_doctor_camera"])
	_view_pointer(first_person, MOUSE_BUTTON_RIGHT, true)
	_view_pointer(first_person, MOUSE_BUTTON_LEFT, true)
	_expect(bool(game.get("_pointer_held")),
		"Left-button care must work while looking, even over the shell's side panel.")
	_view_pointer(first_person, MOUSE_BUTTON_LEFT, false, Vector2(5, 5))
	_view_pointer(first_person, MOUSE_BUTTON_RIGHT, false, Vector2(5, 5))
	_expect(not bool(first_person.get("_looking")) and not bool(game.get("_pointer_held"))
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Releasing right mouse outside the clinic must always restore the cursor.")
	_view_pointer(first_person, MOUSE_BUTTON_RIGHT, true)
	game.call("_open_sheet", "journal")
	_key("controls/asmr_doctor_camera", true)
	_key("controls/asmr_doctor_camera", false)
	_expect(not bool(first_person.get("_looking")) and first_person.visible,
		"Opening a sheet must release mouse-look and block camera switching behind it.")
	game.call("_close_sheet")
	_view_pointer(first_person, MOUSE_BUTTON_RIGHT, true)
	game.call("open_pause_menu")
	_expect(not bool(first_person.get("_looking"))
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Pause must release the captured cursor for shared menus.")
	var pause: Node = game.get("_pause_menu")
	pause.call("resume")
	await process_frame
	_expect(bool(first_person.get("_input_enabled")) and not bool(first_person.get("_looking")),
		"Resuming must allow mouse-look without automatically recapturing the cursor.")
	_view_pointer(first_person, MOUSE_BUTTON_RIGHT, true)
	root.focus_exited.emit()
	_expect(not bool(first_person.get("_looking"))
		and not bool(first_person.get("_input_enabled"))
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Focus loss must stop camera input and release mouse capture.")
	root.focus_entered.emit()
	_view_pointer(first_person, MOUSE_BUTTON_RIGHT, true)
	game.call("_toggle_rest")
	_expect(not bool(first_person.get("_looking")) and bool(first_person.get("sleeping")),
		"Rest mode must release mouse-look and remove the 3D patient.")
	game.call("_toggle_rest")


func _test_layouts(game: Node) -> void:
	for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(844, 390),
		Vector2i(1280, 720), Vector2i(2560, 1080)]:
		root.size = dimensions
		await process_frame
		await process_frame
		await process_frame
		game.call("_layout_clinic")
		await process_frame
		var clinic := game.get_node("%Clinic") as Control
		var scroll := game.get_node("%PatientScroll") as ScrollContainer
		var bounds := root.get_visible_rect()
		_expect(clinic.position.x >= 0 and clinic.position.y >= 0
			and clinic.get_rect().end.x <= bounds.end.x + 2
			and clinic.get_rect().end.y <= bounds.end.y + 2
			and scroll.size.y > 0,
			"Clinic must fit at %s (clinic %s, viewport %s, scroll %s)." % [
				dimensions, clinic.get_rect(), bounds, scroll.size,
			])
		var tools: Dictionary = game.get("_tool_buttons")
		var camera_button := game.get_node("%CameraButton") as Button
		_expect(bounds.encloses(camera_button.get_global_rect()),
			"The on-screen camera switch must stay reachable at %s." % dimensions)
		for button: Button in tools.values():
			_expect(button.size.x <= scroll.size.x + 1,
				"Treatment buttons must fit their scroll area at %s." % dimensions)
		game.call("_open_sheet", "journal")
		await process_frame
		var sheet := game.get_node("%SheetPanel") as Control
		_expect(sheet.position.x >= 0 and sheet.position.y >= 0
			and sheet.get_rect().end.x <= bounds.end.x + 2
			and sheet.get_rect().end.y <= bounds.end.y + 2,
			"The journal sheet must remain within the viewport at %s." % dimensions)
		game.call("_close_sheet")
	root.size = Vector2i(1280, 720)
	await process_frame
	_settings.call("set_value", "accessibility/reduced_motion", true)
	_expect(not bool(game.get_node("%ClinicView").get("motion_enabled")),
		"Reduced motion must park the original clinic illustration.")
	_expect(not bool(game.get_node("%Clinic3D").get("motion_enabled")),
		"Reduced motion must also park 3D patient and held-tool animations.")
	_settings.call("set_value", "accessibility/reduced_motion", false)


func _test_two_shifts(game: Node) -> void:
	var store := root.get_node("Store")
	var starting_wallet := int(store.call("points", Options.GAME_ID))
	for shift in 2:
		for appointment in Options.APPOINTMENTS_PER_SHIFT:
			var model: RefCounted = game.get("_session")
			var patient_id := str(model.get("patient_id"))
			_expect(str(game.get_node("%Clinic3D").get("patient_id")) == patient_id,
				"The 3D patient must follow each real appointment transition.")
			var tool := str(Options.PATIENTS[patient_id]["favorite"])
			var buttons: Dictionary = game.get("_tool_buttons")
			await _click(game, buttons[tool])
			var attempts := 0
			while not bool(model.get("complete")) and attempts < 120:
				attempts += 1
				if str(Options.TOOLS[tool]["kind"]) == "hold":
					_key("controls/asmr_doctor_treat", true)
					game.call("_update_round", 0.5, 0.0)
					_key("controls/asmr_doctor_treat", false)
				else:
					game.call("_update_round", float(Options.TOOLS[tool]["period"]), 0.0)
					_key("controls/asmr_doctor_treat", true)
					_key("controls/asmr_doctor_treat", false)
			_expect(bool(model.get("complete")), "Real controls must fully soothe " + patient_id)
			if not bool(model.get("complete")):
				return
			_expect((game.get_node("%NextPatient") as Button).visible,
				"A calm patient must expose a player-paced next appointment.")
			var progress: RefCounted = game.get("_progress")
			var before := int(progress.get("total_visits"))
			game.call("_complete_appointment")
			_expect(int(progress.get("total_visits")) == before,
				"An appointment must be recorded only once.")
			await _click(game, game.get_node("%NextPatient") as Button)
		_expect(not bool(game.get("_round_active"))
			and int(store.call("points", Options.GAME_ID)) == starting_wallet + (shift + 1) * Options.SHIFT_TOKENS,
			"Only a genuinely completed three-patient shift must pay its exact cosmetic reward.")
		if shift == 0:
			game.call("_on_play_again_pressed")
			await process_frame
	var progress: RefCounted = game.get("_progress")
	_expect((progress.get("favorites") as Array).size() == 6
		and bool(progress.call("all_patients_helped")),
		"Two shifts must introduce all six patients and discover all six preferences.")
	_expect(bool(store.call("purchase", Options.GAME_ID, "asmr_moonflowers"))
		and str(store.call("equipped_id", Options.GAME_ID, Options.PLANT_SLOT)) == "asmr_moonflowers"
		and str(game.get_node("%ClinicView").get("plant_id")) == "asmr_moonflowers",
		"Earned currency must buy and visibly equip clinic decor through the shared Store.")
	var art: RefCounted = game.get_node("%Clinic3D").get("_art")
	_expect(str(art.get("_plant_id")) == "asmr_moonflowers",
		"Purchased decor must update the 3D clinic as well as the illustrated view.")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Finishing a shift must leave the cursor available for results and menus.")


func _test_damaged_save() -> void:
	var file := ConfigFile.new()
	file.set_value("clinic", "version", 999)
	file.save(Options.SAVE_PATH)
	var bytes := FileAccess.get_file_as_bytes(Options.SAVE_PATH)
	var game := await _open()
	game.call("_update_round", 200.0, 0.0)
	(game.get_node("%CareButton") as Button).button_down.emit()
	game.call("_update_round", 10.0, 0.0)
	_expect((game.get_node("%CareButton") as Button).disabled
		and (game.get_node("%SaveStatus") as Label).text.contains("Nothing was overwritten")
		and FileAccess.get_file_as_bytes(Options.SAVE_PATH) == bytes,
		"A damaged/newer save must explain recovery, disable earning and remain untouched.")
	game.call("_toggle_rest")
	_expect(bool(game.get("_sleep_mode")), "An unreadable save must not prevent no-goal rest mode.")
	game.free()


func _reveal(game: Node, button: Button) -> void:
	for name: String in ["PatientScroll", "RestScroll", "SheetScroll"]:
		var scroll := game.get_node("%" + name) as ScrollContainer
		if scroll.is_ancestor_of(button):
			scroll.ensure_control_visible(button)
	await process_frame
	await process_frame


func _click(game: Node, button: Button) -> void:
	await _reveal(game, button)
	_pointer(button, true)
	_pointer(button, false)
	await process_frame


func _pointer(button: Button, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)


func _view_pointer(view: Control, button: MouseButton, pressed: bool,
	position := Vector2.INF) -> void:
	var event := InputEventMouseButton.new()
	event.position = view.get_global_rect().get_center() if position == Vector2.INF else position
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)


func _look(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	root.push_input(event, true)


func _key(binding: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = int(_settings.call("binding_keycode", binding))
	event.pressed = pressed
	root.push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

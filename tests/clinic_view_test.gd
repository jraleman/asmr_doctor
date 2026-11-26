extends SceneTree

## Real Compatibility rendering in both perspectives, all tools and compact UI.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
var _failures := PackedStringArray()
var _output := ""
var _settings: Node
var _old_scale: Variant


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Clinic view tests require a real graphics window, not --headless.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--asmr-capture="):
			_output = argument.trim_prefix("--asmr-capture=")
	if not _output.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_output) == OK,
			"Render capture directory must be writable.")
	root.size = Vector2i(1280, 720)
	GameCatalog.select(Options.GAME_ID)
	root.get_node("GameSession").call("configure_single_player")
	_settings = root.get_node("Settings")
	_old_scale = _settings.call("get_value", "ui/scale", 1.0)
	_settings.call("set_value", "ui/scale", 1.0)
	var packed := load("res://games/asmr_doctor/gameplay.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var view := game.get_node("%ClinicView") as Control
	var first_person := game.get_node("%Clinic3D") as Control
	view.call("set_motion", false)
	var portraits: Array[int] = []
	var first_person_portraits: Array[int] = []
	for id in Options.PATIENT_ORDER:
		var queue: Array[String] = [id, "mira", "nimbus"]
		game.set("_queue", queue)
		game.set("_appointment_index", 0)
		game.call("_begin_appointment")
		view.call("set_motion", false)
		first_person.call("set_motion", false)
		await _settle()
		var image := root.get_texture().get_image()
		var first_crop := _portrait_rect(first_person, image)
		var first_fingerprint := hash(image.get_region(first_crop).get_data())
		_expect(not first_person_portraits.has(first_fingerprint),
			"Each patient must have distinct actual 3D artwork: " + id)
		first_person_portraits.append(first_fingerprint)
		_expect(_has_picture(first_person, image),
			"The first-person camera must render warm-colored 3D artwork: " + id)
		_capture(image, "doctor_" + id)
		game.call("_toggle_camera")
		view.call("set_motion", false)
		await _settle()
		image = root.get_texture().get_image()
		var crop := _portrait_rect(view, image)
		var fingerprint := hash(image.get_region(crop).get_data())
		_expect(not portraits.has(fingerprint), "Each patient must have distinct rendered artwork: " + id)
		portraits.append(fingerprint)
		_expect(not image.is_empty() and _has_picture(view, image),
			"The clinic must render actual warm-colored artwork: " + id)
		_capture(image, "clinic_" + id)
		game.call("_toggle_camera")
	await _test_3d_tools_and_look(game, first_person)
	for layout: Dictionary in [
		{"size": Vector2i(320, 568), "scale": 1.0},
		{"size": Vector2i(844, 390), "scale": 1.0},
		{"size": Vector2i(2560, 1080), "scale": 1.0},
		{"size": Vector2i(1280, 720), "scale": 2.0},
	]:
		var dimensions: Vector2i = layout["size"]
		root.size = dimensions
		_settings.call("set_value", "ui/scale", layout["scale"])
		await _settle()
		game.call("_layout_clinic")
		await _settle()
		var scroll := game.get_node("%PatientScroll") as ScrollContainer
		var care := game.get_node("%CareButton") as Button
		if scroll.is_ancestor_of(care):
			scroll.ensure_control_visible(care)
		await _settle()
		_expect(care.is_visible_in_tree() and root.get_visible_rect().has_point(
			care.get_global_rect().get_center()),
			"Rendered care controls must remain reachable at %s." % dimensions)
		var switch := game.get_node("%CameraButton") as Button
		_expect(root.get_visible_rect().encloses(switch.get_global_rect()),
			"The rendered camera switch must remain reachable at %s." % dimensions)
		_capture(root.get_texture().get_image(), "layout_%dx%d_scale%.1f" % [
			dimensions.x, dimensions.y, float(layout["scale"]),
		])
	root.size = Vector2i(1280, 720)
	_settings.call("set_value", "ui/scale", 1.0)
	game.call("_open_sheet", "journal")
	await _settle()
	_capture(root.get_texture().get_image(), "patient_journal")
	game.call("_open_sheet", "sounds")
	await _settle()
	_capture(root.get_texture().get_image(), "soundscapes")
	game.call("_close_sheet")
	game.call("_toggle_rest")
	await _settle()
	_capture(root.get_texture().get_image(), "rest_mode")
	game.free()
	await _test_welcome()
	_settings.call("set_value", "ui/scale", _old_scale)
	await create_timer(0.3, true, false, true).timeout
	if _failures.is_empty():
		print("ASMR Doctor rendered clinic tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_3d_tools_and_look(game: Node, view: Control) -> void:
	var viewport := view.get("_viewport") as SubViewport
	var tools: Array[int] = []
	for id in Options.TOOL_ORDER:
		view.call("update_clinic", "mira", id, 50.0, false, false, true, false, 0.6)
		view.call("set_motion", false)
		await _settle()
		var image := viewport.get_texture().get_image()
		var area := Rect2i(Vector2i(image.get_width() * 0.4, image.get_height() * 0.5),
			Vector2i(image.get_width() * 0.6, image.get_height() * 0.5))
		var fingerprint := hash(image.get_region(area).get_data())
		_expect(not tools.has(fingerprint),
			"Every selected tool must have distinct rendered foreground geometry: " + id)
		tools.append(fingerprint)
		_capture(root.get_texture().get_image(), "doctor_tool_" + id)
	view.call("update_clinic", "mira", "brush", 20.0, true, false, false, true, 0.6)
	view.call("set_motion", false)
	await _settle()
	_capture(root.get_texture().get_image(), "doctor_midnight")
	var before := hash(viewport.get_texture().get_image().get_data())
	var camera := view.get("_camera") as Camera3D
	var position := camera.position
	var press := InputEventMouseButton.new()
	press.position = view.get_global_rect().get_center()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(90, -20)
	motion.screen_relative = motion.relative
	root.push_input(motion, true)
	await _settle()
	_expect(hash(viewport.get_texture().get_image().get_data()) != before
		and camera.position == position,
		"Actual mouse-look must change the rendered 3D perspective without moving the doctor.")
	_capture(root.get_texture().get_image(), "doctor_mouse_look")
	motion.relative = -motion.relative
	motion.screen_relative = motion.relative
	root.push_input(motion, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	game.call("_refresh_frame")


func _test_welcome() -> void:
	var packed := load("res://games/asmr_doctor/intro.tscn") as PackedScene
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(320, 568)]:
		root.size = dimensions
		var welcome := packed.instantiate()
		root.add_child(welcome)
		await _settle()
		var next := welcome.get_node("%NextButton") as Button
		var text_width := next.get_theme_font("font").get_string_size(
			"Next", HORIZONTAL_ALIGNMENT_LEFT, -1, next.get_theme_font_size("font_size")).x
		_expect(next.size.x >= text_width + next.get_theme_stylebox("normal").get_minimum_size().x,
			"The welcome's Next label must fit instead of collapsing behind its spacer.")
		_expect(root.get_visible_rect().encloses(next.get_global_rect()),
			"Welcome actions must stay on screen at %s." % dimensions)
		_capture(root.get_texture().get_image(), "welcome_%dx%d" % [dimensions.x, dimensions.y])
		for index in 2:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = next.get_global_rect().get_center()
			root.push_input(press, true)
			var release := press.duplicate() as InputEventMouseButton
			release.pressed = false
			root.push_input(release, true)
			await _settle()
			_expect(int(welcome.get("_card")) == index + 1,
				"The real Next button must advance the welcome cards.")
		_expect(next.text == "Open the clinic",
			"The final welcome card must explain where its action leads.")
		welcome.free()
		await process_frame


func _settle() -> void:
	for index in 4:
		await process_frame
	await RenderingServer.frame_post_draw


func _portrait_rect(view: Control, image: Image) -> Rect2i:
	var rect := view.get_global_rect()
	var center := rect.get_center()
	var scale := Vector2(image.get_size()) / root.get_visible_rect().size
	var radius := minf(rect.size.x, rect.size.y) * 0.14
	var area := Rect2i((center - Vector2.ONE * radius) * scale, Vector2.ONE * radius * 2 * scale)
	return area.intersection(Rect2i(Vector2i.ZERO, image.get_size()))


func _has_picture(view: Control, image: Image) -> bool:
	var rect := view.get_global_rect()
	var scale := Vector2(image.get_size()) / root.get_visible_rect().size
	var center := rect.get_center() * scale
	var pixel := image.get_pixelv(Vector2i(center))
	return pixel.r > 0.2 and pixel.g > 0.2 and pixel.b > 0.2


func _capture(image: Image, filename: String) -> void:
	if not _output.is_empty():
		_expect(image.save_png(_output.path_join(filename + ".png")) == OK,
			"Rendered screenshot must save: " + filename)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

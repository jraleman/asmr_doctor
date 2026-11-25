extends SceneTree

## Treatment pacing, preference discovery and durable journal regression checks.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const Session := preload("res://games/asmr_doctor/clinic_session.gd")
const Progress := preload("res://games/asmr_doctor/clinic_progress.gd")
var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_care()
	_test_rhythm()
	_test_roster()
	_test_progress()
	if _failures.is_empty():
		print("ASMR Doctor treatment and journal tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_care() -> void:
	var favorite := Session.new()
	favorite.begin("mira")
	favorite.advance(120.0)
	_expect(favorite.stress == Session.INITIAL_STRESS,
		"Waiting must neither raise stress nor earn calm.")
	var response := favorite.advance(1.0, 0.4)
	_expect(bool(response.get("discovery", false)) and favorite.favorite_found,
		"Steady favored care must discover a preference through actual treatment.")
	var neutral := Session.new()
	neutral.begin("fidget")
	neutral.advance(1.0, 0.4)
	_expect(favorite.stress < neutral.stress,
		"A patient's preferred trigger must soothe more effectively.")
	var sensitive := Session.new()
	sensitive.begin("nimbus")
	sensitive.select_tool("tap", 10)
	sensitive.pulse()
	var normal := Session.new()
	normal.begin("mira")
	normal.select_tool("tap", 10)
	normal.pulse()
	_expect(sensitive.stress > normal.stress and sensitive.stress < Session.INITIAL_STRESS,
		"A sensitive sound must be slower, not an unwinnable treatment.")
	var split := Session.new()
	split.begin("mira")
	for index in 10:
		split.advance(0.1, 0.4)
	_expect(is_equal_approx(split.stress, favorite.stress),
		"Continuous treatment must not depend on rendering frame rate.")
	favorite.advance(1.0, 1.4)
	var startled := favorite.stress
	for index in 10:
		favorite.advance(0.01, 1.4)
	_expect(favorite.startles == 1 and favorite.stress == startled,
		"One loud sound must not cause a frame-by-frame startle penalty.")
	_expect(not favorite.select_tool("snip", 3)
		and favorite.select_tool("snip", 4),
		"Tool unlocks must depend on completed patients, not idle time.")


func _test_rhythm() -> void:
	var session := Session.new()
	session.begin("fidget")
	session.select_tool("tap", 0)
	session.pulse()
	var after_first := session.stress
	for index in 20:
		session.advance(0.01)
		session.pulse()
	_expect(session.stress == after_first,
		"Rapid repeated presses must not farm soothing progress.")
	session.advance(20.0)
	session.pulse()
	_expect(session.stress < after_first, "Long rests must remain valid treatment.")
	var paced := Session.new()
	paced.begin("fidget")
	paced.select_tool("tap", 0)
	paced.pulse()
	paced.advance(1.1)
	var response := paced.pulse()
	_expect(bool(response.get("discovery", false)) and paced.favorite_found,
		"A few well-spaced favorite taps must reveal a journal preference.")


func _test_roster() -> void:
	for id in Options.PATIENT_ORDER:
		var session := Session.new()
		session.begin(id)
		var tool := str(Options.PATIENTS[id]["favorite"])
		session.select_tool(tool, 100)
		for index in 200:
			if session.complete:
				break
			if str(Options.TOOLS[tool]["kind"]) == "hold":
				session.advance(0.5, 0.4)
			else:
				session.advance(float(Options.TOOLS[tool]["period"]))
				session.pulse()
		_expect(session.complete and session.favorite_found and session.stress == 0,
			"Every patient must be fully treatable and discoverable: " + id)
		var attempts := session.attempts
		session.advance(60.0, 0.4)
		session.pulse()
		_expect(session.attempts == attempts and session.progress() == 1.0,
			"Completed appointments must not continue awarding treatment.")


func _test_progress() -> void:
	var path := "user://asmr_doctor_rules_test_%d.cfg" % get_instance_id()
	var progress := Progress.new()
	progress.save_path = path
	_expect(progress.load_save() == ERR_FILE_NOT_FOUND, "A new journal must start clean.")
	_expect(progress.next_queue() == ["mira", "fidget", "nimbus"],
		"The first shift must introduce the three initial visitors.")
	for id: String in ["mira", "fidget", "nimbus"]:
		progress.record_visit(id)
		progress.discover(id)
	progress.completed_shifts = 1
	_expect(progress.save() == OK, "Completed care must be writable.")
	var file := ConfigFile.new()
	file.load(path)
	file.set_value("future", "keep", "untouched")
	file.save(path)
	var restored := Progress.new()
	restored.save_path = path
	_expect(restored.load_save() == OK and restored.total_visits == 3
		and restored.completed_shifts == 1 and restored.favorites.size() == 3
		and restored.next_queue() == ["ember", "wisp", "pip"],
		"Reloading must preserve the journal and introduce the next three patients.")
	restored.save()
	file.load(path)
	_expect(file.get_value("future", "keep", "") == "untouched",
		"Saving must merge, not erase unrecognized fields.")
	file.set_value("clinic", "version", 999)
	file.save(path)
	var bytes := FileAccess.get_file_as_bytes(path)
	var newer := Progress.new()
	newer.save_path = path
	_expect(newer.load_save() == ERR_INVALID_DATA and not newer.writable
		and newer.save() == ERR_INVALID_DATA
		and FileAccess.get_file_as_bytes(path) == bytes,
		"A newer journal must be refused and left byte-for-byte unchanged.")
	file.set_value("clinic", "version", 1)
	file.set_value("visits", "mira", -1)
	file.save(path)
	var damaged := Progress.new()
	damaged.save_path = path
	_expect(damaged.load_save() == ERR_INVALID_DATA,
		"Invalid patient counts must not become usable progression.")
	_expect(DirAccess.remove_absolute(path) == OK, "The test journal must be cleaned up.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

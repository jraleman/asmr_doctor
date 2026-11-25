extends RefCounted

## Only completed care and discovered preferences persist, never microphone data.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const SAVE_VERSION := 1
const MAX_VISITS := 1000000

var save_path := Options.SAVE_PATH
var total_visits := 0
var completed_shifts := 0
var visits: Dictionary[String, int] = {}
var favorites: Array[String] = []
var writable := true


func load_save() -> Error:
	if not FileAccess.file_exists(save_path):
		return ERR_FILE_NOT_FOUND
	var file := ConfigFile.new()
	var error := file.load(save_path)
	if error != OK:
		writable = false
		return error
	if file.get_value("clinic", "version", 0) != SAVE_VERSION:
		writable = false
		return ERR_INVALID_DATA
	var count: Variant = file.get_value("clinic", "total_visits", 0)
	var shifts: Variant = file.get_value("clinic", "completed_shifts", 0)
	var known: Variant = file.get_value("clinic", "favorites", [])
	if not _valid_count(count) or not _valid_count(shifts) or not known is Array:
		writable = false
		return ERR_INVALID_DATA
	var loaded_visits: Dictionary[String, int] = {}
	var loaded_favorites: Array[String] = []
	var sum := 0
	for id in Options.PATIENT_ORDER:
		var value: Variant = file.get_value("visits", id, 0)
		if not _valid_count(value):
			writable = false
			return ERR_INVALID_DATA
		loaded_visits[id] = int(value)
		sum += int(value)
	for id: Variant in known:
		if not id is String or not Options.PATIENTS.has(id) \
				or loaded_favorites.has(str(id)):
			writable = false
			return ERR_INVALID_DATA
		loaded_favorites.append(str(id))
	if sum != int(count) or int(shifts) * Options.APPOINTMENTS_PER_SHIFT > sum:
		writable = false
		return ERR_INVALID_DATA
	total_visits = int(count)
	completed_shifts = int(shifts)
	visits = loaded_visits
	favorites = loaded_favorites
	writable = true
	return OK


func save() -> Error:
	if not writable:
		return ERR_INVALID_DATA
	var file := ConfigFile.new()
	if FileAccess.file_exists(save_path):
		var error := file.load(save_path)
		if error != OK:
			return error
		if file.get_value("clinic", "version", 0) != SAVE_VERSION:
			return ERR_INVALID_DATA
	file.set_value("clinic", "version", SAVE_VERSION)
	file.set_value("clinic", "total_visits", total_visits)
	file.set_value("clinic", "completed_shifts", completed_shifts)
	file.set_value("clinic", "favorites", favorites)
	for id in Options.PATIENT_ORDER:
		file.set_value("visits", id, visits_of(id))
	return file.save(save_path)


func visits_of(id: String) -> int:
	return visits.get(id, 0)


func discover(id: String) -> bool:
	assert(Options.PATIENTS.has(id), "ASMR Doctor: unknown journal patient.")
	if favorites.has(id):
		return false
	favorites.append(id)
	return true


func record_visit(id: String) -> void:
	assert(Options.PATIENTS.has(id), "ASMR Doctor: unknown completed patient.")
	visits[id] = mini(MAX_VISITS, visits_of(id) + 1)
	total_visits = 0
	for count in visits.values():
		total_visits += count


func next_queue() -> Array[String]:
	var result: Array[String] = []
	for index in Options.APPOINTMENTS_PER_SHIFT:
		result.append(Options.PATIENT_ORDER[
			(total_visits + index) % Options.PATIENT_ORDER.size()
		])
	return result


func all_patients_helped() -> bool:
	for id in Options.PATIENT_ORDER:
		if visits_of(id) == 0:
			return false
	return true


func _valid_count(value: Variant) -> bool:
	return value is int and int(value) >= 0 \
		and int(value) <= MAX_VISITS * Options.PATIENT_ORDER.size()

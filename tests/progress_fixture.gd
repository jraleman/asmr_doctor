extends RefCounted

## Preserve the player's clinic, wallet and achievements across scene tests.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
var _store: Node
var _achievements: Node
var _wallet: Dictionary = {}
var _unlocks: Dictionary = {}
var _bytes := PackedByteArray()
var _existed := false
var _active := false


func begin(tree: SceneTree) -> Error:
	_store = tree.root.get_node("Store")
	_achievements = tree.root.get_node("AchievementManager")
	_existed = FileAccess.file_exists(Options.SAVE_PATH)
	if _existed:
		var file := FileAccess.open(Options.SAVE_PATH, FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()
		_bytes = file.get_buffer(file.get_length())
	_wallet = _store.call("export_save", Options.GAME_ID)
	_unlocks = _achievements.call("export_save", Options.GAME_ID)
	_active = true
	var error: Error = _store.call("erase_save", Options.GAME_ID)
	if error == OK:
		error = _achievements.call("erase_save", Options.GAME_ID)
	if error == OK and _existed:
		error = DirAccess.remove_absolute(Options.SAVE_PATH)
	if error != OK:
		restore()
	return error


func restore() -> Error:
	if not _active:
		return OK
	var error := OK
	if _existed:
		var file := FileAccess.open(Options.SAVE_PATH, FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
		else:
			file.store_buffer(_bytes)
			file.flush()
			error = file.get_error()
	elif FileAccess.file_exists(Options.SAVE_PATH):
		error = DirAccess.remove_absolute(Options.SAVE_PATH)
	var wallet_error: Error = _store.call("import_save", Options.GAME_ID, _wallet)
	var unlock_error: Error = _achievements.call("import_save", Options.GAME_ID, _unlocks)
	if error == OK:
		error = wallet_error if wallet_error != OK else unlock_error
	_active = error != OK
	return error

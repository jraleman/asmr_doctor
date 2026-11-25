extends Node

## Scene-owned players respect the shared Music/SFX buses and release on exit.

const Audio := preload("res://games/asmr_doctor/clinic_audio.gd")
var _ambient: Dictionary[String, AudioStreamPlayer] = {}
var _voices: Array[AudioStreamPlayer] = []
var _hold: AudioStreamPlayer
var _mix := {"rain": 0.0, "fire": 0.0, "room": 0.0}
var _levels := {"rain": 0.0, "fire": 0.0, "room": 0.0}
var _intensity := 0.55
var _silent := false
var _snips := true
var _crinkles := true
var _ducked := false
var _running := false
var _hold_id := ""
var _hold_target := 0.0
var _hold_level := 0.0
var _voice_index := 0


func _ready() -> void:
	for id: String in ["rain", "fire", "room"]:
		var player := _make_player("Music")
		player.stream = Audio.stream(id)
		_ambient[id] = player
	_hold = _make_player("SFX")
	for index in 3:
		_voices.append(_make_player("SFX"))


func configure(mix: Dictionary, intensity: float, silent: bool,
		snips: bool, crinkles: bool) -> void:
	for id in _mix:
		_mix[id] = clampf(float(mix.get(id, 0.0)), 0.0, 1.0)
	_intensity = clampf(intensity, 0.0, 1.0)
	_silent = silent
	_snips = snips
	_crinkles = crinkles
	if _silent or not _allowed(_hold_id):
		end_care()
	for voice in _voices:
		if _silent or not _allowed(str(voice.get_meta("tool", ""))):
			voice.stop()


func start() -> void:
	_running = true
	for player in _ambient.values():
		if not player.playing:
			player.play()


func set_microphone_active(active: bool) -> void:
	_ducked = active
	if active:
		end_care()
		for voice in _voices:
			voice.stop()


func hold_care(id: String, strength: float) -> void:
	if not _running or _ducked or not _allowed(id) or strength <= 0.0:
		end_care()
		return
	if id != _hold_id or not _hold.playing:
		_hold.stop()
		_hold_id = id
		_hold.stream = Audio.stream(id)
		_hold_level = 0.0
		_hold.volume_db = -60.0
		_hold.play()
	_hold_target = _intensity * 0.65


func pulse(id: String) -> void:
	if not _running or _ducked or not _allowed(id):
		return
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stop()
	voice.stream = Audio.stream(id)
	voice.set_meta("tool", id)
	voice.volume_db = linear_to_db(maxf(0.0001, _intensity * 0.7))
	voice.play()


func end_care() -> void:
	_hold_target = 0.0


func stop() -> void:
	_running = false
	end_care()
	for player in _ambient.values():
		player.stop()
	for voice in _voices:
		voice.stop()
	if is_instance_valid(_hold):
		_hold.stop()
	_hold_level = 0.0


func _process(delta: float) -> void:
	for id: String in _ambient:
		var target := float(_mix[id]) * 0.7 if _running else 0.0
		if _ducked:
			target *= 0.03
		_levels[id] = move_toward(float(_levels[id]), target, delta * 0.8)
		_ambient[id].volume_db = linear_to_db(maxf(0.0001, float(_levels[id])))
	_hold_level = move_toward(_hold_level, _hold_target, delta * 5.0)
	_hold.volume_db = linear_to_db(maxf(0.0001, _hold_level))
	if is_zero_approx(_hold_level) and is_zero_approx(_hold_target) and _hold.playing:
		_hold.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		end_care()


func _allowed(id: String) -> bool:
	return not _silent and (id != "snip" or _snips) and (id != "crinkle" or _crinkles)


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = -60.0
	add_child(player)
	return player


func _exit_tree() -> void:
	stop()

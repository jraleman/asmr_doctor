extends Node

## Explicit-start level capture, never monitoring or retaining microphone PCM.

signal status_changed(message: String)
signal capture_failed(message: String)
signal calibrated

const WebCapture := preload("res://games/asmr_doctor/web_microphone.gd")
const CALIBRATION_SECONDS := 1.25
const NO_INPUT_SECONDS := 4.0

var active := false
var ready_for_input := false
var normalized_level := 0.0
var sensitivity := 1.0
var noise_floor := 0.002
var _capture: AudioEffectCapture
var _browser: JavaScriptObject
var _browser_waiting := false
var _player: AudioStreamPlayer
var _bus_name := ""
var _settle := 0.35
var _idle := 0.0
var _frames := 0
var _energy := 0.0
var _peak := 0.0


func _ready() -> void:
	get_window().focus_exited.connect(stop)
	set_process(false)


func start() -> void:
	stop()
	if not bool(ProjectSettings.get_setting_with_override("audio/driver/enable_input")):
		_fail("Microphone input is disabled in this build. Mouse and keyboard still work.")
		return
	if OS.has_feature("web") and not bool(JavaScriptBridge.eval("window.isSecureContext")):
		_fail("Microphone access needs HTTPS or localhost. Mouse and keyboard still work.")
		return
	if OS.has_feature("web"):
		_reset_capture()
		_browser = WebCapture.create()
		_browser.start()
		status_changed.emit("Waiting for your browser's microphone permission...")
		return
	_bus_name = "ASMRDoctorInput" + str(get_instance_id())
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, _bus_name)
	AudioServer.set_bus_send(bus, "Master")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(bus, _capture)
	# Capture runs before the muted bus output. Microphone sound never reaches speakers.
	AudioServer.set_bus_mute(bus, true)
	_player = AudioStreamPlayer.new()
	_player.bus = _bus_name
	_player.stream = AudioStreamMicrophone.new()
	add_child(_player)
	_reset_capture()
	_player.play()
	status_changed.emit("Stay quiet for a moment. Measuring your room...")


func stop() -> void:
	var was_active := active
	active = false
	ready_for_input = false
	normalized_level = 0.0
	set_process(false)
	if _browser != null:
		_browser.stop()
		_browser = null
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
		_player.queue_free()
	_player = null
	_capture = null
	if not _bus_name.is_empty():
		var bus := AudioServer.get_bus_index(_bus_name)
		if bus >= 0:
			AudioServer.remove_bus(bus)
		_bus_name = ""
	if was_active and is_inside_tree():
		status_changed.emit("Mic off. Your room is private again.")


func _process(delta: float) -> void:
	if not active:
		return
	if _browser != null:
		_process_browser(delta)
		return
	if _capture == null:
		return
	var available := _capture.get_frames_available()
	if not _has_frames(delta, available):
		return
	var frames := _capture.get_buffer(available)
	var energy := 0.0
	var peak := 0.0
	for frame in frames:
		var mono := (frame.x + frame.y) * 0.5
		energy += mono * mono
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	_consume_levels(delta, frames.size(), energy, peak, AudioServer.get_mix_rate())


func _reset_capture() -> void:
	_settle = 0.35
	_idle = 0.0
	_frames = 0
	_energy = 0.0
	_peak = 0.0
	_browser_waiting = true
	active = true
	ready_for_input = false
	normalized_level = 0.0
	set_process(true)


func _process_browser(delta: float) -> void:
	if str(_browser.state) == "pending":
		return
	if str(_browser.state) == "stopped":
		stop()
		return
	if str(_browser.state) == "ready":
		if _browser_waiting:
			_browser_waiting = false
			status_changed.emit("Stay quiet for a moment. Measuring your room...")
		_browser.read()
	if str(_browser.state) == "failed":
		var reason := str(_browser.error)
		match reason:
			"NotAllowedError", "SecurityError":
				_fail("Microphone permission was denied. Allow it in your browser or use the care button.")
			"NotFoundError":
				_fail("No microphone was found. Connect a device or use the care button.")
			_:
				_fail("The browser couldn't start microphone audio (%s)." % reason)
		return
	var available := int(_browser.frames)
	if _has_frames(delta, available):
		_consume_levels(delta, available, float(_browser.energy), float(_browser.peak),
			float(_browser.rate))


func _has_frames(delta: float, available: int) -> bool:
	_idle = _idle + delta if available == 0 else 0.0
	if _idle >= NO_INPUT_SECONDS:
		_fail("No microphone audio arrived. Check permission and device, then try again.")
		return false
	if available == 0:
		if _idle >= 0.15:
			normalized_level = 0.0
		return false
	return true


func _consume_levels(delta: float, count: int, energy: float, peak: float, rate: float) -> void:
	if _settle > 0.0:
		_settle -= delta
		return
	if not ready_for_input:
		_frames += count
		_energy += energy
		_peak = maxf(_peak, peak)
		if float(_frames) / rate >= CALIBRATION_SECONDS:
			if _peak <= 0.0:
				_fail("The microphone returned digital silence. Check permission or use the care button.")
				return
			noise_floor = clampf(sqrt(_energy / _frames) * 2.0, 0.0015, 0.035)
			ready_for_input = true
			if _capture != null:
				_capture.clear_buffer()
			status_changed.emit("Listening locally. Soft sounds only; headphones work best.")
			calibrated.emit()
		return
	var rms := sqrt(energy / count)
	normalized_level = level_from_rms(rms, noise_floor, sensitivity)


static func level_from_rms(rms: float, floor_level: float, gain: float) -> float:
	if not is_finite(rms) or not is_finite(floor_level) or not is_finite(gain):
		push_error("ASMR Doctor: microphone levels must be finite.")
		return 0.0
	return clampf((rms - floor_level) * gain / 0.065, 0.0, 1.5)


func _fail(message: String) -> void:
	stop()
	push_warning("ASMR Doctor microphone: " + message)
	capture_failed.emit(message + " Mouse and keyboard are always available.")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		stop()


func _exit_tree() -> void:
	stop()

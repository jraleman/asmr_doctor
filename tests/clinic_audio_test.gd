extends SceneTree

## Measure actual generated PCM and verify that loading never starts a microphone.

const Audio := preload("res://games/asmr_doctor/clinic_audio.gd")
const Mic := preload("res://games/asmr_doctor/microphone.gd")
const Soundscape := preload("res://games/asmr_doctor/soundscape.gd")
var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for id: String in ["rain", "fire", "room", "whisper", "brush", "tap", "paper", "crinkle", "snip"]:
		var stream := Audio.stream(id)
		var bytes := stream.data
		var peak := 0.0
		var energy := 0.0
		for index in bytes.size() / 2:
			var sample := float(bytes.decode_s16(index * 2)) / 32768.0
			peak = maxf(peak, absf(sample))
			energy += sample * sample
		_expect(stream.stereo and stream.mix_rate == Audio.RATE and bytes.size() > 0
			and peak > 0.003 and peak < 0.46 and sqrt(energy / (bytes.size() / 2)) > 0.001,
			"Original stereo synthesis must be audible, non-empty and bounded: " + id)
		if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
			_expect(absf(float(bytes.decode_s16(0) - bytes.decode_s16(bytes.size() - 4)))
				/ 32768.0 < 0.12, "Ambient and continuous sounds must join softly: " + id)
		else:
			_expect(abs(bytes.decode_s16(0)) < 10 and abs(bytes.decode_s16(bytes.size() - 4)) < 100,
				"Individual tool sounds must have quiet attack/release endpoints: " + id)
	_expect(Mic.level_from_rms(0.001, 0.002, 1.0) == 0.0
		and Mic.level_from_rms(0.025, 0.002, 1.0) > 0.08
		and Mic.level_from_rms(0.15, 0.002, 1.0) > 1.0,
		"Mic input must separate quiet, gentle and loud calibrated levels.")
	var bus_count := AudioServer.bus_count
	var mic := Mic.new()
	root.add_child(mic)
	_expect(not mic.active and not mic.ready_for_input and AudioServer.bus_count == bus_count,
		"Instantiating microphone support must not open a device or create a capture bus.")
	mic.active = true
	mic.set("_settle", 0.0)
	for index in 3:
		mic.call("_consume_levels", 0.5, 24000, 24000 * 0.000001, 0.002, 48000.0)
	_expect(mic.ready_for_input and is_equal_approx(mic.noise_floor, 0.002),
		"Both capture backends must calibrate by sample time above digital silence.")
	mic.call("_consume_levels", 0.1, 4800, 4800 * 0.000625, 0.03, 48000.0)
	_expect(mic.normalized_level > 0.08 and mic.normalized_level < 1.0,
		"Calibrated aggregate input must produce gentle treatment strength.")
	mic.call("_has_frames", 0.16, 0)
	_expect(mic.normalized_level == 0.0,
		"Missing fresh audio must clear stale care strength before the device timeout.")
	mic.stop()
	mic.stop()
	mic.free()
	var sound := Soundscape.new()
	root.add_child(sound)
	sound.configure({"rain": 0.3}, 0.5, true, true, true)
	sound.start()
	sound.pulse("tap")
	sound.hold_care("whisper", 0.4)
	var voices: Array = sound.get("_voices")
	_expect(not (voices[0] as AudioStreamPlayer).playing
		and not (sound.get("_hold") as AudioStreamPlayer).playing,
		"Silent treatment settings must suppress both pulse and continuous tool audio.")
	sound.configure({}, 0.5, false, false, false)
	sound.pulse("snip")
	sound.pulse("crinkle")
	_expect(not (voices[0] as AudioStreamPlayer).playing,
		"Sensitive-sound exclusions must keep tools silent without removing their rules.")
	sound.set_microphone_active(true)
	sound.pulse("tap")
	_expect(not (voices[0] as AudioStreamPlayer).playing,
		"Microphone capture must not trigger speaker tool feedback.")
	sound.set_microphone_active(false)
	sound.pulse("tap")
	_expect((voices[0] as AudioStreamPlayer).playing,
		"An allowed treatment must reach a real SFX player.")
	sound.stop()
	sound.free()
	await create_timer(0.2, true, false, true).timeout
	if _failures.is_empty():
		print("ASMR Doctor audio and microphone-boundary tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

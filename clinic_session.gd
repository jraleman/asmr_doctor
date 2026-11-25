extends RefCounted

## Node-free treatment rules. Waiting never raises stress or earns calm.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const INITIAL_STRESS := 80.0
const HOLD_RATE := 4.2
const PULSE_GAIN := 7.5

var patient_id := ""
var tool_id := "whisper"
var stress := INITIAL_STRESS
var elapsed := 0.0
var since_pulse := 0.0
var soothing_seconds := 0.0
var attempts := 0
var gentle_actions := 0
var startles := 0
var complete := false
var favorite_found := false
var _has_pulsed := false
var _favorite_exposure := 0.0
var _hold_fraction := 0.0
var _startle_cooldown := 0.0


func begin(id: String, known_favorite := false) -> void:
	assert(Options.PATIENTS.has(id), "ASMR Doctor: unknown patient.")
	patient_id = id
	stress = INITIAL_STRESS
	elapsed = 0.0
	since_pulse = 0.0
	soothing_seconds = 0.0
	attempts = 0
	gentle_actions = 0
	startles = 0
	complete = false
	favorite_found = known_favorite
	_has_pulsed = false
	_favorite_exposure = 0.0
	_hold_fraction = 0.0
	_startle_cooldown = 0.0


func select_tool(id: String, completed_visits: int) -> bool:
	if not Options.TOOLS.has(id):
		push_warning("ASMR Doctor: unknown treatment '%s'." % id)
		return false
	if completed_visits < int(Options.TOOLS[id]["unlock"]):
		return false
	tool_id = id
	since_pulse = 0.0
	_has_pulsed = false
	_favorite_exposure = 0.0
	_hold_fraction = 0.0
	return true


func advance(delta: float, strength := 0.0, quality := 1.0) -> Dictionary:
	if not is_finite(delta) or delta < 0.0 or not is_finite(strength) \
			or not is_finite(quality):
		push_error("ASMR Doctor: treatment input must be finite and time non-negative.")
		return {}
	if complete or patient_id.is_empty():
		return {}
	elapsed += delta
	since_pulse += delta
	_startle_cooldown = maxf(0.0, _startle_cooldown - delta)
	if strength > 1.0:
		return _startle()
	if strength < 0.08 or str(Options.TOOLS[tool_id]["kind"]) != "hold":
		_hold_fraction = 0.0
		return {}
	var gentleness := clampf(1.0 - absf(strength - 0.4), 0.2, 1.0)
	var care := delta * gentleness * clampf(quality, 0.2, 1.0)
	soothing_seconds += care
	_hold_fraction += delta
	if _hold_fraction >= 1.0:
		var actions := floori(_hold_fraction)
		attempts += actions
		gentle_actions += actions
		_hold_fraction -= actions
	return _soothe(HOLD_RATE * care * affinity(), care)


func pulse(strength := 0.4) -> Dictionary:
	if not is_finite(strength):
		push_error("ASMR Doctor: sound strength must be finite.")
		return {}
	if complete or patient_id.is_empty() or strength < 0.08:
		return {}
	if strength > 1.0:
		return _startle()
	if str(Options.TOOLS[tool_id]["kind"]) != "pulse":
		return {}
	attempts += 1
	var period := float(Options.TOOLS[tool_id]["period"])
	var interval := since_pulse
	since_pulse = 0.0
	var first := not _has_pulsed
	_has_pulsed = true
	if not first and interval < period * 0.45:
		return {"message": "A little space between sounds. There's no rush.",
			"kind": "pace", "gain": 0.0}
	# Long rests remain valid. Timing offers a small bonus, never a failure gate.
	var rhythm := 0.72 if first else clampf(
		1.0 - absf(interval - period) / (period * 2.0), 0.45, 1.0
	)
	gentle_actions += 1
	soothing_seconds += period * rhythm
	return _soothe(PULSE_GAIN * affinity() * rhythm, rhythm)


func affinity() -> float:
	var patient: Dictionary = Options.PATIENTS[patient_id]
	if tool_id == str(patient["favorite"]):
		return 1.6
	if tool_id == str(patient["avoid"]):
		return 0.25
	return 0.85


func progress() -> float:
	return clampf((INITIAL_STRESS - stress) / INITIAL_STRESS, 0.0, 1.0)


func rhythm_phase() -> float:
	return fmod(since_pulse / float(Options.TOOLS[tool_id]["period"]), 1.0)


func _soothe(gain: float, exposure: float) -> Dictionary:
	var before := stress
	stress = maxf(0.0, stress - gain)
	complete = is_zero_approx(stress)
	var found := false
	if affinity() > 1.0:
		_favorite_exposure += exposure
		if _favorite_exposure >= 0.9 and not favorite_found:
			favorite_found = true
			found = true
	return {"gain": before - stress, "discovery": found,
		"kind": "favorite" if affinity() > 1.0 else "sensitive" if affinity() < 0.5 else "gentle"}


func _startle() -> Dictionary:
	if _startle_cooldown > 0.0:
		return {}
	startles += 1
	attempts += 1
	stress = minf(INITIAL_STRESS, stress + 2.0)
	_startle_cooldown = 2.0
	return {"gain": 0.0, "kind": "loud",
		"message": "A little softer. One quiet breath, then try again."}

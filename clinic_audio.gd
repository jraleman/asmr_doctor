extends RefCounted

## Original, deterministic stereo synthesis. No recordings or network resources.

const RATE := 16000
static var _cache: Dictionary[String, AudioStreamWAV] = {}


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var durations := {
		"rain": 6.0, "fire": 6.0, "room": 6.0, "whisper": 2.0,
		"brush": 2.0, "tap": 0.4, "paper": 1.25, "crinkle": 1.4, "snip": 0.5,
	}
	assert(durations.has(kind), "ASMR Doctor: unknown synthesized sound.")
	var looping := kind in ["rain", "fire", "room", "whisper", "brush"]
	var count := roundi(float(durations[kind]) * RATE)
	var overlap := 1600 if looping else 0
	var samples := PackedFloat32Array()
	samples.resize((count + overlap) * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("asmr_doctor_" + kind)
	var low := [0.0, 0.0]
	var pink := [0.0, 0.0]
	var brown := [0.0, 0.0]
	for index in count + overlap:
		var time := float(index) / RATE
		for channel in 2:
			var white := rng.randf_range(-1.0, 1.0)
			low[channel] = lerpf(low[channel], white, 0.025)
			pink[channel] = lerpf(pink[channel], white, 0.18)
			brown[channel] = clampf((brown[channel] + white * 0.012) * 0.998, -0.5, 0.5)
			var sample := _sample(kind, time, float(durations[kind]), channel,
				white, low[channel], pink[channel], brown[channel])
			if not looping:
				sample *= minf(1.0, time / 0.008) \
					* minf(1.0, (float(durations[kind]) - time) / 0.04)
			samples[index * 2 + channel] = clampf(sample, -0.45, 0.45)
	if looping:
		# Overlap the tail into the head; the final sample then joins its neighbor.
		for index in overlap:
			for channel in 2:
				var head := index * 2 + channel
				var tail := (count + index) * 2 + channel
				samples[head] = lerpf(samples[tail], samples[head], float(index) / overlap)
	var bytes := PackedByteArray()
	bytes.resize(count * 4)
	for index in count * 2:
		bytes.encode_s16(index * 2, roundi(samples[index] * 32767.0))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = RATE
	result.stereo = true
	result.data = bytes
	if looping:
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD
		result.loop_begin = 0
		result.loop_end = count
	_cache[kind] = result
	return result


static func _sample(
	kind: String, time: float, duration: float, channel: int,
	white: float, low: float, pink: float, brown: float
) -> float:
	var side := float(channel) * 0.23
	match kind:
		"rain":
			return pink * 0.24 + low * 0.22 + white * 0.012
		"fire":
			var crackle := pow(maxf(0.0, sin(time * 17.3 + side)
				* sin(time * 31.7 + 0.8)), 12.0)
			return brown * 0.32 + pink * crackle * 0.12 + low * 0.08
		"room":
			var chord := sin(TAU * 130.81 * time + side) \
				+ sin(TAU * 164.81 * time + 0.7 + side) * 0.6 \
				+ sin(TAU * 196.0 * time + 1.2 - side) * 0.45
			return chord * 0.022 * (0.85 + 0.15 * sin(time * 0.7)) + brown * 0.025
		"whisper":
			return (pink * 0.24 + (white - pink) * 0.025) \
				* (0.75 + 0.25 * sin(time * PI + side))
		"brush":
			return (pink * 0.27 + low * 0.28) \
				* (0.65 + 0.35 * sin(time * PI + side))
		"tap":
			return sin(TAU * 420.0 * time) * exp(-time * 22.0) * 0.22 \
				+ sin(TAU * 735.0 * time) * exp(-time * 35.0) * 0.045 \
				+ pink * exp(-time * 50.0) * 0.07
		"paper":
			return (pink * 0.35 + low * 0.2) * pow(sin(PI * time / duration), 2.0) \
				* (0.65 + 0.35 * sin(time * 19.0))
		"crinkle":
			var folds := 0.25 + pow(absf(sin(time * 12.0) * cos(time * 19.3)), 2.0)
			return (pink * 0.38 + low * 0.18) * folds * sin(PI * time / duration)
		"snip":
			return (pink * 0.24 + white * 0.02) \
				* pow(sin(PI * time / duration), 6.0) \
				+ sin(TAU * 620.0 * time) * exp(-time * 25.0) * 0.035
	return 0.0

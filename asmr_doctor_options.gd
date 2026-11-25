extends RefCounted

## Game-owned declarations, safe to load before the framework autoloads.

const GAME_ID := "asmr_doctor"
const SAVE_PATH := "user://asmr_doctor_clinic.cfg"
const APPOINTMENTS_PER_SHIFT := 3
const SHIFT_TOKENS := 18

const RAIN_KEY := "game/asmr_doctor_rain"
const FIRE_KEY := "game/asmr_doctor_fire"
const ROOM_KEY := "game/asmr_doctor_room"
const INTENSITY_KEY := "game/asmr_doctor_intensity"
const MIC_GAIN_KEY := "game/asmr_doctor_mic_gain"
const SILENT_KEY := "game/asmr_doctor_silent_tools"
const SNIPS_KEY := "game/asmr_doctor_snips_audio"
const CRINKLE_KEY := "game/asmr_doctor_crinkle_audio"
const LIGHTING_KEY := "game/asmr_doctor_lighting"
const CONTRAST_KEY := "game/asmr_doctor_contrast"

const TREAT_ACTION := &"asmr_doctor_treat"
const JOURNAL_ACTION := &"asmr_doctor_journal"
const SOUNDS_ACTION := &"asmr_doctor_sounds"
const SLEEP_ACTION := &"asmr_doctor_sleep"
const TOOL_ACTIONS: Array[StringName] = [
	&"asmr_doctor_whisper", &"asmr_doctor_tap", &"asmr_doctor_brush",
	&"asmr_doctor_paper", &"asmr_doctor_crinkle", &"asmr_doctor_snip",
]
const CONTROL_BINDINGS: Array[Dictionary] = [
	{"key": "controls/asmr_doctor_treat", "default": KEY_SPACE,
		"action": TREAT_ACTION, "title": "Give gentle care", "player": 0,
		"description": "Hold for whispers and brushing; press for rhythmic tools."},
	{"key": "controls/asmr_doctor_whisper", "default": KEY_1,
		"action": TOOL_ACTIONS[0], "title": "Whisper", "player": 0},
	{"key": "controls/asmr_doctor_tap", "default": KEY_2,
		"action": TOOL_ACTIONS[1], "title": "Wooden taps", "player": 0},
	{"key": "controls/asmr_doctor_brush", "default": KEY_3,
		"action": TOOL_ACTIONS[2], "title": "Feather brush", "player": 0},
	{"key": "controls/asmr_doctor_paper", "default": KEY_4,
		"action": TOOL_ACTIONS[3], "title": "Page turning", "player": 0},
	{"key": "controls/asmr_doctor_crinkle", "default": KEY_5,
		"action": TOOL_ACTIONS[4], "title": "Silk crinkles", "player": 0},
	{"key": "controls/asmr_doctor_snip", "default": KEY_6,
		"action": TOOL_ACTIONS[5], "title": "Soft snips", "player": 0},
	{"key": "controls/asmr_doctor_journal", "default": KEY_J,
		"action": JOURNAL_ACTION, "title": "Patient journal", "player": 0},
	{"key": "controls/asmr_doctor_sounds", "default": KEY_O,
		"action": SOUNDS_ACTION, "title": "Soundscapes", "player": 0},
	{"key": "controls/asmr_doctor_sleep", "default": KEY_R,
		"action": SLEEP_ACTION, "title": "Rest mode", "player": 0},
]

const TUNABLES: Array[Dictionary] = [
	{"key": RAIN_KEY, "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.05,
		"title": "Rain at the window", "format": GameManifest.FORMAT_PERCENT,
		"heading": "Your soundscape"},
	{"key": FIRE_KEY, "default": 0.2, "min": 0.0, "max": 1.0, "step": 0.05,
		"title": "Little fireplace", "format": GameManifest.FORMAT_PERCENT},
	{"key": ROOM_KEY, "default": 0.2, "min": 0.0, "max": 1.0, "step": 0.05,
		"title": "Dreamy room tone", "format": GameManifest.FORMAT_PERCENT},
	{"key": INTENSITY_KEY, "default": 0.55, "min": 0.0, "max": 1.0, "step": 0.05,
		"title": "Treatment sound intensity", "format": GameManifest.FORMAT_PERCENT,
		"heading": "Sound comfort"},
	{"key": SILENT_KEY, "type": GameManifest.OPTION_TOGGLE, "default": false,
		"title": "Silent treatments",
		"description": "Play every treatment with visual feedback and no tool audio."},
	{"key": SNIPS_KEY, "type": GameManifest.OPTION_TOGGLE, "default": true,
		"title": "Allow snipping sounds",
		"description": "Off mutes this tool without removing its mouse/keyboard treatment."},
	{"key": CRINKLE_KEY, "type": GameManifest.OPTION_TOGGLE, "default": true,
		"title": "Allow crinkling sounds",
		"description": "Off mutes this tool without removing its mouse/keyboard treatment."},
	{"key": MIC_GAIN_KEY, "default": 1.0, "min": 0.25, "max": 4.0, "step": 0.05,
		"title": "Microphone sensitivity", "heading": "Optional microphone",
		"description": "Applies after quiet-room calibration. Headphones are recommended.",
		"format": GameManifest.FORMAT_PERCENT},
	{"key": LIGHTING_KEY, "type": GameManifest.OPTION_CHOICE, "default": 0,
		"title": "Clinic lighting", "heading": "Your clinic",
		"choices": [
			{"value": 0, "title": "Alternate day and midnight shifts"},
			{"value": 1, "title": "Always golden afternoon"},
			{"value": 2, "title": "Always midnight"},
		]},
	{"key": CONTRAST_KEY, "type": GameManifest.OPTION_TOGGLE, "default": false,
		"title": "More opaque clinic panels",
		"description": "Increases panel contrast without changing treatment difficulty."},
]

const TOOL_ORDER: Array[String] = ["whisper", "tap", "brush", "paper", "crinkle", "snip"]
const TOOLS := {
	"whisper": {"title": "Whisper", "verb": "Hold to reassure", "kind": "hold",
		"unlock": 0, "period": 6.0, "color": Color("cbb6df"),
		"hint": "A soft, steady hush. Hold the care button, or whisper with the mic on."},
	"tap": {"title": "Wooden taps", "verb": "Tap gently", "kind": "pulse",
		"unlock": 0, "period": 1.1, "color": Color("e6bd91"),
		"hint": "One soft tap as the rhythm ring meets its edge. No need to hurry."},
	"brush": {"title": "Feather brush", "verb": "Hold to brush", "kind": "hold",
		"unlock": 0, "period": 3.0, "color": Color("b7d5b5"),
		"hint": "Hold for slow strokes. You can also hold and drift across the chair."},
	"paper": {"title": "Page turning", "verb": "Turn a page", "kind": "pulse",
		"unlock": 2, "period": 1.8, "color": Color("efe0b7"),
		"hint": "Let each page settle before turning another. Follow the slow ring."},
	"crinkle": {"title": "Silk crinkles", "verb": "Fold the silk", "kind": "pulse",
		"unlock": 3, "period": 1.5, "color": Color("e4b7c3"),
		"hint": "Small, unhurried folds. Leave a little quiet between each one."},
	"snip": {"title": "Soft snips", "verb": "Make a soft snip", "kind": "pulse",
		"unlock": 4, "period": 1.35, "color": Color("a8cbd3"),
		"hint": "Snip the air, not the patient. A tiny sound, then a patient pause."},
}

const PATIENT_ORDER: Array[String] = ["mira", "fidget", "nimbus", "ember", "wisp", "pip"]
const PATIENTS := {
	"mira": {
		"name": "Mira", "role": "An overbooked office worker", "kind": "human",
		"color": Color("d6a183"), "coat": Color("c88f80"),
		"favorite": "whisper", "avoid": "crinkle",
		"intro": "My calendar has a meeting called \"recover from meetings\".",
		"hint": "Could you keep things soft and steady? My thoughts are a little loud.",
		"liked": "That little hush... my thoughts finally have room to sit down.",
		"disliked": "That rustle reminds me of the inbox. Maybe something softer?",
		"outro": "I think I'll take the long way home. The one with the trees.",
		"returns": ["I took a lunch break. Outside. With an actual lunch.",
			"My calendar has a new appointment: absolutely nothing."],
	},
	"fidget": {
		"name": "Sir Fidget", "role": "A knight between quests", "kind": "knight",
		"color": Color("c6ccd6"), "coat": Color("a7b6c4"),
		"favorite": "tap", "avoid": "snip",
		"intro": "The dragon is lovely. It's the performance review I fear.",
		"hint": "A small, dependable rhythm would help. Something wooden, perhaps?",
		"liked": "Aha. A very small horse, walking very slowly. Perfect.",
		"disliked": "Those snips sound a little like sword practice. Not today.",
		"outro": "I shall face tomorrow bravely. After a nap.",
		"returns": ["I put a cushion in my helmet. Revolutionary.",
			"The dragon and I have started a very quiet book club."],
	},
	"nimbus": {
		"name": "Nimbus", "role": "A cloud with a lot on their mind", "kind": "cloud",
		"color": Color("c8bfdb"), "coat": Color("aca7c8"),
		"favorite": "brush", "avoid": "tap",
		"intro": "Everyone says \"cheer up\". I am literally overcast.",
		"hint": "Something feathery, please. It's been a tangled sort of day.",
		"liked": "Oh. That's a little patch of blue I hadn't noticed.",
		"disliked": "The tapping feels a bit like thunder. Could we try a softer touch?",
		"outro": "Just a light drizzle now. The good kind.",
		"returns": ["I made a rainbow. A small one. For myself.",
			"I've learned that partly cloudy is a perfectly good forecast."],
	},
	"ember": {
		"name": "Ember", "role": "A dragon with itchy scales", "kind": "dragon",
		"color": Color("e2ad87"), "coat": Color("c58b73"),
		"favorite": "paper", "avoid": "snip",
		"intro": "I keep accidentally toasting my bedtime stories.",
		"hint": "Would you read to me? I especially like the sound between the pages.",
		"liked": "That page sounds like a whole new, very sleepy adventure.",
		"disliked": "My scales are a little sensitive to snipping sounds.",
		"outro": "A story without a cliffhanger. My favorite kind of ending.",
		"returns": ["I finished a book without setting it on fire.",
			"I'm writing a story. Nothing bad happens in chapter three."],
	},
	"wisp": {
		"name": "Wisp", "role": "A ghost who forgot how to rest", "kind": "ghost",
		"color": Color("bad8cc"), "coat": Color("a0c1ba"),
		"favorite": "snip", "avoid": "crinkle",
		"intro": "I've been haunting the same to-do list for eighty years.",
		"hint": "Could you snip a few imaginary loose ends? They're following me around.",
		"liked": "One less loose end. I feel positively translucent.",
		"disliked": "That rustling reminds me of old paperwork. Even ghosts have limits.",
		"outro": "Unfinished business can wait until after tea.",
		"returns": ["I left one thing undone. The world continued.",
			"I haunt a hammock now. Much better hours."],
	},
	"pip": {
		"name": "Pip", "role": "A robot with rusty nerves", "kind": "robot",
		"color": Color("b3c9c4"), "coat": Color("85a9a8"),
		"favorite": "crinkle", "avoid": "paper",
		"intro": "ERROR 408: relaxation request timed out.",
		"hint": "Soft, crinkly textures help my circuits stop counting.",
		"liked": "Oh. A sound that doesn't need processing. Lovely.",
		"disliked": "Page turns activate my document scanner. Another texture?",
		"outro": "STATUS: nothing to optimize. Saving this feeling.",
		"returns": ["I installed a sunset instead of an update.",
			"My new favorite number is approximately enough."],
	},
}

const ACHIEVEMENTS := {
	"asmr_doctor_first_care": {"title": "A little lighter",
		"description": "Soothe your first patient.", "badge": "AHH"},
	"asmr_doctor_first_shift": {"title": "Room for quiet",
		"description": "Complete a three-patient shift.", "badge": "CALM"},
	"asmr_doctor_all_friends": {"title": "A clinic for everyone",
		"description": "Welcome all six patients back to calm.", "badge": "SIX"},
	"asmr_doctor_listener": {"title": "A good listener",
		"description": "Discover every patient's favorite trigger.", "badge": "EAR"},
}

const PLANT_SLOT := "asmr_doctor_plant"
const LAMP_SLOT := "asmr_doctor_lamp"
const RUG_SLOT := "asmr_doctor_rug"
const STORE_CURRENCY := {
	"name": "Kindness Token", "plural": "Kindness Tokens",
	"points_per_score": 0.0, "round_bonus": 0, "win_bonus": 0,
}
const STORE_SLOTS: Array[Dictionary] = [
	{"id": PLANT_SLOT, "kind": "plant", "title": "Windowsill"},
	{"id": LAMP_SLOT, "kind": "lamp", "title": "Reading light"},
	{"id": RUG_SLOT, "kind": "rug", "title": "Clinic rug"},
]
const STORE_ITEMS: Array[Dictionary] = [
	{"id": "asmr_fern", "kind": "plant", "title": "Faithful fern", "default": true,
		"price": 0, "badge": "FERN", "color": Color("a5c5a5"),
		"description": "Excellent at listening. A little less good at paperwork."},
	{"id": "asmr_moonflowers", "kind": "plant", "title": "Moonflowers",
		"price": 18, "badge": "BLOOM", "color": Color("d1badd"),
		"description": "A tiny night garden. Cosmetic; it never changes treatment."},
	{"id": "asmr_honey_lamp", "kind": "lamp", "title": "Honey lamp", "default": true,
		"price": 0, "badge": "GLOW", "color": Color("e6c594"),
		"description": "The color of a good cup of tea."},
	{"id": "asmr_rose_lamp", "kind": "lamp", "title": "Rose lantern",
		"price": 24, "badge": "ROSE", "color": Color("dfb3bd"),
		"description": "A softer shade for the same safe little room."},
	{"id": "asmr_sage_rug", "kind": "rug", "title": "Sage rug", "default": true,
		"price": 0, "badge": "SAGE", "color": Color("b0c5ad"),
		"description": "Quiet footsteps begin here."},
	{"id": "asmr_twilight_rug", "kind": "rug", "title": "Twilight rug",
		"price": 30, "badge": "DUSK", "color": Color("b3a5c5"),
		"description": "A little patch of evening, even at lunchtime."},
]

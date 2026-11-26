extends RefCounted

## A self-paced clinic, discovered and presented through the shared game shell.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "ASMR Doctor"
	game.tagline = "A little care. A little quieter."
	game.menu_order = 21
	game.gameplay_scene_path = "res://games/asmr_doctor/gameplay.tscn"
	game.intro_scene_path = "res://games/asmr_doctor/intro.tscn"
	game.tutorial_video_path = "res://games/asmr_doctor/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/asmr_doctor/assets/video/tutorial_poster.webp"
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.uses_shell_round_rules = false
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.control_bindings = Options.CONTROL_BINDINGS
	game.tunables = Options.TUNABLES
	game.achievements = Options.ACHIEVEMENTS
	game.store_items = Options.STORE_ITEMS
	game.store_slots = Options.STORE_SLOTS
	game.store_currency = Options.STORE_CURRENCY
	game.store_preview_scene_path = "res://games/asmr_doctor/clinic_art.tscn"
	game.share_art_scene_path = "res://games/asmr_doctor/clinic_art.tscn"
	game.stats_url = "https://deskcansaw.com"
	game.save_files = [{
		"path": Options.SAVE_PATH, "title": "Clinic journal",
		"description": "Completed appointments, returning friends, favorite triggers and shifts.",
	}]
	game.copy = {
		"single_player_description": "Run a tiny, magical clinic at your own pace.",
		"instructions_headline": "Make a little room for quiet.",
		"instructions_rules": (
			"Welcome three patients per shift. Choose a tool, listen to their hints, "
			+ "and help their calm meter fill. There is no timer, losing or passive stress.\n"
			+ "Hold the care button for whispering and brushing. Press once per sound "
			+ "for taps, pages, silk and snips. The rhythm ring suggests a gentle pace; "
			+ "long pauses are always fine. A favorite sound works faster; sensitive "
			+ "sounds work more slowly. Sudden loud microphone input causes a small, recoverable startle.\n"
			+ "Page turning unlocks after 2 completed patients, silk after 3 and snips "
			+ "after 4. Preferences and completed appointments save immediately. "
			+ "An unfinished shift restarts on your next visit; journal progress stays.\n"
			+ "Complete all three appointments and close the shift to earn 18 Kindness "
			+ "Tokens for cosmetic plants, lamps and rugs in the Store. Nothing affects treatment strength.\n"
			+ "The microphone is OFF until you explicitly enable it. Stay quiet for "
			+ "calibration, then whisper softly or make gentle sounds. It measures "
			+ "loudness and rhythm, not words or sound identity. Audio stays in memory "
			+ "on this device and is never monitored, recorded or uploaded. Headphones "
			+ "prevent your soundscape from being picked up. Pause, focus loss, journal, "
			+ "rest and leaving the clinic stop capture; resuming never reopens it.\n"
			+ "Soundscapes mixes rain, fire and room tone. Rest mode has no goals, "
			+ "scoring or rewards; return whenever you like. Every treatment works "
			+ "with mouse/keyboard and even with all sound muted."
		),
		"instructions_demo_prompt": "SPEAK SOFTLY. TAKE YOUR TIME.",
		"instructions_solo_summary": "Three appointments. No deadline. All input modes share the same care.",
		"instructions_player_one_controls": (
			"Start in the 3D doctor's view. Hold right mouse to look; release for menus. "
			+ "C or the view button switches to the illustrated room and back. "
			+ "Choose a tool, then use the care button or click the clinic. "
			+ "Hold for continuous care; press for individual rhythmic sounds. "
			+ "Tab and Enter navigate the clinic. Esc pauses."
		),
		"store_intro": (
			"A complete three-patient shift earns 18 Kindness Tokens. "
			+ "Everything here is cosmetic, and the original furnishings are free."
		),
	}
	game.credits = [{
		"heading": "ASMR Doctor",
		"lines": [
			"Design, code, original illustrated clinic and synthesized audio - DeskCanSaw",
			"A fictional relaxation game, not medical care or a microphone recording tool.",
		],
	}]
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://games/asmr_doctor/assets/icon.svg"
	theme.cover_texture_path = "res://games/asmr_doctor/assets/cover.svg"
	theme.plaque_color = Color("303338")
	theme.accent = Color("c5d6b7")
	theme.light = Color("f6e5c4")
	theme.background_top = Color("343b3c")
	theme.background_bottom = Color("1b242c")
	theme.style_share_card = true
	game.theme = theme
	return game

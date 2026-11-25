extends GameShell

## The clinic owns self-paced care; shared menus own pause, options and results.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const Session := preload("res://games/asmr_doctor/clinic_session.gd")
const Progress := preload("res://games/asmr_doctor/clinic_progress.gd")
const View := preload("res://games/asmr_doctor/clinic_view.gd")
const Soundscape := preload("res://games/asmr_doctor/soundscape.gd")
const Microphone := preload("res://games/asmr_doctor/microphone.gd")

@onready var _clinic: Control = %Clinic
@onready var _header: HFlowContainer = %ClinicHeader
@onready var _compact_menu: MenuButton = %CompactMenu
@onready var _body: BoxContainer = %ClinicBody
@onready var _room_column: VBoxContainer = %RoomColumn
@onready var _view: View = %ClinicView
@onready var _patient_panel: PanelContainer = %PatientPanel
@onready var _patient_stack: VBoxContainer = %PatientStack
@onready var _patient_details: VBoxContainer = %PatientDetails
@onready var _patient_scroll: ScrollContainer = %PatientScroll
@onready var _rest_scroll: ScrollContainer = %RestScroll
@onready var _patient_name: Label = %PatientName
@onready var _patient_role: Label = %PatientRole
@onready var _dialogue: Label = %Dialogue
@onready var _appointment_label: Label = %AppointmentLabel
@onready var _calm_label: Label = %CalmLabel
@onready var _calm_meter: ProgressBar = %CalmMeter
@onready var _reaction: Label = %Reaction
@onready var _tray: GridContainer = %ToolTray
@onready var _tool_hint: Label = %ToolHint
@onready var _treatment_controls: VBoxContainer = %TreatmentControls
@onready var _care_dock: VBoxContainer = %CareDock
@onready var _care_button: Button = %CareButton
@onready var _mic_button: Button = %MicButton
@onready var _mic_meter: ProgressBar = %MicMeter
@onready var _mic_status: Label = %MicStatus
@onready var _next_button: Button = %NextPatient
@onready var _rest_button: Button = %RestButton
@onready var _save_status: Label = %SaveStatus
@onready var _retry_save: Button = %RetrySave
@onready var _shift_label: Label = %ShiftLabel
@onready var _wallet_label: Label = %WalletLabel
@onready var _sound_caption: Label = %SoundCaption
@onready var _shade: ColorRect = %SheetShade
@onready var _sheet: PanelContainer = %SheetPanel
@onready var _sheet_scroll: ScrollContainer = %SheetScroll
@onready var _sheet_content: VBoxContainer = %SheetContent
@onready var _sound: Soundscape = %Soundscape
@onready var _mic: Microphone = %Microphone

var _session := Session.new()
var _progress := Progress.new()
var _queue: Array[String] = []
var _tool_buttons: Dictionary[String, Button] = {}
var _built := false
var _appointment_index := 0
var _appointment_saved := false
var _shift_patients := 0
var _shift_completed := false
var _shift_recorded := false
var _shift_attempts := 0
var _shift_gentle := 0
var _shift_startles := 0
var _sleep_mode := false
var _key_held := false
var _pointer_held := false
var _mic_latched := false
var _focus_suspended := false
var _reaction_time := 0.0
var _save_error := OK
var _sheet_kind := ""
var _sheet_focus: Control
var _finished_clinic: Dictionary = {}
var _capture_inset := 0.0
var _web_window: JavaScriptObject
var _web_focus_callback: JavaScriptObject


func game_id() -> String:
	return Options.GAME_ID


func _build_playfield() -> void:
	var error := _progress.load_save()
	if error not in [OK, ERR_FILE_NOT_FOUND]:
		push_warning("ASMR Doctor: clinic save was not loaded (%s)." % error_string(error))
		_save_error = error
	for index in Options.TOOL_ORDER.size():
		var id := Options.TOOL_ORDER[index]
		var button := Button.new()
		button.name = "Tool_" + id
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_select_tool.bind(id))
		_tray.add_child(button)
		_tool_buttons[id] = button
	_care_button.button_down.connect(_care_down)
	_care_button.button_up.connect(_care_up)
	_view.care_pressed.connect(_care_down)
	_view.care_released.connect(_care_up)
	_next_button.pressed.connect(_next_patient)
	_mic_button.pressed.connect(_toggle_microphone)
	_mic.status_changed.connect(_on_mic_status)
	_mic.capture_failed.connect(_on_mic_failed)
	_mic.calibrated.connect(_on_mic_calibrated)
	(%JournalButton as Button).pressed.connect(_open_sheet.bind("journal"))
	(%SoundsButton as Button).pressed.connect(_open_sheet.bind("sounds"))
	_rest_button.pressed.connect(_toggle_rest)
	(%ReturnFromRest as Button).pressed.connect(_toggle_rest)
	(%ClinicMenu as Button).pressed.connect(open_pause_menu)
	_compact_menu.get_popup().id_pressed.connect(_on_compact_menu_item)
	_retry_save.pressed.connect(_retry_persistence)
	Store.equipped_changed.connect(_on_equipment_changed)
	Store.points_changed.connect(_on_points_changed)
	get_viewport().size_changed.connect(_layout_clinic)
	get_window().focus_exited.connect(_on_focus_exited)
	get_window().focus_entered.connect(_on_focus_entered)
	_built = true
	_apply_audio_settings()
	_apply_equipment()
	_refresh_save_status()
	_layout_clinic()
	_on_controls_changed()
	_connect_web_focus()


func _configure_mode_ui() -> void:
	super()
	_player_one_caption.text = "CARE GIVEN"
	_time_caption.text = "APPOINTMENTS"
	_time_label.text = "%d / %d" % [_shift_patients, Options.APPOINTMENTS_PER_SHIFT]
	_callout.hide()
	_play_again_button.text = "Open another shift"
	_round_instructions.text = "Completed care stays in your journal. Another shift brings more friends."
	_share_card_hint.text = "A quiet keepsake. The QR opens the studio website, not a public patient record."


func _reset_round_state() -> void:
	_stop_input()
	_queue = _progress.next_queue()
	_appointment_index = 0
	_shift_patients = 0
	_shift_attempts = 0
	_shift_gentle = 0
	_shift_startles = 0
	_shift_completed = false
	_shift_recorded = false
	_sleep_mode = false
	_finished_clinic.clear()
	_begin_appointment()


func _activate_round() -> void:
	_clinic.show()
	_sound.start()
	_refresh_controls()
	_layout_clinic.call_deferred()


func _begin_appointment() -> void:
	var id := _queue[_appointment_index]
	_appointment_saved = false
	_session.begin(id, _progress.favorites.has(id))
	var patient: Dictionary = Options.PATIENTS[id]
	_patient_name.text = str(patient["name"])
	_patient_role.text = str(patient["role"])
	var visits := _progress.visits_of(id)
	var returns: Array = patient["returns"]
	_dialogue.text = str(patient["intro"]) if visits == 0 else str(
		returns[mini(visits - 1, returns.size() - 1)]
	)
	_reaction.text = str(patient["hint"])
	_reaction_time = 0.0
	_appointment_label.text = "TODAY'S VISITOR / %d OF %d" % [
		_appointment_index + 1, Options.APPOINTMENTS_PER_SHIFT,
	]
	_patient_scroll.scroll_vertical = 0
	_refresh_controls()
	_refresh_frame()


func _update_round(delta: float, _time_left: float) -> void:
	if not _can_treat():
		return
	_reaction_time += delta
	var manual := _key_held or _pointer_held
	var strength := maxf(0.4 if manual else 0.0, _mic.normalized_level)
	_consume_response(_session.advance(delta, strength))
	if _mic.ready_for_input:
		if _mic.normalized_level < 0.04:
			_mic_latched = false
		elif _mic.normalized_level >= 0.1 and not _mic_latched:
			_mic_latched = true
			if str(Options.TOOLS[_session.tool_id]["kind"]) == "pulse":
				_perform_pulse(_mic.normalized_level)
	_mic_meter.value = _mic.normalized_level
	if _mic.ready_for_input:
		_mic_status.text = (
			"A little loud. Try a softer sound." if _mic.normalized_level > 1.0
			else "Listening locally / gentle sound" if _mic.normalized_level >= 0.08
			else "Listening locally / quiet"
		)
	var continuous := str(Options.TOOLS[_session.tool_id]["kind"]) == "hold"
	if continuous and strength >= 0.08 and strength <= 1.0:
		_sound.hold_care(_session.tool_id, strength)
	else:
		_sound.end_care()
	_view.caring = strength >= 0.08
	_refresh_frame()
	if _session.complete:
		_complete_appointment()


func _input(event: InputEvent) -> void:
	if not _built:
		return
	if event.is_action_released(Options.TREAT_ACTION):
		_key_held = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_pointer_held = false
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _shade.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_close_sheet()
			get_viewport().set_input_as_handled()
		return
	if not _round_active or get_tree().paused:
		return
	if event.is_action_pressed(Options.JOURNAL_ACTION):
		_open_sheet("journal")
	elif event.is_action_pressed(Options.SOUNDS_ACTION):
		_open_sheet("sounds")
	elif event.is_action_pressed(Options.SLEEP_ACTION):
		_toggle_rest()
	elif _can_treat() and event.is_action_pressed(Options.TREAT_ACTION):
		_key_held = true
		if str(Options.TOOLS[_session.tool_id]["kind"]) == "pulse":
			_perform_pulse()
	else:
		for index in Options.TOOL_ACTIONS.size():
			if event.is_action_pressed(Options.TOOL_ACTIONS[index]):
				_select_tool(Options.TOOL_ORDER[index])
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()


func _care_down() -> void:
	if not _can_treat():
		return
	_pointer_held = true
	if str(Options.TOOLS[_session.tool_id]["kind"]) == "pulse":
		_perform_pulse()


func _care_up() -> void:
	_pointer_held = false


func _perform_pulse(strength := 0.4) -> void:
	if not _can_treat():
		return
	var response := _session.pulse(strength)
	if float(response.get("gain", 0.0)) > 0.0:
		_sound.pulse(_session.tool_id)
	_consume_response(response)
	_refresh_frame()
	if _session.complete:
		_complete_appointment()


func _select_tool(id: String) -> void:
	if not _can_treat():
		return
	if not _session.select_tool(id, _progress.total_visits):
		_reaction.text = "This tool arrives after %d completed patients." % Options.TOOLS[id]["unlock"]
		return
	_key_held = false
	_pointer_held = false
	_mic_latched = true
	_sound.end_care()
	_reaction.text = str(Options.PATIENTS[_session.patient_id]["hint"])
	_refresh_controls()
	_refresh_frame()


func _consume_response(response: Dictionary) -> void:
	if response.is_empty():
		return
	var patient: Dictionary = Options.PATIENTS[_session.patient_id]
	var kind := str(response.get("kind", ""))
	var discovered := bool(response.get("discovery", false))
	if discovered and _progress.discover(_session.patient_id):
		_persist_progress()
	var message := str(response.get("message", ""))
	if message.is_empty():
		match kind:
			"favorite":
				message = str(patient["liked"])
			"sensitive":
				message = str(patient["disliked"])
			_:
				message = "Their shoulders soften. A little quieter, a little lighter."
	if discovered:
		message += "\nFavorite discovered: " + str(Options.TOOLS[_session.tool_id]["title"])
	if discovered or _reaction_time >= 2.5 or kind == "loud":
		_reaction.text = message
		_reaction_time = 0.0
		AudioManager.request_caption(message)


func _complete_appointment() -> void:
	if _appointment_saved:
		return
	var before := _progress.total_visits
	_stop_input()
	_appointment_saved = true
	_shift_patients += 1
	_shift_attempts += _session.attempts
	_shift_gentle += _session.gentle_actions
	_shift_startles += _session.startles
	_progress.record_visit(_session.patient_id)
	_dialogue.text = str(Options.PATIENTS[_session.patient_id]["outro"])
	var unlocked := PackedStringArray()
	for id in Options.TOOL_ORDER:
		var threshold := int(Options.TOOLS[id]["unlock"])
		if threshold > before and threshold <= _progress.total_visits:
			unlocked.append(str(Options.TOOLS[id]["title"]))
	_reaction.text = "A little lighter. Thank you for taking your time."
	if not unlocked.is_empty():
		_reaction.text += "\nNew in your tray: " + ", ".join(unlocked) + "."
	if _persist_progress():
		_check_clinic_achievements()
	_refresh_controls()
	_refresh_frame()
	AudioManager.request_caption("%s feels calm. %s" % [_patient_name.text, _dialogue.text])
	_next_button.grab_focus()


func _next_patient() -> void:
	if not _round_active or not _appointment_saved or get_tree().paused:
		return
	if _appointment_index + 1 == Options.APPOINTMENTS_PER_SHIFT:
		if not _shift_recorded:
			_progress.completed_shifts += 1
			_shift_recorded = true
		if not _persist_progress():
			return
		_shift_completed = true
		_end_round()
		return
	if not _persist_progress():
		return
	_stop_input()
	_appointment_index += 1
	_begin_appointment()
	_care_button.grab_focus()


func _refresh_frame() -> void:
	if not _built or _session.patient_id.is_empty():
		return
	_calm_label.text = "%d%% calm" % roundi(100.0 - _session.stress)
	_calm_meter.value = 100.0 - _session.stress
	_view.patient_id = _session.patient_id
	_view.tool_id = _session.tool_id
	_view.stress = _session.stress
	_view.sleeping = _sleep_mode
	_view.night = _is_night()
	_view.rhythm = _session.rhythm_phase()
	_view.favorite = _session.favorite_found and _session.affinity() > 1.0
	_view.queue_redraw()
	_scores[PLAYER_ONE] = _shift_patients * 100 \
		+ (0 if _appointment_saved else roundi(_session.progress() * 100.0))
	_update_scores()
	_time_label.text = "%d / %d" % [_shift_patients, Options.APPOINTMENTS_PER_SHIFT]


func _refresh_controls() -> void:
	if not _built:
		return
	for index in Options.TOOL_ORDER.size():
		var id := Options.TOOL_ORDER[index]
		var tool: Dictionary = Options.TOOLS[id]
		var button := _tool_buttons[id]
		var locked := _progress.total_visits < int(tool["unlock"])
		var binding := Settings.binding_keycode(str(Options.CONTROL_BINDINGS[index + 1]["key"]))
		button.text = "%s  %s%s" % [
			OS.get_keycode_string(binding), tool["title"],
			"\nAfter %d patients" % tool["unlock"] if locked else "",
		]
		button.disabled = locked or not _progress.writable or _session.complete
		button.set_pressed_no_signal(id == _session.tool_id)
		button.tooltip_text = str(tool["hint"])
		button.accessibility_name = "%s%s" % [tool["title"], " (selected)" if id == _session.tool_id else ""]
	_tool_hint.text = str(Options.TOOLS[_session.tool_id]["hint"])
	var treat_key := OS.get_keycode_string(Settings.binding_keycode("controls/asmr_doctor_treat"))
	_care_button.text = "%s / %s" % [Options.TOOLS[_session.tool_id]["verb"], treat_key]
	_care_button.disabled = not _progress.writable
	_mic_button.disabled = not _progress.writable
	_treatment_controls.visible = not _appointment_saved
	_care_dock.visible = not _appointment_saved and not _sleep_mode
	_next_button.visible = _appointment_saved
	_next_button.text = (
		"Close shift / +%d Kindness Tokens" % Options.SHIFT_TOKENS
		if _appointment_index + 1 == Options.APPOINTMENTS_PER_SHIFT
		else "Welcome the next patient"
	)
	_patient_scroll.visible = not _sleep_mode
	_rest_scroll.visible = _sleep_mode
	var compact_nav := _compact_layout()
	_rest_button.text = ("Return" if compact_nav else "Return to clinic") \
		if _sleep_mode else ("Rest" if compact_nav else "Rest mode")
	_rest_button.accessibility_name = "Return to clinic" if _sleep_mode else "Rest mode"
	_shift_label.text = ("%s / %02d" if compact_nav else "%s SHIFT / %02d") % [
		"MIDNIGHT" if _is_night() else "AFTERNOON", _progress.completed_shifts + 1,
	]
	var popup := _compact_menu.get_popup()
	popup.clear()
	for item: String in ["Patient journal", "Soundscapes",
		"Return to clinic" if _sleep_mode else "Rest mode", "Pause / Settings / Decor"]:
		popup.add_item(item)
	_wallet_label.text = Store.format_points(game_id(), Store.points(game_id()))
	_view.set_motion(not _reduced_motion_enabled and not _shade.visible and _round_active)


func _toggle_rest() -> void:
	if not _round_active or get_tree().paused:
		return
	_close_sheet()
	_stop_input()
	_sleep_mode = not _sleep_mode
	_refresh_controls()
	_refresh_frame()
	_layout_clinic.call_deferred()
	_rest_button.grab_focus()


func _toggle_microphone() -> void:
	if _mic.active:
		_stop_input()
	elif _can_treat():
		_open_sheet("microphone")


func _enable_microphone() -> void:
	_close_sheet()
	if not _can_treat():
		return
	_stop_input()
	_sound.set_microphone_active(true)
	_mic.start()
	_sound.set_microphone_active(_mic.active)


func _on_mic_status(message: String) -> void:
	_mic_status.text = message
	_mic_button.text = "Stop mic" if _mic.active else "Enable mic"
	_sound.set_microphone_active(_mic.active)
	_mic_meter.value = 0.0


func _on_mic_failed(message: String) -> void:
	_on_mic_status(message)
	AudioManager.request_caption(message)


func _on_mic_calibrated() -> void:
	_mic_latched = true


func _stop_input() -> void:
	_key_held = false
	_pointer_held = false
	_mic_latched = false
	if not _built:
		return
	_mic.stop()
	_sound.set_microphone_active(false)
	_sound.end_care()
	_view.caring = false


func _can_treat() -> bool:
	return _built and _round_active and not get_tree().paused \
		and not _focus_suspended and not _sleep_mode and not _shade.visible \
		and not _session.complete and _progress.writable


func _open_sheet(kind: String) -> void:
	if not _built or not _round_active or get_tree().paused:
		return
	_stop_input()
	_sheet_focus = get_viewport().gui_get_focus_owner()
	_sheet_kind = kind
	for child in _sheet_content.get_children():
		_sheet_content.remove_child(child)
		child.queue_free()
	_shade.show()
	_view.set_motion(false)
	match kind:
		"journal":
			_build_journal()
		"sounds":
			_build_sound_mixer()
		"microphone":
			_sheet_label("A quiet word about the microphone", 26)
			_sheet_label(
				"Optional. Local. Never recorded.\n\n"
				+ "Only sound level and rhythm are used, not your words. "
				+ "Audio stays in memory on this device and is never played back or uploaded.\n\n"
				+ "Use headphones. Stay quiet for calibration, then make soft sounds. "
				+ "Your browser or operating system may ask permission.\n\n"
				+ "Pause, focus loss, journal and rest stop capture. It never restarts by itself.", 16
			)
			_sheet_button("Enable for this visit", _enable_microphone, "ConfirmMicrophone")
	var close := _sheet_button("Back to clinic", _close_sheet, "CloseSheet")
	_layout_clinic()
	_sheet_scroll.scroll_vertical = 0
	AudioManager.attach_ui_sounds(_sheet)
	close.grab_focus()


func _close_sheet() -> void:
	if not _built:
		return
	_shade.hide()
	_sheet_kind = ""
	_view.set_motion(not _reduced_motion_enabled)
	if is_instance_valid(_sheet_focus) and _sheet_focus.is_visible_in_tree():
		_sheet_focus.grab_focus()
	_sheet_focus = null


func _build_journal() -> void:
	_sheet_label("The patient journal", 28)
	_sheet_label("%d completed appointments / %d favorite sounds discovered" % [
		_progress.total_visits, _progress.favorites.size(),
	], 16)
	for id in Options.PATIENT_ORDER:
		var patient: Dictionary = Options.PATIENTS[id]
		var count := _progress.visits_of(id)
		_sheet_label(str(patient["name"]) + " / " + str(patient["role"]), 19)
		var favorite_text := str(Options.TOOLS[str(patient["favorite"])]["title"]) \
			if _progress.favorites.has(id) else "not discovered yet"
		var entry := "%d visits / Favorite: %s" % [count, favorite_text]
		if count > 0:
			var returns: Array = patient["returns"]
			entry += "\n" + (str(patient["outro"]) if count == 1
				else str(returns[mini(count - 2, returns.size() - 1)]))
		else:
			entry += "\nA little story still to come."
		_sheet_label(entry, 15)


func _build_sound_mixer() -> void:
	_sheet_label("A room that sounds like you", 26)
	_sheet_label("Adjust gently. Changes save with your settings; headphones are welcome.", 15)
	for entry: Array in [
		["Rain at the window", Options.RAIN_KEY],
		["Little fireplace", Options.FIRE_KEY],
		["Dreamy room tone", Options.ROOM_KEY],
		["Treatment intensity", Options.INTENSITY_KEY],
	]:
		var label := _sheet_label("", 16)
		var slider := HSlider.new()
		slider.name = "Mix_" + str(entry[1]).get_slice("/", 1).trim_prefix("asmr_doctor_")
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.tunable(str(entry[1]))
		slider.custom_minimum_size.y = 36.0 * _shell_hud_unit
		label.text = "%s / %d%%" % [entry[0], roundi(slider.value * 100)]
		slider.accessibility_name = str(entry[0])
		slider.value_changed.connect(func(value: float) -> void:
			label.text = "%s / %d%%" % [entry[0], roundi(value * 100)]
			Settings.set_value(str(entry[1]), value)
		)
		_sheet_content.add_child(slider)
	for entry: Array in [
		["Silent treatments", Options.SILENT_KEY],
		["Allow snipping sounds", Options.SNIPS_KEY],
		["Allow crinkling sounds", Options.CRINKLE_KEY],
	]:
		var toggle := CheckButton.new()
		toggle.text = str(entry[0])
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toggle.button_pressed = Settings.tunable_bool(str(entry[1]))
		toggle.toggled.connect(func(value: bool) -> void:
			Settings.set_value(str(entry[1]), value)
		)
		_sheet_content.add_child(toggle)


func _sheet_label(text: String, pixels: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("clinic_pixels", pixels)
	_sheet_content.add_child(label)
	return label


func _sheet_button(text: String, action: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	_sheet_content.add_child(button)
	return button


func _persist_progress() -> bool:
	_save_error = _progress.save()
	if _save_error != OK:
		push_warning("ASMR Doctor: clinic could not save (%s)." % error_string(_save_error))
	_refresh_save_status()
	return _save_error == OK


func _retry_persistence() -> void:
	if _persist_progress():
		_check_clinic_achievements()


func _refresh_save_status() -> void:
	if not _progress.writable:
		_save_status.text = (
			"This clinic save is damaged or from a newer version. Nothing was overwritten. "
			+ "Return to the title's Saves screen to restore a backup or delete this game's save. "
			+ "Rest mode and soundscapes still work."
		)
	elif _save_error != OK:
		_save_status.text = "Couldn't save the journal (%s). Keep this window open and retry." \
			% error_string(_save_error)
	else:
		_save_status.text = "Completed care and discoveries saved. A full shift earns 18 Kindness Tokens."
	_retry_save.visible = _progress.writable and _save_error != OK


func _check_clinic_achievements() -> void:
	if _progress.total_visits > 0:
		_unlock_round_achievement("asmr_doctor_first_care")
	if _progress.all_patients_helped():
		_unlock_round_achievement("asmr_doctor_all_friends")
	if _progress.favorites.size() == Options.PATIENT_ORDER.size():
		_unlock_round_achievement("asmr_doctor_listener")


func _apply_audio_settings() -> void:
	_sound.configure({
		"rain": Settings.tunable(Options.RAIN_KEY),
		"fire": Settings.tunable(Options.FIRE_KEY),
		"room": Settings.tunable(Options.ROOM_KEY),
	}, Settings.tunable(Options.INTENSITY_KEY), Settings.tunable_bool(Options.SILENT_KEY),
		Settings.tunable_bool(Options.SNIPS_KEY), Settings.tunable_bool(Options.CRINKLE_KEY))
	_mic.sensitivity = Settings.tunable(Options.MIC_GAIN_KEY)
	var captions := PackedStringArray()
	for pair: Array in [
		[Options.RAIN_KEY, "Rain at the window"], [Options.FIRE_KEY, "A tiny fire"],
		[Options.ROOM_KEY, "Dreamy room tone"],
	]:
		if Settings.tunable(str(pair[0])) > 0.0:
			captions.append(str(pair[1]))
	_sound_caption.text = " / ".join(captions) if not captions.is_empty() else "A little welcome silence."


func _apply_equipment() -> void:
	_view.plant_id = Store.equipped_id(game_id(), Options.PLANT_SLOT)
	_view.lamp_id = Store.equipped_id(game_id(), Options.LAMP_SLOT)
	_view.rug_id = Store.equipped_id(game_id(), Options.RUG_SLOT)
	_view.queue_redraw()


func _on_equipment_changed(id: String, _slot: String, _item: String) -> void:
	if id == game_id() and _built:
		_apply_equipment()


func _on_points_changed(id: String, _points: int) -> void:
	if id == game_id() and _built:
		_wallet_label.text = Store.format_points(id, Store.points(id))


func _is_night() -> bool:
	var choice := Settings.tunable_choice(Options.LIGHTING_KEY)
	return choice == 2 or (choice == 0 and _progress.completed_shifts % 2 == 1)


func _compact_layout() -> bool:
	var ui_scale := float(Settings.get_value("ui/scale", 1.0))
	return get_window().size.x / ui_scale < 740.0 or get_window().size.y / ui_scale < 480.0


func _on_compact_menu_item(id: int) -> void:
	match id:
		0:
			_open_sheet("journal")
		1:
			_open_sheet("sounds")
		2:
			_toggle_rest()
		3:
			open_pause_menu()


func _layout_clinic() -> void:
	if not _built:
		return
	var bounds := _playfield_bounds()
	bounds.size.y = maxf(0.0, bounds.size.y - _capture_inset)
	var unit := _shell_hud_unit
	var width := minf(1360.0 * unit, bounds.size.x)
	_clinic.position = bounds.position + Vector2((bounds.size.x - width) * 0.5, 0)
	_clinic.size = Vector2(width, bounds.size.y)
	var portrait := width / unit < 740.0 or Responsive.is_portrait(get_viewport_rect().size)
	var compact_nav := _compact_layout()
	_compact_menu.visible = compact_nav
	for node: Control in [%JournalButton, %SoundsButton, %RestButton, %ClinicMenu]:
		node.visible = not compact_nav
	_shift_label.custom_minimum_size.x = minf(280.0 * unit, width)
	_wallet_label.custom_minimum_size.x = minf(148.0 * unit, width)
	_body.vertical = portrait
	_body.add_theme_constant_override("separation", roundi(14.0 * unit))
	_room_column.size_flags_stretch_ratio = 0.9 if portrait else 1.7
	_patient_panel.size_flags_stretch_ratio = 1.0
	_room_column.custom_minimum_size.y = minf(200.0 * unit, bounds.size.y * 0.45) if portrait else 0.0
	_patient_panel.custom_minimum_size.x = 0.0 if portrait else minf(width * 0.42, 350.0 * unit)
	# Keep care in reach on desktop; let the whole card scroll on short screens.
	var dock_parent: Node = _patient_details \
		if portrait or bounds.size.y / unit < 460.0 else _patient_stack
	if _care_dock.get_parent() != dock_parent:
		_care_dock.reparent(dock_parent)
		if dock_parent == _patient_stack:
			_patient_stack.move_child(_care_dock, 1)
	for label: Label in _clinic.find_children("*", "Label", true, false):
		_style_clinic_label(label)
	for button: Button in _clinic.find_children("*", "Button", true, false):
		_style_clinic_button(button)
	if compact_nav:
		_shift_label.add_theme_font_size_override("font_size", roundi(18.0 * unit))
	(%SoundsButton as Button).text = "Sounds" if portrait else "Soundscapes"
	(%ClinicMenu as Button).text = "Menu" if portrait else "Menu / Decor"
	_care_button.custom_minimum_size.y = 52.0 * unit
	_header.add_theme_constant_override("h_separation", roundi(8.0 * unit))
	_header.add_theme_constant_override("v_separation", roundi(5.0 * unit))
	_style_panel(_patient_panel, unit)
	var screen := get_viewport_rect().size
	_sheet.size = Vector2(minf(620.0 * unit, screen.x - 24.0 * unit),
		maxf(1.0, minf(640.0 * unit, screen.y - 28.0 * unit)))
	_sheet.position = (screen - _sheet.size) * 0.5
	_style_panel(_sheet, unit)
	for label: Label in _sheet_content.find_children("*", "Label", true, false):
		_style_clinic_label(label)
	for button: Button in _sheet_content.find_children("*", "Button", true, false):
		_style_clinic_button(button)


func _set_capture_inset(bottom: float) -> void:
	_capture_inset = maxf(0.0, bottom)
	_layout_clinic()


func _style_clinic_label(label: Label) -> void:
	if not label.has_meta("clinic_pixels"):
		label.set_meta("clinic_pixels", label.get_theme_font_size("font_size"))
	label.add_theme_font_size_override("font_size",
		roundi(float(label.get_meta("clinic_pixels")) * _shell_hud_unit))


func _style_clinic_button(button: Button) -> void:
	button.custom_minimum_size.y = 42.0 * _shell_hud_unit
	button.add_theme_font_size_override("font_size", roundi(14.0 * _shell_hud_unit))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := button.get_theme_stylebox(state).duplicate() as StyleBox
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			box.set_content_margin(side, 9.0 * _shell_hud_unit)
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			box.set_content_margin(side, 6.0 * _shell_hud_unit)
		button.add_theme_stylebox_override(state, box)


func _style_panel(panel: PanelContainer, unit: float) -> void:
	var box := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	box.bg_color.a = 0.97 if Settings.tunable_bool(Options.CONTRAST_KEY) else 0.72
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, 14.0 * unit)
	panel.add_theme_stylebox_override("panel", box)


func _on_controls_changed() -> void:
	super()
	if _built:
		_hint.text = "Hold for whispers/brushes; press for rhythmic tools. " \
			+ "Journal and soundscapes pause care. Mic is always opt-in."
		_refresh_controls()


func _on_game_setting_changed(_key: String, _value: Variant) -> void:
	if not _built:
		return
	_apply_audio_settings()
	_refresh_controls()
	_refresh_frame()
	_layout_clinic()


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _built:
		_view.set_motion(not value and not _shade.visible and _round_active)


func open_pause_menu() -> void:
	_stop_input()
	if _built:
		_close_sheet()
	super()


func _finish_round() -> void:
	_stop_input()
	if _built:
		_finished_clinic = _clinic_snapshot()
		_shade.hide()
		_clinic.hide()
		_view.set_motion(false)


func _round_points_earned(_one: int, _two: int) -> int:
	return Options.SHIFT_TOKENS if _shift_completed else 0


func _award_round_achievements(_one: int, _two: int) -> void:
	if _shift_completed:
		_unlock_round_achievement("asmr_doctor_first_shift")


func _round_totals() -> Dictionary:
	return {"hits": _shift_gentle, "attempts": _shift_attempts}


func _player_stats(player: int) -> Dictionary:
	return {"score": _scores[player], "hits": _shift_gentle, "misses": _shift_startles,
		"accuracy": _accuracy_percent(_shift_gentle, _shift_attempts), "streak": _shift_patients}


func _describe_round_outcome(_one: int, _two: int) -> Dictionary:
	return {
		"result": "A LITTLE QUIETER" if _shift_completed else "A QUIET MOMENT",
		"subtitle": "%d patients left a little lighter. The room will be here tomorrow." % _shift_patients,
		"color": Color("c5d6b7"),
	}


func _round_highlight_summary() -> String:
	return "%d completed appointments / %d favorite sounds in your journal." % [
		_shift_patients, _progress.favorites.size(),
	]


func _spawn_round_confetti(_color: Color) -> void:
	pass


func _clinic_snapshot() -> Dictionary:
	return {"patient": _session.patient_id, "stress": _session.stress, "night": _is_night(),
		"plant": _view.plant_id, "lamp": _view.lamp_id, "rug": _view.rug_id}


func _share_payload() -> Dictionary:
	var result := super()
	result["clinic"] = _finished_clinic.duplicate(true)
	return result


func _notification(what: int) -> void:
	if not _built:
		return
	if what == NOTIFICATION_PAUSED:
		_stop_input()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_exited()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_focus_entered()


func _on_focus_exited() -> void:
	_focus_suspended = true
	_stop_input()


func _on_focus_entered() -> void:
	_focus_suspended = false


func _connect_web_focus() -> void:
	if not OS.has_feature("web"):
		return
	_web_window = JavaScriptBridge.get_interface("window")
	_web_focus_callback = JavaScriptBridge.create_callback(_on_web_focus_changed)
	_web_window.addEventListener("blur", _web_focus_callback)
	_web_window.addEventListener("focus", _web_focus_callback)
	_web_window.document.addEventListener("visibilitychange", _web_focus_callback)
	_on_web_focus_changed([])


func _on_web_focus_changed(_arguments: Array) -> void:
	if not _built or _web_window == null:
		return
	if bool(_web_window.document.hidden) or not bool(_web_window.document.hasFocus()):
		_on_focus_exited()
	else:
		_on_focus_entered()


func _exit_tree() -> void:
	if _web_window != null:
		_web_window.removeEventListener("blur", _web_focus_callback)
		_web_window.removeEventListener("focus", _web_focus_callback)
		_web_window.document.removeEventListener("visibilitychange", _web_focus_callback)
		_web_focus_callback = null
		_web_window = null
	if _built:
		_stop_input()
		_sound.stop()
		_built = false

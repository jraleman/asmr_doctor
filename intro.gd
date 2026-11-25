extends MenuScreen

## Player-paced welcome cards. This scene never opens input hardware.

const CARDS: Array[Dictionary] = [
	{"heading": "Some days arrive a little loud.",
		"body": "An overbooked office worker. A worried knight. A cloud with a lot on their mind.\n\n"
			+ "Your tiny clinic has room for all of them. A little care is enough to begin.",
		"patient": "nimbus", "night": false},
	{"heading": "Listen for the little things.",
		"body": "A wooden tap. A feather's hush. The space between two pages.\n\n"
			+ "Choose a tool, follow each patient's hints, and take your time. "
			+ "Mouse and keyboard do everything. A microphone is only ever your choice.",
		"patient": "mira", "night": false},
	{"heading": "There is room for you, too.",
		"body": "Three appointments make a shift. There is no countdown and no losing.\n\n"
			+ "Keep a journal, make the clinic your own, or put the appointments aside "
			+ "and rest with the rain. You don't have to earn a quiet moment.",
		"patient": "wisp", "night": true},
]

@export_file("*.tscn") var next_scene := "res://scenes/menus/main_menu.tscn"
@onready var _body: BoxContainer = %IntroBody
@onready var _art: Control = %IntroArt
@onready var _heading: Label = %IntroHeading
@onready var _copy: Label = %IntroCopy
@onready var _step: Label = %IntroStep
@onready var _next: Button = %NextButton
@onready var _skip: Button = %SkipButton
var _card := 0
var _finished := false


func _ready() -> void:
	margins = %IntroMargins
	first_focus = _next
	_next.pressed.connect(_on_next_pressed)
	_skip.pressed.connect(_on_skip_pressed)
	_show_card()
	super()


func _show_card() -> void:
	var card := CARDS[_card]
	_heading.text = str(card["heading"])
	_copy.text = str(card["body"])
	_step.text = "A LITTLE WELCOME / %d OF %d" % [_card + 1, CARDS.size()]
	_next.text = "Open the clinic" if _card + 1 == CARDS.size() else "Next"
	_art.call("configure", {"clinic": {
		"patient": card["patient"], "night": card["night"], "stress": 12.0,
	}})


func _on_next_pressed() -> void:
	if _finished:
		return
	if _card + 1 == CARDS.size():
		_on_skip_pressed()
	else:
		_card += 1
		_show_card()


func _on_skip_pressed() -> void:
	if _finished:
		return
	_finished = true
	_next.disabled = true
	_skip.disabled = true
	if Router.is_transitioning():
		await Router.transition_finished
	if is_inside_tree():
		Router.goto(next_scene)


func go_back() -> void:
	_on_skip_pressed()


func _on_layout_changed(size: Vector2) -> void:
	var unit := size.x / maxf(get_window().size.x, 1.0) \
		* float(Settings.get_value("ui/scale", 1.0))
	_body.vertical = size.y > size.x
	_art.size_flags_stretch_ratio = 0.8 if _body.vertical else 1.4
	_heading.add_theme_font_size_override("font_size", roundi(28.0 * unit))
	_copy.add_theme_font_size_override("font_size", roundi(18.0 * unit))
	_step.add_theme_font_size_override("font_size", roundi(12.0 * unit))
	var available := size.x - margins.get_theme_constant("margin_left") \
		- margins.get_theme_constant("margin_right") - 16.0 * unit
	var button_width := minf(180.0 * unit, maxf(1.0, available * 0.5))
	(_next.get_parent() as HBoxContainer).add_theme_constant_override(
		"separation", roundi(16.0 * unit))
	for button in [_next, _skip]:
		button.custom_minimum_size = Vector2(button_width, 46.0 * unit)
		button.add_theme_font_size_override("font_size", roundi(16.0 * unit))

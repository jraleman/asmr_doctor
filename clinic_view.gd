extends Control

## Original vector illustration shared by the clinic, intro, shop and frozen shares.
## This view has no autoload, audio, microphone or persistence dependencies.

signal care_pressed
signal care_released

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const DESIGN := Vector2(1000.0, 760.0)
const INK := Color("555366")

@export var interactive := false
var patient_id := "mira"
var tool_id := "whisper"
var stress := 80.0
var night := false
var sleeping := false
var motion_enabled := true
var caring := false
var favorite := false
var rhythm := 0.0
var plant_id := "asmr_fern"
var lamp_id := "asmr_honey_lamp"
var rug_id := "asmr_sage_rug"
var _time := 0.0
var _origin := Vector2.ZERO
var _unit := 1.0
var _pointer := Vector2(665.0, 430.0)
var _boxes: Dictionary[String, StyleBoxFlat] = {}


func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	accessibility_name = "A softly lit clinic with an illustrated patient in a cushioned chair"


func configure(data: Dictionary) -> void:
	motion_enabled = false
	var snapshot: Dictionary = data.get("clinic", {})
	patient_id = str(snapshot.get("patient", "nimbus"))
	stress = float(snapshot.get("stress", 0.0))
	night = bool(snapshot.get("night", false))
	plant_id = str(snapshot.get("plant", plant_id))
	lamp_id = str(snapshot.get("lamp", lamp_id))
	rug_id = str(snapshot.get("rug", rug_id))
	var id := str(data.get("id", ""))
	match str(data.get("kind", "")):
		"plant":
			plant_id = id
		"lamp":
			lamp_id = id
		"rug":
			rug_id = id
	queue_redraw()


func set_motion(enabled: bool) -> void:
	motion_enabled = enabled
	if not enabled:
		_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if motion_enabled:
		_time += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		_pointer = (event.position - _origin) / maxf(_unit, 0.001)
		if caring:
			queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer = (event.position - _origin) / maxf(_unit, 0.001)
			care_pressed.emit()
		else:
			care_released.emit()
		accept_event()


func _draw() -> void:
	_unit = maxf(0.001, minf(size.x / DESIGN.x, size.y / DESIGN.y))
	_origin = (size - DESIGN * _unit) * 0.5
	_reset_transform()
	_room()
	_furnishings()
	_chair()
	if not sleeping and Options.PATIENTS.has(patient_id):
		_patient()
	_reset_transform()
	_foreground()
	if interactive and not sleeping:
		_rhythm_ring()
		if caring:
			_tool(_pointer.clamp(Vector2(210, 170), Vector2(800, 595)))
	draw_set_transform(Vector2.ZERO)


func _room() -> void:
	_box(Rect2(10, 10, 980, 740), Color("c7c1c6") if night else Color("f0dfc8"), 38)
	_box(Rect2(24, 24, 952, 532), Color("d3c8d6") if night else Color("f4e8d7"), 29)
	for index in 12:
		var x := 46.0 + index * 82.0
		draw_line(Vector2(x, 35), Vector2(x, 538), Color(0.45, 0.38, 0.38, 0.045), 2)
	draw_rect(Rect2(24, 531, 952, 16), Color("c6aea3"))
	_box(Rect2(24, 547, 952, 189), Color("b69e99") if night else Color("d3b49b"), 18)
	for index in 6:
		var y := 565.0 + index * 32.0
		draw_line(Vector2(29, y), Vector2(971, y), Color(0.38, 0.29, 0.28, 0.13), 2)
		for plank in 5:
			var x := 65.0 + plank * 211.0 + (index % 2) * 91.0
			draw_line(Vector2(x, y), Vector2(x + 13, y + 31), Color(0.38, 0.29, 0.28, 0.1), 2)
	# The arch and curtain use the same restful pose under reduced motion.
	_box(Rect2(354, 75, 292, 318), Color("ac9f9e"), 132)
	_box(Rect2(367, 88, 266, 290), Color("65788e") if night else Color("c0d3ca"), 121)
	_box(Rect2(378, 99, 244, 265), Color("758398") if night else Color("dce3cb"), 112)
	if night:
		draw_circle(Vector2(548, 157), 28, Color("f7e9c2"))
		draw_circle(Vector2(560, 149), 24, Color("758398"))
		for point: Vector2 in [Vector2(420, 167), Vector2(478, 127),
				Vector2(576, 232), Vector2(454, 241), Vector2(521, 206)]:
			_star(point, 3.0, Color("f0dfbf"))
	else:
		draw_circle(Vector2(556, 174), 38, Color("efd6a4"))
		_ellipse(Vector2(422, 286), Vector2(92, 48), Color("a3beb1"))
		_ellipse(Vector2(563, 308), Vector2(108, 57), Color("8fae9e"))
	draw_line(Vector2(500, 94), Vector2(500, 376), Color("e9d8bd"), 9, true)
	draw_line(Vector2(370, 255), Vector2(630, 255), Color("e9d8bd"), 9, true)
	_box(Rect2(340, 378, 320, 17), Color("ad9382"), 6)
	for side in [-1, 1]:
		var x := 336.0 if side == -1 else 609.0
		_box(Rect2(x, 97, 56, 278), Color("cdaab0") if night else Color("dfc1b6"), 20)
		for fold in 3:
			draw_line(Vector2(x + 12 + fold * 14, 113),
				Vector2(x + 10 + fold * 16, 362), Color(0.5, 0.3, 0.36, 0.1), 3)
	_text(Vector2(500, 54), "THE LITTLE CLINIC OF CALM", 16, Color("75676c"))


func _furnishings() -> void:
	_box(Rect2(79, 181, 202, 18), Color("ac8b76"), 5)
	for index in 4:
		var colors := [Color("c4b8cc"), Color("a8bdb0"), Color("d5b9a2"), Color("b8c5cc")]
		_box(Rect2(98 + index * 27, 128 - (index % 2) * 12, 21, 53 + (index % 2) * 12),
			colors[index], 3)
		draw_line(Vector2(104 + index * 27, 140), Vector2(104 + index * 27, 171),
			Color(1, 1, 1, 0.3), 2)
	_box(Rect2(224, 138, 30, 43), Color("c4d6cf"), 10)
	_box(Rect2(230, 129, 18, 12), Color("a6a18c"), 3)
	_box(Rect2(104, 243, 145, 147), Color("d1bfa8"), 8)
	_box(Rect2(113, 252, 127, 129), Color("f6ead5"), 4)
	_text(Vector2(177, 283), "a little care", 17, Color("8d827b"))
	_text(Vector2(177, 310), "a little quieter", 17, Color("8d827b"))
	_leaf(Vector2(176, 340), 21, -0.5, Color("a4b39b"))
	draw_line(Vector2(171, 356), Vector2(184, 331), Color("81977f"), 2, true)
	draw_circle(Vector2(810, 133), 43, Color("bba695"))
	draw_circle(Vector2(810, 133), 36, Color("f6e8cd"))
	for index in 12:
		var angle := index * TAU / 12.0
		draw_line(Vector2(810, 133) + Vector2.from_angle(angle) * 28,
			Vector2(810, 133) + Vector2.from_angle(angle) * 31, Color("b6a394"), 2, true)
	draw_line(Vector2(810, 133), Vector2(810, 110), INK, 3, true)
	draw_line(Vector2(810, 133), Vector2(828, 145), INK, 3, true)
	_box(Rect2(776, 425, 157, 130), Color("b49486"), 12)
	_box(Rect2(790, 442, 129, 113), Color("6b5b5e"), 34)
	_box(Rect2(765, 414, 180, 18), Color("c3a497"), 5)
	var glow := Color("e5bd8e")
	for index in 3:
		var sway := sin(_time * 1.1 + index) * 4.0
		_ellipse(Vector2(827 + index * 22, 521 + sway),
			Vector2(14, 22 + index * 3), Color(glow, 0.75))
	draw_line(Vector2(806, 539), Vector2(885, 541), Color("a5816f"), 11, true)
	_plant(Vector2(138, 557))
	var lamp_color := Color("dfb3bd") if lamp_id == "asmr_rose_lamp" else Color("eed2a0")
	_ellipse(Vector2(719, 567), Vector2(34, 8), Color(0.3, 0.25, 0.3, 0.15))
	draw_line(Vector2(719, 555), Vector2(719, 311), Color("978781"), 8, true)
	_ellipse(Vector2(719, 556), Vector2(31, 9), Color("aa9890"))
	_ellipse(Vector2(719, 366), Vector2(76, 110), Color(lamp_color, 0.13))
	draw_colored_polygon(PackedVector2Array([
		Vector2(680, 283), Vector2(758, 283), Vector2(777, 347), Vector2(661, 347),
	]), lamp_color)
	_ellipse(Vector2(719, 347), Vector2(58, 9), lamp_color.darkened(0.09))
	_ellipse(Vector2(719, 283), Vector2(39, 7), lamp_color.lightened(0.1))
	for index in 6:
		var point := Vector2(264 + sin(index * 0.7) * 20, 38 + index * 19)
		draw_line(point, point + Vector2(-4, 23), Color("8fa28d"), 2, true)
		_leaf(point + Vector2(6, 12), 13, 0.7 if index % 2 else -0.7, Color("a1b19a"))


func _plant(base: Vector2) -> void:
	var blooms := plant_id == "asmr_moonflowers"
	for index in 7:
		var tip := base + Vector2((index - 3) * 16.0, -89.0 - sin(index * 1.7) * 23.0)
		draw_line(base + Vector2(0, -24), tip, Color("879f87"), 3, true)
		_leaf(tip + Vector2(0, 11), 24, (index - 3) * 0.25, Color("9bb294"))
		if blooms:
			for petal in 5:
				draw_circle(tip + Vector2.from_angle(petal * TAU / 5.0) * 9.0,
					7.0, Color("dfcde4"))
			draw_circle(tip, 4.5, Color("f5dbad"))
	_box(Rect2(base.x - 31, base.y - 36, 62, 54), Color("c49f8c"), 11)
	_box(Rect2(base.x - 36, base.y - 39, 72, 12), Color("d3b19c"), 5)


func _chair() -> void:
	_ellipse(Vector2(503, 620), Vector2(244, 67),
		Color("afa0bf") if rug_id == "asmr_twilight_rug" else Color("afc0aa"))
	for index in 3:
		_ellipse_outline(Vector2(503, 620), Vector2(226 - index * 13, 54 - index * 5),
			Color(1, 1, 1, 0.22), 2)
	_ellipse(Vector2(510, 609), Vector2(155, 28), Color(0.3, 0.29, 0.32, 0.14))
	for x in [399.0, 611.0]:
		draw_line(Vector2(x, 548), Vector2(x - 9 if x < 500 else x + 9, 614),
			Color("9c7e70"), 14, true)
	_box(Rect2(371, 319, 278, 262), Color("8da9a3"), 94)
	_box(Rect2(389, 332, 242, 217), Color("b1c7bb"), 80)
	for x in [451.0, 566.0]:
		draw_circle(Vector2(x, 393), 5, Color("93ada4"))
	_box(Rect2(378, 505, 265, 73), Color("b7cdbf"), 27)
	_box(Rect2(342, 437, 57, 134), Color("9bb7ad"), 26)
	_box(Rect2(621, 437, 57, 134), Color("9bb7ad"), 26)
	_box(Rect2(348, 439, 45, 32), Color("c3d4c6"), 15)
	_box(Rect2(627, 439, 45, 32), Color("c3d4c6"), 15)


func _patient() -> void:
	var patient: Dictionary = Options.PATIENTS[patient_id]
	var bob := sin(_time * TAU / 6.0) * 2.5
	draw_set_transform(_origin + Vector2(510, 439 + bob) * _unit,
		0.0, Vector2.ONE * _unit)
	var color: Color = patient["color"]
	var coat: Color = patient["coat"]
	var kind := str(patient["kind"])
	var relaxed := stress < 32.0
	var face_y := -92.0
	if kind == "cloud":
		for point: Vector2 in [Vector2(-74, -73), Vector2(-35, -112),
				Vector2(20, -123), Vector2(73, -86)]:
			draw_circle(point, 46, color)
		_ellipse(Vector2(0, -55), Vector2(111, 65), color)
		_ellipse(Vector2(-28, -112), Vector2(32, 12), color.lightened(0.12))
		face_y = -68.0
		for index in 3:
			_ellipse(Vector2(-39 + index * 39, 31 + sin(_time + index) * 4),
				Vector2(7, 11), Color("acb8cc"))
	elif kind == "ghost":
		var silhouette := PackedVector2Array()
		for index in 25:
			var angle := PI + index * PI / 24.0
			silhouette.append(Vector2(cos(angle) * 83, -68 + sin(angle) * 88))
		silhouette.append(Vector2(89, 42))
		for index in 17:
			silhouette.append(Vector2(89 - index * 178.0 / 16.0, 42 + sin(index * PI / 2) * 11))
		draw_colored_polygon(silhouette, Color(color, 0.95))
		_ellipse(Vector2(-24, -98), Vector2(24, 39), Color(1, 1, 1, 0.12))
		face_y = -70.0
	elif kind == "robot":
		_box(Rect2(-74, -13, 148, 100), coat, 26)
		_box(Rect2(-58, -160, 116, 113), color, 24)
		_box(Rect2(-48, -146, 96, 76), Color("647b7b"), 15)
		_box(Rect2(-74, -126, 16, 42), coat, 7)
		_box(Rect2(58, -126, 16, 42), coat, 7)
		draw_line(Vector2(0, -158), Vector2(0, -181), coat, 5, true)
		draw_circle(Vector2(0, -184), 9, Color("e5c595"))
		_box(Rect2(-33, 3, 66, 43), Color("d7ddd0"), 9)
		_leaf(Vector2(0, 23), 13, -0.5, Color("92ac92"))
		face_y = -112.0
	elif kind == "knight":
		_box(Rect2(-78, -13, 156, 100), coat, 35)
		for side in [-1, 1]:
			draw_circle(Vector2(side * 78, 4), 29, color)
		_ellipse(Vector2(0, -89), Vector2(65, 77), color)
		_ellipse(Vector2(-19, -112), Vector2(18, 41), color.lightened(0.16))
		_box(Rect2(-60, -116, 120, 45), Color("697b87"), 16)
		draw_line(Vector2(0, -164), Vector2(12, -195), Color("b99ab2"), 14, true)
		_leaf(Vector2(16, -194), 28, 0.75, Color("c6a9c1"))
		draw_line(Vector2(0, -5), Vector2(0, 71), Color("d6dbe0"), 3, true)
		face_y = -96.0
	elif kind == "dragon":
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(side * 62, 8), Vector2(side * 123, -65),
				Vector2(side * 117, 18), Vector2(side * 80, 56),
			]), coat)
		_ellipse(Vector2(0, 31), Vector2(77, 79), color)
		_ellipse(Vector2(0, 43), Vector2(44, 51), Color("efd5ac"))
		_ellipse(Vector2(0, -88), Vector2(67, 69), color)
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(side * 35, -141), Vector2(side * 47, -180),
				Vector2(side * 60, -128),
			]), Color("f0d7b0"))
		_ellipse(Vector2(0, -63), Vector2(56, 32), color.lightened(0.08))
		for x in [-19.0, 19.0]:
			draw_circle(Vector2(x, -70), 3, coat)
		face_y = -102.0
	else:
		_ellipse(Vector2(0, 25), Vector2(82, 77), coat)
		_box(Rect2(-45, -32, 90, 35), Color("edd4b3"), 14)
		_ellipse(Vector2(0, -104), Vector2(69, 77), Color("62535a"))
		draw_circle(Vector2(-63, -87), 12, color)
		draw_circle(Vector2(63, -87), 12, color)
		_ellipse(Vector2(0, -88), Vector2(57, 61), color)
		_ellipse(Vector2(-19, -145), Vector2(45, 26), Color("62535a"))
		_ellipse(Vector2(43, -132), Vector2(24, 38), Color("62535a"))
		face_y = -91.0
		for x in [-26.0, 26.0]:
			draw_arc(Vector2(x, face_y), 19, 0, TAU, 32, INK, 2.2, true)
		draw_line(Vector2(-7, face_y), Vector2(7, face_y), INK, 2, true)
	if kind not in ["ghost", "cloud"]:
		draw_line(Vector2(-50, 29), Vector2(-22, 57), coat.darkened(0.09), 19, true)
		draw_line(Vector2(50, 29), Vector2(22, 57), coat.darkened(0.09), 19, true)
		_box(Rect2(-69, 70, 138, 24), Color("e6c6b0"), 12)
	var eye_color := Color("e2edd6") if kind in ["robot", "knight"] else INK
	for side in [-1, 1]:
		var eye := Vector2(side * 25, face_y)
		if relaxed:
			draw_arc(eye + Vector2(0, -3), 9, 0.15, PI - 0.15, 16, eye_color, 3, true)
		else:
			_ellipse(eye, Vector2(3.2, 5.2), eye_color)
			if stress > 55:
				draw_line(eye + Vector2(-8, -15 + side * 2),
					eye + Vector2(8, -15 - side * 2), eye_color, 2, true)
		if kind not in ["knight", "robot"]:
			_ellipse(eye + Vector2(side * 11, 18), Vector2(12, 6), Color(0.85, 0.5, 0.5, 0.24))
	var mouth := Vector2(0, face_y + 27)
	if stress < 50:
		draw_arc(mouth - Vector2(0, 5), 10, 0.15, PI - 0.15, 20, eye_color, 2.5, true)
	else:
		draw_line(mouth - Vector2(7, 0), mouth + Vector2(7, 0), eye_color, 2.5, true)
	if stress > 30:
		for side in [-1, 1]:
			for index in 2:
				draw_line(Vector2(side * (102 + index * 8), -130 + index * 23),
					Vector2(side * (114 + index * 8), -136 + index * 23),
					Color(INK, clampf(stress / 130.0, 0.0, 0.6)), 3, true)
	if favorite:
		_star(Vector2(104, -153), 10, Color("f4d79a"))
		_star(Vector2(-111, -63), 6, Color("f4d79a"))


func _foreground() -> void:
	_ellipse(Vector2(235, 614), Vector2(75, 19), Color(0.3, 0.25, 0.3, 0.1))
	draw_line(Vector2(234, 578), Vector2(234, 627), Color("a58b7a"), 9, true)
	_ellipse(Vector2(234, 569), Vector2(74, 22), Color("bd9e87"))
	_ellipse(Vector2(234, 562), Vector2(74, 22), Color("dfc7a6"))
	_ellipse(Vector2(235, 557), Vector2(29, 9), Color("c8b49c"))
	_box(Rect2(216, 524, 39, 29), Color("f7e7c9"), 11)
	draw_arc(Vector2(257, 534), 10, -PI * 0.5, PI * 0.5, 24, Color("f7e7c9"), 4, true)
	_ellipse(Vector2(235, 526), Vector2(17, 5), Color("b78d70"))
	for index in 2:
		var drift := sin(_time * 0.7 + index * 2) * 4
		draw_arc(Vector2(230 + index * 11 + drift, 506 - index * 10),
			10, PI * 0.6, PI * 1.4, 20, Color(1, 0.97, 0.9, 0.46), 2, true)
	_box(Rect2(742, 596, 154, 43), Color("e2c6af"), 9)
	_box(Rect2(747, 600, 144, 30), Color("f6e6cb"), 5)
	draw_line(Vector2(819, 601), Vector2(819, 628), Color("c7b29c"), 2, true)
	_text(Vector2(500, 706), "there is no hurry here", 20, Color("786b6b"))
	if sleeping:
		_text(Vector2(500, 461), "a moment for you", 22, Color("627d74"))
		_text(Vector2(500, 493), "no goals. just quiet.", 15, Color("627d74"))


func _rhythm_ring() -> void:
	var center := Vector2(796, 315)
	var color: Color = Options.TOOLS[tool_id]["color"]
	draw_circle(center, 43, Color("f5e8d7"))
	draw_arc(center, 33, 0, TAU, 64, Color("c4b6b0"), 2, true)
	var radius := 10.0 + rhythm * 23.0
	draw_arc(center, radius, 0, TAU, 48, color.darkened(0.24), 2.8, true)
	draw_circle(center, 4, color.darkened(0.12))
	_text(center + Vector2(0, 66), "slow & steady", 14, Color("7c7178"))


func _tool(point: Vector2) -> void:
	var color: Color = Options.TOOLS[tool_id]["color"]
	match tool_id:
		"brush":
			draw_line(point, point + Vector2(18, 52), Color("ab8e78"), 10, true)
			_leaf(point - Vector2(3, 9), 28, -0.35, color)
			draw_line(point + Vector2(1, 11), point - Vector2(11, 29), color.darkened(0.17), 2, true)
		"tap":
			draw_line(point - Vector2(18, 16), point + Vector2(21, 21), color, 15, true)
			draw_circle(point - Vector2(20, 18), 13, color.lightened(0.1))
		"paper":
			_box(Rect2(point - Vector2(28, 18), Vector2(56, 41)), color, 5)
			draw_line(point + Vector2(0, -15), point + Vector2(0, 19), color.darkened(0.25), 2)
		"snip":
			for side in [-1, 1]:
				draw_arc(point + Vector2(side * 10, 18), 10, 0, TAU, 24, color.darkened(0.2), 4, true)
				draw_line(point + Vector2(side * 5, 9), point + Vector2(-side * 17, -25),
					Color("eef0e6"), 5, true)
		"crinkle":
			draw_colored_polygon(PackedVector2Array([
				point + Vector2(-28, -14), point + Vector2(8, -24), point + Vector2(29, 8),
				point + Vector2(4, 29), point + Vector2(-23, 18),
			]), color)
			draw_line(point + Vector2(-16, -7), point + Vector2(13, 11), color.darkened(0.14), 3, true)
		_:
			for index in 3:
				draw_arc(point, 15 + index * 11, -0.8, 0.8, 32,
					Color(color.darkened(0.1), 0.8 - index * 0.2), 3, true)


func _reset_transform() -> void:
	draw_set_transform(_origin, 0.0, Vector2.ONE * _unit)


func _box(rect: Rect2, color: Color, radius: int) -> void:
	var key := color.to_html() + str(radius)
	if not _boxes.has(key):
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(radius)
		_boxes[key] = box
	draw_style_box(_boxes[key], rect)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 48:
		points.append(center + Vector2.from_angle(index * TAU / 48.0) * radii)
	draw_colored_polygon(points, color)


func _ellipse_outline(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 49:
		points.append(center + Vector2.from_angle(index * TAU / 48.0) * radii)
	draw_polyline(points, color, width, true)


func _leaf(center: Vector2, radius: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 32:
		var unit := Vector2.from_angle(index * TAU / 32.0) * Vector2(radius * 0.48, radius)
		points.append(center + unit.rotated(angle))
	draw_colored_polygon(points, color)


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 8:
		points.append(center + Vector2.from_angle(index * TAU / 8.0)
			* (radius if index % 2 == 0 else radius * 0.3))
	draw_colored_polygon(points, color)


func _text(center: Vector2, text: String, pixels: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string(font, center - Vector2(width * 0.5, 0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

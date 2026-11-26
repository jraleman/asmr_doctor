extends RefCounted

## Original low-poly clinic, patients and doctor-held tools; no imported assets.

const Options := preload("res://games/asmr_doctor/asmr_doctor_options.gd")
const INK := Color("555366")
const WOOD := Color("b6947b")
const SKIN := Color("ddb295")
const SLEEVE := Color("b7cbc0")
const TOOL_POSITION := Vector3(0.32, -0.34, -0.72)

var patient: Node3D
var _environment: Environment
var _walls: Array[MeshInstance3D] = []
var _sky: Array[MeshInstance3D] = []
var _sun: DirectionalLight3D
var _moon: MeshInstance3D
var _plant: Node3D
var _lamp_shade: MeshInstance3D
var _lamp_light: OmniLight3D
var _rug: MeshInstance3D
var _flames: Array[MeshInstance3D] = []
var _tool: Node3D
var _whisper_rings: Array[MeshInstance3D] = []
var _blades: Array[Node3D] = []
var _open_eyes: Node3D
var _closed_eyes: Node3D
var _straight_mouth: Node3D
var _smile: Node3D
var _favorite: Node3D
var _plant_id := ""
var _lamp_id := ""
var _rug_id := ""
var _materials: Dictionary[String, StandardMaterial3D] = {}


func build(room: Node3D, camera: Camera3D) -> void:
	var world := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment = _environment
	room.add_child(world)
	_box(room, Vector3(0, -0.08, -0.8), Vector3(6, 0.16, 6), Color("d3b49b"))
	for index in 15:
		_box(room, Vector3(0, 0.006, -3.6 + index * 0.4), Vector3(6, 0.008, 0.012), Color("bd9e89"))
	for side in [-1, 1]:
		_walls.append(
			_box(room, Vector3(side * 3.0, 1.75, -0.8), Vector3(0.12, 3.5, 6), Color("f4e8d7"))
		)
	_walls.append(_box(room, Vector3(0, 1.75, -3.8), Vector3(6, 3.5, 0.12), Color("f4e8d7")))
	_box(room, Vector3(0, 3.5, -0.8), Vector3(6, 0.12, 6), Color("e6d3bd"))
	_box(room, Vector3(0, 0.12, -3.69), Vector3(6, 0.16, 0.08), WOOD)
	_build_window(room)
	_build_shelves(room)
	_build_fireplace(room)
	_build_lamp(room)
	_build_chair(room)
	_plant = Node3D.new()
	_plant.name = "Plant"
	_plant.position = Vector3(-1.25, 0, -1.6)
	room.add_child(_plant)
	patient = Node3D.new()
	patient.name = "Patient"
	patient.position.z = -1.3
	room.add_child(patient)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-35, -25, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 12.0
	room.add_child(_sun)
	_tool = Node3D.new()
	_tool.name = "HeldTool"
	_tool.position = TOOL_POSITION
	camera.add_child(_tool)
	var left_hand := Node3D.new()
	left_hand.position = Vector3(-0.35, -0.39, -0.72)
	left_hand.rotation.z = -0.25
	camera.add_child(left_hand)
	_hand(left_hand)
	set_equipment("asmr_fern", "asmr_honey_lamp", "asmr_sage_rug")
	set_night(false)


func set_night(night: bool) -> void:
	var wall_color := Color("bdb2ca") if night else Color("f4e8d7")
	for wall in _walls:
		wall.material_override = _material(wall_color)
	for sky in _sky:
		sky.material_override = _material(Color("667891") if night else Color("c4dccb"), 0.3)
	_moon.visible = night
	_environment.background_color = wall_color
	_environment.ambient_light_color = Color("b4b9d3") if night else Color("f4e5ce")
	_environment.ambient_light_energy = 0.45 if night else 0.62
	_sun.light_color = Color("adb8de") if night else Color("fff0d3")
	_sun.light_energy = 0.25 if night else 0.45
	_lamp_light.light_energy = 0.55 if night else 0.22


func set_equipment(plant: String, lamp: String, rug: String) -> void:
	if _plant_id != plant:
		_plant_id = plant
		_clear(_plant)
		_build_plant(plant == "asmr_moonflowers")
	if _lamp_id != lamp:
		_lamp_id = lamp
		_lamp_shade.material_override = _material(
			Color("dfb3bd") if lamp == "asmr_rose_lamp" else Color("eed2a0")
		)
	if _rug_id != rug:
		_rug_id = rug
		_rug.material_override = _material(
			Color("afa0bf") if rug == "asmr_twilight_rug" else Color("afc0aa")
		)


func set_patient(id: String) -> void:
	_clear(patient)
	var data: Dictionary = Options.PATIENTS[id]
	var color: Color = data["color"]
	var coat: Color = data["coat"]
	var kind := str(data["kind"])
	var face := Vector3(0, 1.48, 0.28)
	if kind not in ["cloud", "ghost"]:
		_ellipsoid(patient, Vector3(0, 0.95, 0), Vector3(0.32, 0.34, 0.23), coat)
		for side in [-1, 1]:
			_segment(
				patient,
				Vector3(side * 0.29, 1.08, 0.02),
				Vector3(side * 0.16, 0.77, 0.29),
				0.08,
				coat
			)
			_ellipsoid(
				patient, Vector3(side * 0.15, 0.77, 0.28), Vector3(0.085, 0.05, 0.075), color
			)
			_segment(
				patient,
				Vector3(side * 0.16, 0.72, 0),
				Vector3(side * 0.18, 0.31, 0.31),
				0.09,
				coat.darkened(0.15)
			)
			_ellipsoid(patient, Vector3(side * 0.18, 0.28, 0.36), Vector3(0.12, 0.07, 0.17), INK)
	match kind:
		"human":
			_ellipsoid(patient, Vector3(0, 1.49, 0), Vector3(0.32, 0.35, 0.27), Color("62535a"))
			_ellipsoid(patient, Vector3(0, 1.45, 0.13), Vector3(0.26, 0.28, 0.18), color)
			for point: Vector3 in [
				Vector3(-0.15, 1.71, 0.22), Vector3(0.16, 1.73, 0.18), Vector3(0.26, 1.55, 0.12)
			]:
				_ellipsoid(patient, point, Vector3(0.15, 0.12, 0.1), Color("62535a"))
			_ellipsoid(patient, Vector3(0, 1.22, 0.1), Vector3(0.2, 0.055, 0.19), Color("edd4b3"))
			face = Vector3(0, 1.47, 0.31)
			for side in [-1, 1]:
				_ring(patient, face + Vector3(side * 0.105, 0, 0.01), 0.056, 0.065, INK)
			_segment(
				patient, face + Vector3(-0.04, 0, 0.02), face + Vector3(0.04, 0, 0.02), 0.008, INK
			)
		"knight":
			_ellipsoid(patient, Vector3(0, 1.49, 0), Vector3(0.3, 0.34, 0.26), color)
			_box(patient, Vector3(0, 1.48, 0.24), Vector3(0.48, 0.16, 0.06), Color("697b87"))
			_segment(patient, Vector3(0, 1.8, 0), Vector3(0.07, 1.95, 0), 0.035, Color("b99ab2"))
			var plume := _ellipsoid(
				patient, Vector3(0.13, 1.97, 0), Vector3(0.09, 0.17, 0.04), Color("c6a9c1")
			)
			plume.rotation.z = -0.65
			for side in [-1, 1]:
				_ellipsoid(patient, Vector3(side * 0.32, 1.09, 0), Vector3(0.13, 0.1, 0.15), color)
		"cloud":
			for point: Vector3 in [
				Vector3(-0.29, 1.38, 0),
				Vector3(-0.13, 1.56, 0),
				Vector3(0.14, 1.59, 0),
				Vector3(0.3, 1.39, 0)
			]:
				_ellipsoid(patient, point, Vector3(0.21, 0.21, 0.2), color)
			_ellipsoid(patient, Vector3(0, 1.29, 0), Vector3(0.46, 0.25, 0.24), color)
			for index in 3:
				_ellipsoid(
					patient,
					Vector3(-0.18 + index * 0.18, 0.83, 0.02),
					Vector3(0.025, 0.06, 0.025),
					Color("acb8cc")
				)
			face = Vector3(0, 1.31, 0.25)
		"dragon":
			_ellipsoid(patient, Vector3(0, 0.96, 0.22), Vector3(0.21, 0.26, 0.055), Color("efd5ac"))
			_ellipsoid(patient, Vector3(0, 1.48, 0), Vector3(0.3, 0.29, 0.25), color)
			_ellipsoid(
				patient, Vector3(0, 1.36, 0.23), Vector3(0.24, 0.12, 0.12), color.lightened(0.08)
			)
			for side in [-1, 1]:
				_cylinder(patient, Vector3(side * 0.17, 1.81, 0), 0.065, 0.24, Color("f0d7b0"), 0.0)
				_polygon(
					patient,
					PackedVector3Array(
						[
							Vector3(side * 0.25, 1.12, -0.07),
							Vector3(side * 0.58, 1.42, -0.13),
							Vector3(side * 0.53, 0.94, -0.08),
							Vector3(side * 0.32, 0.8, 0),
						]
					),
					coat
				)
				_ellipsoid(
					patient, Vector3(side * 0.09, 1.4, 0.345), Vector3(0.014, 0.012, 0.012), coat
				)
			face = Vector3(0, 1.54, 0.25)
		"ghost":
			color.a = 0.94
			_ellipsoid(patient, Vector3(0, 1.43, 0), Vector3(0.3, 0.35, 0.24), color)
			_cylinder(patient, Vector3(0, 1.05, 0), 0.34, 0.62, color, 0.25)
			for index in 5:
				_ellipsoid(
					patient,
					Vector3(-0.27 + index * 0.135, 0.76, 0.08),
					Vector3(0.085, 0.095, 0.2),
					color
				)
			face = Vector3(0, 1.43, 0.255)
		"robot":
			_box(patient, Vector3(0, 1.49, 0), Vector3(0.52, 0.47, 0.36), color)
			_box(patient, Vector3(0, 1.49, 0.19), Vector3(0.44, 0.32, 0.045), Color("647b7b"))
			for side in [-1, 1]:
				_ellipsoid(patient, Vector3(side * 0.29, 1.49, 0), Vector3(0.055, 0.09, 0.08), coat)
			_segment(patient, Vector3(0, 1.74, 0), Vector3(0, 1.87, 0), 0.016, coat)
			_ellipsoid(patient, Vector3(0, 1.9, 0), Vector3.ONE * 0.045, Color("e5c595"))
			_box(patient, Vector3(0, 1.01, 0.235), Vector3(0.26, 0.17, 0.03), Color("d7ddd0"))
			face = Vector3(0, 1.5, 0.22)
	_build_face(face, Color("e2edd6") if kind in ["robot", "knight"] else INK)


func set_expression(stress: float, favorite: bool) -> void:
	_open_eyes.visible = stress >= 32.0
	_closed_eyes.visible = stress < 32.0
	_straight_mouth.visible = stress >= 50.0
	_smile.visible = stress < 50.0
	_favorite.visible = favorite


func set_tool(id: String) -> void:
	_clear(_tool)
	_whisper_rings.clear()
	_blades.clear()
	_hand(_tool)
	var color: Color = Options.TOOLS[id]["color"]
	match id:
		"brush":
			_segment(_tool, Vector3(0, 0.03, -0.025), Vector3(0, 0.29, -0.025), 0.012, WOOD)
			var feather := _ellipsoid(
				_tool, Vector3(0, 0.32, -0.025), Vector3(0.065, 0.14, 0.022), color
			)
			feather.rotation.z = 0.25
			_segment(
				_tool, Vector3(0.03, 0.21, 0), Vector3(-0.03, 0.43, 0), 0.004, color.darkened(0.2)
			)
		"tap":
			_segment(
				_tool, Vector3(-0.035, 0.06, -0.025), Vector3(0.09, 0.25, -0.025), 0.032, color
			)
			_box(_tool, Vector3(-0.24, 0.09, -0.02), Vector3(0.24, 0.1, 0.16), WOOD)
		"paper":
			var book := Node3D.new()
			book.position = Vector3(-0.19, 0.16, -0.07)
			book.rotation.x = 0.65
			_tool.add_child(book)
			_box(book, Vector3(0, -0.016, 0), Vector3(0.46, 0.025, 0.3), WOOD)
			for side in [-1, 1]:
				_box(book, Vector3(side * 0.115, 0.006, 0), Vector3(0.22, 0.02, 0.28), color)
				for line in 5:
					_segment(
						book,
						Vector3(side * 0.115 - 0.075, 0.018, -0.09 + line * 0.035),
						Vector3(side * 0.115 + 0.075, 0.018, -0.09 + line * 0.035),
						0.002,
						color.darkened(0.22)
					)
		"crinkle":
			for row in 2:
				for column in 3:
					var x := -0.36 + column * 0.13
					var y := 0.1 + row * 0.1
					var z := -0.05 + (column % 2) * 0.04
					_polygon(
						_tool,
						PackedVector3Array(
							[
								Vector3(x, y, z),
								Vector3(x + 0.13, y, -0.01 - z),
								Vector3(x + 0.13, y + 0.1, -0.01 - z),
								Vector3(x, y + 0.1, z),
							]
						),
						color.lightened(column * 0.045)
					)
		"snip":
			for side in [-1, 1]:
				_ring(_tool, Vector3(side * 0.038, 0.06, -0.03), 0.026, 0.035, color)
				var blade := Node3D.new()
				blade.position = Vector3(0, 0.13, -0.03)
				_tool.add_child(blade)
				_segment(blade, Vector3.ZERO, Vector3(side * 0.06, 0.17, 0), 0.009, Color("eef0e6"))
				_blades.append(blade)
			_ellipsoid(_tool, Vector3(0, 0.13, -0.025), Vector3.ONE * 0.015, color.darkened(0.2))
		"whisper":
			for index in 3:
				var radius := 0.05 + index * 0.035
				var ring := _ring(
					_tool,
					Vector3(-0.04, 0.2, -0.04),
					radius,
					radius + 0.004,
					Color(color, 0.6 - index * 0.15)
				)
				ring.visible = false
				_whisper_rings.append(ring)


func animate(time: float, caring: bool, pointer: Vector2, moving := true) -> void:
	patient.position.y = sin(time * TAU / 6.0) * 0.012
	_tool.position = TOOL_POSITION + Vector3(pointer.x * 0.06, -pointer.y * 0.04, 0)
	_tool.rotation.z = sin(time * 2.0) * 0.06 if caring and moving else 0.0
	_tool.position.y += sin(time * 2.0) * 0.025 if caring and moving else 0.0
	for index in _flames.size():
		_flames[index].scale.y = (0.18 + index * 0.025) * (1.0 + sin(time * 1.3 + index) * 0.08)
	for ring in _whisper_rings:
		ring.visible = caring
		ring.scale = Vector3.ONE * (1.0 + sin(time) * 0.08)
	for index in _blades.size():
		_blades[index].rotation.z = (
			(1 if index == 0 else -1) * (sin(time * 2.0) * 0.12 if caring and moving else 0.0)
		)


func _build_window(room: Node3D) -> void:
	_box(room, Vector3(0, 1.94, -3.66), Vector3(1.72, 1.62, 0.12), WOOD)
	_ellipsoid(room, Vector3(0, 2.68, -3.66), Vector3(0.86, 0.62, 0.07), WOOD)
	_sky.append(_box(room, Vector3(0, 1.97, -3.57), Vector3(1.54, 1.48, 0.06), Color("c4dccb")))
	_sky.append(
		_ellipsoid(room, Vector3(0, 2.67, -3.57), Vector3(0.77, 0.52, 0.04), Color("c4dccb"))
	)
	_moon = _ellipsoid(
		room, Vector3(0.36, 2.65, -3.51), Vector3(0.16, 0.16, 0.015), Color("f7e9c2"), 0.5
	)
	_box(room, Vector3(0, 2.1, -3.49), Vector3(0.045, 1.98, 0.07), Color("e9d8bd"))
	_box(room, Vector3(0, 1.94, -3.49), Vector3(1.56, 0.045, 0.07), Color("e9d8bd"))
	_box(room, Vector3(0, 1.13, -3.48), Vector3(1.92, 0.09, 0.28), WOOD)
	for side in [-1, 1]:
		for fold in 3:
			_cylinder(
				room,
				Vector3(side * (0.91 + fold * 0.09), 2.06, -3.43),
				0.08,
				1.78,
				Color("dfc1b6").darkened(fold * 0.03)
			)
	_label(room, Vector3(0, 3.33, -3.42), "THE LITTLE CLINIC OF CALM", 0.0015, INK)


func _build_shelves(room: Node3D) -> void:
	for shelf in 2:
		var y := 1.25 + shelf * 0.63
		_box(room, Vector3(-2.0, y, -3.45), Vector3(1.25, 0.07, 0.38), WOOD)
		for book in 6:
			var colors := [Color("c4b8cc"), Color("a8bdb0"), Color("d5b9a2")]
			var height := 0.27 + (book % 3) * 0.06
			_box(
				room,
				Vector3(-2.48 + book * 0.18, y + height * 0.5 + 0.04, -3.4),
				Vector3(0.12, height, 0.22),
				colors[(book + shelf) % 3]
			)
	_label(room, Vector3(-2.0, 2.53, -3.66), "a little care\na little quieter", 0.0022, INK)
	_cylinder(room, Vector3(-1.47, 0.47, -0.72), 0.03, 0.9, WOOD)
	_cylinder(room, Vector3(-1.47, 0.92, -0.72), 0.32, 0.055, Color("dfc7a6"))
	_cylinder(room, Vector3(-1.47, 1.02, -0.72), 0.065, 0.15, Color("f7e7c9"))


func _build_fireplace(room: Node3D) -> void:
	_box(room, Vector3(1.96, 0.55, -3.4), Vector3(1.16, 1.1, 0.5), Color("b49486"))
	_box(room, Vector3(1.96, 0.5, -3.125), Vector3(0.85, 0.78, 0.035), Color("56484e"))
	_box(room, Vector3(1.96, 1.12, -3.35), Vector3(1.34, 0.1, 0.64), WOOD)
	for index in 3:
		_segment(
			room,
			Vector3(1.67, 0.22 + index * 0.04, -2.98),
			Vector3(2.22, 0.24 + index * 0.04, -3.07),
			0.055,
			Color("8b6b58")
		)
		_flames.append(
			_ellipsoid(
				room,
				Vector3(1.73 + index * 0.22, 0.45, -3.0),
				Vector3(0.085, 0.18 + index * 0.025, 0.075),
				Color("e5bd8e"),
				0.5
			)
		)
	var light := OmniLight3D.new()
	light.position = Vector3(1.96, 0.67, -2.8)
	light.light_color = Color("efbb87")
	light.light_energy = 0.28
	light.omni_range = 3.0
	room.add_child(light)
	_label(room, Vector3(1.98, 2.29, -3.65), "there is no hurry here", 0.0018, INK)


func _build_lamp(room: Node3D) -> void:
	_cylinder(room, Vector3(1.14, 0.04, -1.83), 0.2, 0.055, Color("aa9890"))
	_cylinder(room, Vector3(1.14, 0.85, -1.83), 0.025, 1.65, Color("978781"))
	_lamp_shade = _cylinder(room, Vector3(1.14, 1.66, -1.83), 0.31, 0.3, Color("eed2a0"), 0.21)
	_ellipsoid(room, Vector3(1.14, 1.48, -1.83), Vector3.ONE * 0.07, Color("ffe8b8"), 0.7)
	_lamp_light = OmniLight3D.new()
	_lamp_light.position = Vector3(1.14, 1.45, -1.83)
	_lamp_light.light_color = Color("ffe2ae")
	_lamp_light.omni_range = 3.5
	room.add_child(_lamp_light)


func _build_chair(room: Node3D) -> void:
	_rug = _cylinder(room, Vector3(0, 0.016, -1.25), 1.21, 0.018, Color("afc0aa"))
	_rug.scale.z = 0.72
	for side in [-1, 1]:
		_segment(
			room, Vector3(side * 0.37, 0.08, -1.5), Vector3(side * 0.34, 0.64, -1.55), 0.045, WOOD
		)
		_segment(
			room, Vector3(side * 0.37, 0.08, -0.95), Vector3(side * 0.34, 0.64, -1.05), 0.045, WOOD
		)
		_ellipsoid(
			room, Vector3(side * 0.43, 0.8, -1.23), Vector3(0.11, 0.13, 0.43), Color("9bb7ad")
		)
	_ellipsoid(room, Vector3(0, 0.62, -1.28), Vector3(0.46, 0.14, 0.44), Color("b7cdbf"))
	_ellipsoid(room, Vector3(0, 1.08, -1.62), Vector3(0.47, 0.57, 0.12), Color("8da9a3"))
	_ellipsoid(room, Vector3(0, 1.12, -1.51), Vector3(0.39, 0.45, 0.07), Color("b1c7bb"))


func _build_plant(blooms: bool) -> void:
	_cylinder(_plant, Vector3(0, 0.19, 0), 0.17, 0.34, Color("c49f8c"), 0.21)
	_cylinder(_plant, Vector3(0, 0.37, 0), 0.215, 0.055, Color("d3b19c"))
	for index in 7:
		var angle := index * TAU / 7.0
		var tip := Vector3(cos(angle) * 0.23, 0.83 + sin(index * 1.7) * 0.12, sin(angle) * 0.18)
		_segment(_plant, Vector3(0, 0.38, 0), tip, 0.012, Color("879f87"))
		var leaf := _ellipsoid(
			_plant, tip - Vector3(0, 0.08, 0), Vector3(0.065, 0.17, 0.025), Color("9bb294")
		)
		leaf.rotation = Vector3(0.25, angle, (index - 3) * 0.2)
		if blooms:
			for petal in 5:
				var offset := Vector3(cos(petal * TAU / 5.0), sin(petal * TAU / 5.0), 0)
				_ellipsoid(_plant, tip + offset * 0.055, Vector3.ONE * 0.04, Color("dfcde4"))
			_ellipsoid(_plant, tip + Vector3(0, 0, 0.03), Vector3.ONE * 0.022, Color("f5dbad"))


func _build_face(center: Vector3, color: Color) -> void:
	_open_eyes = _group(patient)
	_closed_eyes = _group(patient)
	_straight_mouth = _group(patient)
	_smile = _group(patient)
	_favorite = _group(patient)
	for side in [-1, 1]:
		var eye := center + Vector3(side * 0.105, 0, 0)
		_ellipsoid(_open_eyes, eye, Vector3(0.014, 0.026, 0.012), color)
		_arc(_closed_eyes, eye + Vector3(0, 0.008, 0), 0.034, color)
	_segment(
		_straight_mouth,
		center + Vector3(-0.035, -0.1, 0),
		center + Vector3(0.035, -0.1, 0),
		0.008,
		color
	)
	_arc(_smile, center + Vector3(0, -0.075, 0), 0.042, color)
	for side in [-1, 1]:
		var star := PackedVector3Array()
		for point in 10:
			var angle := point * TAU / 10.0 + PI * 0.5
			var radius := 0.055 if point % 2 == 0 else 0.025
			star.append(Vector3(side * 0.42 + cos(angle) * radius, 1.83 + sin(angle) * radius, 0.1))
		_polygon(_favorite, star, Color("f4d79a"))
	set_expression(80.0, false)


func _hand(parent: Node3D) -> void:
	_segment(parent, Vector3(0.11, -0.3, 0.12), Vector3(0.01, -0.075, 0.01), 0.067, SLEEVE)
	_ellipsoid(
		parent, Vector3(0, -0.055, 0.01), Vector3(0.068, 0.035, 0.05), SLEEVE.lightened(0.12)
	)
	_ellipsoid(parent, Vector3(0, 0.01, 0), Vector3(0.059, 0.078, 0.04), SKIN)
	for index in 3:
		_segment(
			parent,
			Vector3(-0.026 + index * 0.025, 0.035, 0.012),
			Vector3(-0.026 + index * 0.025, 0.078, 0.02),
			0.016,
			SKIN
		)
	_ellipsoid(parent, Vector3(-0.053, 0.005, 0.02), Vector3(0.025, 0.047, 0.025), SKIN)


func _group(parent: Node3D) -> Node3D:
	var group := Node3D.new()
	parent.add_child(group)
	return group


func _clear(parent: Node3D) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var key := color.to_html() + str(glow)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		material.metallic_specular = 0.25
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glow > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = glow
		_materials[key] = material
	return _materials[key]


func _mesh(
	parent: Node3D, mesh: Mesh, position: Vector3, color: Color, glow := 0.0
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color, glow)
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, position: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, mesh, position, color)


func _ellipsoid(
	parent: Node3D, position: Vector3, radii: Vector3, color: Color, glow := 0.0
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var instance := _mesh(parent, mesh, position, color, glow)
	instance.scale = radii
	return instance


func _cylinder(
	parent: Node3D,
	position: Vector3,
	radius: float,
	height: float,
	color: Color,
	top_radius := -1.0
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 24
	return _mesh(parent, mesh, position, color)


func _segment(
	parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color
) -> MeshInstance3D:
	var instance := _cylinder(parent, (start + end) * 0.5, radius, start.distance_to(end), color)
	instance.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return instance


func _ring(
	parent: Node3D, center: Vector3, inner: float, outer: float, color: Color
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	var instance := _mesh(parent, mesh, center, color)
	instance.rotation.x = PI * 0.5
	return instance


func _arc(parent: Node3D, center: Vector3, radius: float, color: Color) -> void:
	for index in 8:
		var start := 0.15 + index * (PI - 0.3) / 8.0
		var end := 0.15 + (index + 1) * (PI - 0.3) / 8.0
		_segment(
			parent,
			center + Vector3(cos(start), -sin(start), 0) * radius,
			center + Vector3(cos(end), -sin(end), 0) * radius,
			0.007,
			color
		)


func _polygon(parent: Node3D, points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var outline := PackedVector2Array()
	for point in points:
		outline.append(Vector2(point.x, point.y))
	var indices := Geometry2D.triangulate_polygon(outline)
	assert(not indices.is_empty(), "Clinic polygons must have a non-degenerate outline.")
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in range(0, indices.size(), 3):
		var a := points[indices[index]]
		var b := points[indices[index + 1]]
		var c := points[indices[index + 2]]
		var normal := (b - a).cross(c - a).normalized()
		(
			vertices
			. append_array(
				PackedVector3Array(
					[
						a,
						b,
						c,
						a,
						c,
						b,
					]
				)
			)
		)
		normals.append_array(
			PackedVector3Array([normal, normal, normal, -normal, -normal, -normal])
		)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh(parent, mesh, Vector3.ZERO, color)


func _label(
	parent: Node3D, position: Vector3, text: String, pixel_size: float, color: Color
) -> void:
	var label := Label3D.new()
	label.position = position
	label.text = text
	label.font_size = 48
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)

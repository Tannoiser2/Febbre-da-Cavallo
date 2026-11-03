class_name Cavallo3D
extends Node3D
## Un cavallo sulla pista: miniatura animata dallo shader, basetta del suo colore e nome sopra.

const SCALA := 0.8

var id := 0
var mat: ShaderMaterial
var etichetta: Label3D
var stato_etichetta: Label3D
var anello: MeshInstance3D
var modello: Node3D
var _galoppo := 0.0
var _galoppo_obj := 0.0
var _testa := 0.0
var _testa_obj := 0.0

func prepara(i: int, mesh: Mesh, font: Font) -> void:
	id = i
	name = "Cavallo%d" % i
	var col := Dati.colore(i)
	modello = Node3D.new()
	add_child(modello)
	# basetta
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.05
	cil.bottom_radius = 1.12
	cil.height = 0.22
	cil.radial_segments = 28
	base.mesh = cil
	var mb := StandardMaterial3D.new()
	mb.albedo_color = col.darkened(0.15)
	mb.roughness = 0.4
	base.material_override = mb
	base.position.y = 0.11
	modello.add_child(base)
	# cavallo
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/cavallo.gdshader")
	var cc := col
	if i == 7:
		cc = Color("#3a3330")
	mat.set_shader_parameter("colore", cc.lerp(Color("#7a4a2a"), 0.18))
	mat.set_shader_parameter("fase", i * 1.7)
	mi.material_override = mat
	mi.scale = Vector3.ONE * SCALA
	mi.position.y = 0.22
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	modello.add_child(mi)
	# anello che lampeggia quando il cavallo si può scegliere
	anello = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.2
	tor.outer_radius = 1.45
	anello.mesh = tor
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color("#fff36b")
	ma.emission_enabled = true
	ma.emission = Color("#ffe14d")
	ma.emission_energy_multiplier = 1.6
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	anello.material_override = ma
	anello.position.y = 0.15
	anello.visible = false
	add_child(anello)
	# nome
	etichetta = Label3D.new()
	etichetta.text = Dati.nome(i).to_upper()
	etichetta.font = font
	etichetta.font_size = 72
	etichetta.pixel_size = 0.014
	etichetta.outline_size = 18
	etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etichetta.no_depth_test = true
	etichetta.fixed_size = false
	etichetta.modulate = col.lightened(0.15) if i != 7 else Color("#f0f0f0")
	etichetta.outline_modulate = Color(0.05, 0.05, 0.05, 0.95)
	etichetta.position.y = 4.2
	etichetta.render_priority = 2
	etichetta.outline_render_priority = 1
	add_child(etichetta)
	stato_etichetta = Label3D.new()
	stato_etichetta.font = font
	stato_etichetta.font_size = 44
	stato_etichetta.pixel_size = 0.014
	stato_etichetta.outline_size = 12
	stato_etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stato_etichetta.no_depth_test = true
	stato_etichetta.modulate = Color("#ff5a4a")
	stato_etichetta.outline_modulate = Color(0, 0, 0, 0.9)
	stato_etichetta.position.y = 5.1
	stato_etichetta.render_priority = 2
	add_child(stato_etichetta)

func imposta(attivo: bool, zoppo: bool) -> void:
	_testa_obj = 0.0 if attivo else 1.0
	mat.set_shader_parameter("spento", 0.0 if attivo else 1.0)
	stato_etichetta.text = "AZZOPPATO" if zoppo else ""

func galoppa(si: bool) -> void:
	_galoppo_obj = 1.0 if si else 0.0

func evidenzia(si: bool) -> void:
	anello.visible = si
	mat.set_shader_parameter("evidenzia", 1.0 if si else 0.0)

func _process(delta: float) -> void:
	_galoppo = move_toward(_galoppo, _galoppo_obj, delta * 4.0)
	_testa = move_toward(_testa, _testa_obj, delta * 2.0)
	mat.set_shader_parameter("galoppo", _galoppo)
	mat.set_shader_parameter("testa", _testa)
	if anello.visible:
		anello.rotation.y += delta * 2.0
		var s := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
		anello.scale = Vector3(s, 1, s)

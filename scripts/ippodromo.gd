class_name Ippodromo
extends Node3D
## Il mondo 3D: prato, pista ovale a caselle, steccato con le lucine di Natale, tribuna,
## arco d'arrivo, cavalli, token e telecamera che segue l'azione.

const GIALLO_A := Color("#f3cf5a")
const GIALLO_B := Color("#ebc248")
const VERDE_PISTA := Color("#1d7a4a")
const VEL := 8.5

var pista: Pista
var font: Font
var cavalli := []            # Cavallo3D
var token_nodi := {}         # cella -> Node3D
var _bande: MeshInstance3D = null   # le colonne coperte dai token
var marcatori := []
var cam: Camera3D
var _cam_target := Vector3.ZERO
var _cam_dist := 60.0
var _cam_target_obj := Vector3.ZERO
var _cam_dist_obj := 60.0
var _segui: Node3D = null
var _sfondo: Node3D
var _mondo_pista: Node3D
var tex_token := {}
var _mesh_cavallo: Mesh
var _zoppi := {}
var _in_moto := {}
var zoom_segui := 0.4
var zoom_extra := 1.0
var aree_libere := []   # rettangoli dello schermo (pixel) liberi dall'interfaccia: la pista si allarga nel migliore
var spostamento_ui := Vector2(0.0, 0.0)   # quanto spostare la vista per lasciare spazio all'interfaccia

func _ready() -> void:
	font = load("res://assets/font/Bangers-Regular.ttf")
	for t in Dati.TOKEN:
		tex_token[t] = load("res://assets/token/%s.png" % t)
	var sc: PackedScene = load("res://assets/modelli/cavallo.glb")
	var n := sc.instantiate()
	_mesh_cavallo = _trova_mesh(n)
	n.free()
	_ambiente()
	_sfondo = Node3D.new()
	add_child(_sfondo)
	_prato()
	cam = Camera3D.new()
	cam.fov = 36.0
	cam.near = 0.5
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	for i in 8:
		var c := Cavallo3D.new()
		add_child(c)
		c.prepara(i, _mesh_cavallo, font)
		cavalli.append(c)
	costruisci(Pista.new(4))

func _trova_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return n.mesh
	for c in n.get_children():
		var m := _trova_mesh(c)
		if m:
			return m
	return null

# ------------------------------------------------------------------ ambiente
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#4a86c8")
	sm.sky_horizon_color = Color("#bcd6ea")
	sm.ground_horizon_color = Color("#9fb98a")
	sm.ground_bottom_color = Color("#3d6b35")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9d3e0")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	we.environment = env
	add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-58, -30, 0)
	sole.light_energy = 1.0
	sole.shadow_enabled = true
	sole.shadow_bias = 0.3
	sole.shadow_normal_bias = 3.0
	sole.directional_shadow_max_distance = 220.0
	sole.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sole)

func _mat(col: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

func _prato() -> void:
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	p.mesh = pm
	var m := _mat(Color("#4f8f3a"))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var g := Gradient.new()
	g.set_color(0, Color("#3f7a2e"))
	g.set_color(1, Color("#4e8c37"))
	nt.color_ramp = g
	m.albedo_texture = nt
	m.uv1_scale = Vector3(30, 30, 1)
	p.material_override = m
	p.position.y = -0.05
	_sfondo.add_child(p)

# ------------------------------------------------------------------ pista
func costruisci(p: Pista) -> void:
	pista = p
	if _mondo_pista:
		_mondo_pista.queue_free()
	for k in token_nodi:
		token_nodi[k].queue_free()
	token_nodi = {}
	_mondo_pista = Node3D.new()
	add_child(_mondo_pista)
	var r_in := Pista.R0 - Pista.BORDO
	var r_out := Pista.R0 + Pista.CORSIE * Pista.LARG_CORSIA + Pista.BORDO
	# fascia verde sotto le caselle (i bordi stampati)
	_striscia(r_in - 0.05, r_out + 0.05, 0.0, VERDE_PISTA, 0.012)
	# caselle
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in pista.celle:
		var col := GIALLO_A if (c["id"] % 2 == 0) else GIALLO_B
		if c["tipo"] == "c":
			col = col.lerp(Color("#f6d978"), 0.35)
		st.set_color(col)
		_poligono_inset(st, c, 0.07, 0.03)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mc := _mat(Color.WHITE, 0.9)
	mc.vertex_color_use_as_albedo = true
	mc.vertex_color_is_srgb = true
	mc.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mc
	_mondo_pista.add_child(mi)
	# prato interno un po' più chiaro
	_striscia(0.0, r_in - 0.05, 0.0, Color("#5a9a40"), 0.005)
	_linea_arrivo(r_in, r_out)
	_steccato(r_out + 0.5, true)
	_steccato(r_in - 0.45, false)
	_tribuna(r_out)
	_alberi(r_in, r_out)
	_inquadra_tutto(true)
	for c in cavalli:
		c.position = pos_partenza(c.id)
		c.basis = _base_dir(Vector2(1, 0))

## Fascia della pista tra due raggi (segue tutto l'ovale)
func _striscia(r0: float, r1: float, _s0: float, col: Color, y: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 360
	for i in n:
		var sa := pista.lunghezza * i / n
		var sb := pista.lunghezza * (i + 1) / n
		var a0 := pista.punto(sa, r0)
		var a1 := pista.punto(sa, r1)
		var b0 := pista.punto(sb, r0)
		var b1 := pista.punto(sb, r1)
		for q in [a0, b0, b1, a0, b1, a1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, y, q.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _mat(col)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_mondo_pista.add_child(mi)

func _poligono_inset(st: SurfaceTool, c: Dictionary, ins: float, y: float) -> void:
	var r0: float = Pista.R0 + c["corsia"] * Pista.LARG_CORSIA + ins
	var r1: float = r0 + Pista.LARG_CORSIA - 2.0 * ins
	var passi := 1 if c["tipo"] == "r" else 8
	var ds: float = ins * (1.0 if c["tipo"] == "r" else Pista.R_MEDIO / (r0 + Pista.LARG_CORSIA / 2.0))
	var s0: float = c["s0"] + ds
	var s1: float = c["s1"] - ds
	for i in passi:
		var sa := lerpf(s0, s1, float(i) / passi)
		var sb := lerpf(s0, s1, float(i + 1) / passi)
		var a0 := pista.punto(sa, r0)
		var a1 := pista.punto(sa, r1)
		var b0 := pista.punto(sb, r0)
		var b1 := pista.punto(sb, r1)
		for q in [a0, b1, b0, a0, a1, b1]:
			st.add_vertex(Vector3(q.x, y, q.y))

func _linea_arrivo(r_in: float, r_out: float) -> void:
	var img := Image.create(16, 2, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 2:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color("#151515"))
	var tex := ImageTexture.create_from_image(img)
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.8, r_out - r_in)
	mi.mesh = q
	var m := _mat(Color.WHITE, 0.7)
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = m
	var p0 := pista.punto(0.0, Pista.R0)
	var x := p0.x
	var oz := p0.y - Pista.R0     # la partenza è sempre su un rettilineo verso +X
	mi.position = Vector3(x, 0.045, oz + (r_in + r_out) / 2.0)
	_mondo_pista.add_child(mi)
	# arco d'arrivo
	var legno := _mat(Color("#f4f4f4"), 0.6)
	var rosso := _mat(Color("#c8202b"), 0.6)
	for z in [r_in - 0.9, r_out + 0.9]:
		var palo := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.26
		cm.height = 7.5
		palo.mesh = cm
		palo.material_override = legno
		palo.position = Vector3(x, 3.75, oz + z)
		_mondo_pista.add_child(palo)
	var trave := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 1.9, r_out - r_in + 2.6)
	trave.mesh = bm
	trave.material_override = rosso
	trave.position = Vector3(x, 7.0, oz + (r_in + r_out) / 2.0)
	_mondo_pista.add_child(trave)
	# la scritta sta sullo striscione, sui due lati
	for lato in [-1.0, 1.0]:
		var scritta := Label3D.new()
		scritta.text = "ARRIVO"
		scritta.font = font
		scritta.font_size = 150
		scritta.pixel_size = 0.012
		scritta.modulate = Color("#ffd23f")
		scritta.outline_size = 14
		scritta.outline_modulate = Color("#5a0a0a")
		scritta.position = Vector3(x + lato * 0.19, 7.0, oz + (r_in + r_out) / 2.0)
		scritta.rotation_degrees.y = 90.0 * lato
		scritta.double_sided = false
		_mondo_pista.add_child(scritta)

func _steccato(r: float, esterno: bool) -> void:
	var bianco := _mat(Color("#f7f7f2"), 0.6)
	var n := int(pista.lunghezza * (r / Pista.R_MEDIO) / 2.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var palo := BoxMesh.new()
	palo.size = Vector3(0.14, 1.0, 0.14)
	mm.mesh = palo
	mm.instance_count = n
	for i in n:
		var p := pista.punto(pista.lunghezza * i / n, r)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, 0.5, p.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = bianco
	_mondo_pista.add_child(mmi)
	# traverse
	for h in [0.55, 0.95]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var k := 300
		for i in k:
			var a := pista.punto(pista.lunghezza * i / k, r)
			var b := pista.punto(pista.lunghezza * (i + 1) / k, r)
			var v := [Vector3(a.x, h - 0.06, a.y), Vector3(b.x, h - 0.06, b.y), Vector3(b.x, h + 0.06, b.y), Vector3(a.x, h + 0.06, a.y)]
			for j in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(v[j])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := bianco.duplicate()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		_mondo_pista.add_child(mi)
	# lucine di Natale sulla traversa alta
	if esterno:
		var nl := int(pista.lunghezza * (r / Pista.R_MEDIO) / 1.1)
		var colori := [Color("#ff3b3b"), Color("#ffd23f"), Color("#3bd16f"), Color("#4aa3ff")]
		for c in 4:
			var ml := MultiMesh.new()
			ml.transform_format = MultiMesh.TRANSFORM_3D
			var sfera := SphereMesh.new()
			sfera.radius = 0.12
			sfera.height = 0.24
			sfera.radial_segments = 8
			sfera.rings = 4
			ml.mesh = sfera
			var idx := []
			for i in nl:
				if i % 4 == c:
					idx.append(i)
			ml.instance_count = idx.size()
			for j in idx.size():
				var p := pista.punto(pista.lunghezza * idx[j] / nl, r)
				ml.set_instance_transform(j, Transform3D(Basis(), Vector3(p.x, 1.12, p.y)))
			var mli := MultiMeshInstance3D.new()
			mli.multimesh = ml
			var m := StandardMaterial3D.new()
			m.albedo_color = colori[c]
			m.emission_enabled = true
			m.emission = colori[c]
			m.emission_energy_multiplier = 2.2
			mli.material_override = m
			mli.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mondo_pista.add_child(mli)

func _tribuna(r_out: float) -> void:
	# tribuna dietro il rettilineo lontano (in alto), con il pubblico colorato
	var lung := pista.massimo.x - pista.minimo.x - 6.0
	var z0 := pista.minimo.y - 3.6
	var cemento := _mat(Color("#c9c2b4"), 0.95)
	for g in 5:
		var gr := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(lung, 0.8 * (g + 1), 2.0)
		gr.mesh = b
		gr.material_override = cemento
		gr.position = Vector3(0, 0.4 * (g + 1), z0 - 1.0 - g * 2.0)
		_mondo_pista.add_child(gr)
	var tetto := MeshInstance3D.new()
	var bt := BoxMesh.new()
	bt.size = Vector3(lung + 2, 0.3, 12)
	tetto.mesh = bt
	tetto.material_override = _mat(Color("#b3242c"), 0.7)
	tetto.position = Vector3(0, 7.6, z0 - 5.0)
	tetto.rotation_degrees.x = -8
	_mondo_pista.add_child(tetto)
	for x in [-lung / 2.0 + 1, 0.0, lung / 2.0 - 1]:
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.2
		cm.height = 7.6
		col.mesh = cm
		col.material_override = _mat(Color("#eeeeee"))
		col.position = Vector3(x, 3.8, z0 - 10.5)
		_mondo_pista.add_child(col)
	# pubblico
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	cap.radial_segments = 6
	cap.rings = 2
	mm.mesh = cap
	var tot := int(lung / 0.9) * 5
	mm.instance_count = tot
	var colori := [Color("#d62828"), Color("#f2c200"), Color("#1f5fd6"), Color("#2a9d3f"), Color("#ffffff"), Color("#8e44ad"), Color("#f77f00"), Color("#333333")]
	var i := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for g in 5:
		for k in int(lung / 0.9):
			var x := -lung / 2.0 + 0.5 + k * 0.9 + rng.randf_range(-0.2, 0.2)
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, 0.8 * (g + 1) + 0.55, z0 - 1.0 - g * 2.0 + rng.randf_range(-0.3, 0.3))))
			mm.set_instance_color(i, colori[rng.randi() % colori.size()])
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mp := StandardMaterial3D.new()
	mp.vertex_color_use_as_albedo = true
	mp.roughness = 0.8
	mmi.material_override = mp
	_mondo_pista.add_child(mmi)

func _albero(pos: Vector3, h: float) -> void:
	var t := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.18 * h
	tc.bottom_radius = 0.22 * h
	tc.height = 0.6 * h
	t.mesh = tc
	t.material_override = _mat(Color("#6b4226"))
	t.position = pos + Vector3(0, 0.3 * h, 0)
	_mondo_pista.add_child(t)
	for k in 3:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = (1.1 - k * 0.28) * h
		cm.height = 1.2 * h
		cm.radial_segments = 10
		c.mesh = cm
		c.material_override = _mat(Color("#1f6b3a").lightened(k * 0.05))
		c.position = pos + Vector3(0, (0.9 + k * 0.6) * h, 0)
		_mondo_pista.add_child(c)
	var stella := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18 * h
	sm.height = 0.36 * h
	stella.mesh = sm
	var ms := _mat(Color("#ffd23f"))
	ms.emission_enabled = true
	ms.emission = Color("#ffcc33")
	ms.emission_energy_multiplier = 2.0
	stella.material_override = ms
	stella.position = pos + Vector3(0, 2.7 * h, 0)
	_mondo_pista.add_child(stella)

## Siepe al centro della pista, con qualche pallina di Natale
func _siepe() -> void:
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 128
	nt.height = 128
	nt.seamless = true
	var g := Gradient.new()
	g.set_color(0, Color("#173f1c"))
	g.set_color(1, Color("#3c7a30"))
	nt.color_ramp = g
	m.albedo_texture = nt
	m.uv1_scale = Vector3(6, 2, 1)
	m.uv1_triplanar = true
	m.roughness = 1.0
	var alto := 1.3
	var r := 1.25
	# la siepe segue la linea di mezzo del prato interno (r = 0): dritta lungo i rettilinei,
	# un cespuglio tondo dove le curve hanno il centro
	var lungo := []
	var k := int(pista.lunghezza / 1.0)
	for i in k:
		var q := pista.punto(pista.lunghezza * i / k, 0.0)
		var nuovo := true
		for x in lungo:
			if x.distance_to(q) < 0.9:
				nuovo = false
				break
		if nuovo:
			lungo.append(q)
	# nelle strettoie la corsia interna è siepe
	var strette := []
	for sg in pista.segmenti:
		if sg["pezzo"] == "S":
			var ss: float = sg["s0"] + 0.6
			while ss < sg["s1"] - 0.5:
				strette.append(pista.punto(ss, Pista.R0 + Pista.LARG_CORSIA * 0.5))
				ss += 0.9
	lungo.append_array(strette)
	var mmb := MultiMesh.new()
	mmb.transform_format = MultiMesh.TRANSFORM_3D
	var sfera := SphereMesh.new()
	sfera.radius = r
	sfera.height = alto * 1.6
	mmb.mesh = sfera
	mmb.instance_count = lungo.size()
	for i in lungo.size():
		mmb.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.0)), Vector3(lungo[i].x, alto * 0.45, lungo[i].y)))
	var corpo := MultiMeshInstance3D.new()
	corpo.multimesh = mmb
	corpo.material_override = m
	_mondo_pista.add_child(corpo)
	var colori := [Color("#d62828"), Color("#ffd23f"), Color("#ffffff")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for c in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var sf := SphereMesh.new()
		sf.radius = 0.13
		sf.height = 0.26
		sf.radial_segments = 8
		sf.rings = 4
		mm.mesh = sf
		var n := int(lungo.size() / 2.5) + 1
		mm.instance_count = n
		for i in n:
			var q: Vector2 = lungo[rng.randi() % lungo.size()]
			var dd := Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(q.x + dd.x, alto * 1.05, q.y + dd.y)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mc := StandardMaterial3D.new()
		mc.albedo_color = colori[c]
		mc.emission_enabled = true
		mc.emission = colori[c]
		mc.emission_energy_multiplier = 0.8
		mi.material_override = mc
		_mondo_pista.add_child(mi)

func _alberi(_r_in: float, r_out: float) -> void:
	# alberi di Natale nel prato interno e ai lati
	_siepe()
	for s in [-1.0, 1.0]:
		var xb := pista.massimo.x if s > 0 else pista.minimo.x
		_albero(Vector3(xb + s * 5.0, 0, -3), 2.0)
		_albero(Vector3(xb + s * 8.0, 0, 4), 1.6)

# ------------------------------------------------------------------ posizioni
## I token stanno fuori dalla pista, sul prato accanto al bordo esterno, all'altezza della loro colonna
func pos_token(id: int) -> Vector3:
	var r := Pista.R0 + Pista.CORSIE * Pista.LARG_CORSIA + Pista.BORDO + 1.55
	if token_nodi.has(id) and not (token_nodi[id].get_meta("tipo") is String):
		r = Pista.R0 + Pista.CORSIE * Pista.LARG_CORSIA + Pista.BORDO + 1.05
	var p := pista.punto(pista.celle[id]["s"], r)
	return Vector3(p.x, 0.02, p.y)

func pos_cella(id: int) -> Vector3:
	var c: Vector2 = pista.celle[id]["centro"]
	return Vector3(c.x, 0.04, c.y)

## Recinto di partenza: in fila sul prato davanti al primo rettilineo, fuori dalla pista
func pos_partenza(cid: int) -> Vector3:
	var r_out := Pista.R0 + Pista.CORSIE * Pista.LARG_CORSIA + Pista.BORDO
	var q := pista.punto(1.6 + cid * 3.1, r_out + (4.4 if cid % 2 == 0 else 6.6))
	return Vector3(q.x, 0.04, q.y)

func pos_cavallo(cid: int, cella: int) -> Vector3:
	if cella == Pista.PARTENZA:
		return pos_partenza(cid)
	if cella == Pista.TRAGUARDO:
		return pos_arrivato(cid)
	return pos_cella(cella)

func pos_arrivato(_cid: int) -> Vector3:
	var p := pista.punto(7.0, Pista.R_MEDIO)
	return Vector3(p.x, 0.04, p.y)

func _base_dir(d: Vector2) -> Basis:
	var dir := Vector3(d.x, 0, d.y).normalized()
	return Basis.looking_at(dir, Vector3.UP)

func dir_cella(id: int) -> Vector2:
	if id < 0:
		return Vector2(1, 0)
	return pista.celle[id]["dir"]

## Mette i cavalli e i token dove dice il motore (senza animazioni)
func sincronizza(m: Motore) -> void:
	for c in m.cavalli:
		var h: Cavallo3D = cavalli[c["id"]]
		h.imposta(c["attivo"], c["zoppo"])
		if _in_moto.get(c["id"], false):
			continue
		if c["zoppo"]:
			_metti_zoppo(h, c["cella_zoppo"])
		elif c["cella"] == Pista.TRAGUARDO:
			pass
		else:
			h.position = pos_cavallo(c["id"], c["cella"])
			h.basis = _base_dir(dir_cella(c["cella"]))
			h.modello.rotation = Vector3.ZERO
	for k in token_nodi.keys():
		if not m.token.has(k):
			token_nodi[k].queue_free()
			token_nodi.erase(k)
	for k in m.token:
		if not token_nodi.has(k):
			metti_token(k, m.token[k])
		elif token_nodi[k].get_meta("tipo") != m.token[k]:
			token_nodi[k].queue_free()
			metti_token(k, m.token[k])
	disegna_colonne(m.token.keys())

## Il token vale per tutta la colonna: le caselle affiancate si colorano di azzurro chiaro
func disegna_colonne(celle_token: Array) -> void:
	if _bande:
		_bande.queue_free()
		_bande = null
	if celle_token.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in celle_token:
		for c in pista.colonna[t]:
			_poligono_inset(st, pista.celle[c], 0.12, 0.05)
	_bande = MeshInstance3D.new()
	_bande.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.72, 1.0, 0.62)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bande.material_override = m
	_bande.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bande)

func _metti_zoppo(h: Cavallo3D, cella: int) -> void:
	var c: Dictionary = pista.celle[cella]
	# a lato della casella, fuori pista (sul bordo interno, così non copre i token che stanno fuori)
	var p := pista.punto(c["s"], Pista.R0 - Pista.BORDO - 1.2)
	h.position = Vector3(p.x, 0.04, p.y)
	h.basis = _base_dir(c["dir"])
	h.modello.rotation = Vector3.ZERO

# ------------------------------------------------------------------ animazioni
func _punti_percorso(cid: int, perc: Array, da: int) -> Array:
	var pts := [cavalli[cid].position]
	var prec := da
	for c in perc:
		if c == da:
			continue
		if c == Pista.TRAGUARDO:
			var s_fine := pista.lunghezza
			var r: float = Pista.R0 + (pista.celle[prec]["corsia"] + 0.5) * Pista.LARG_CORSIA if prec >= 0 else Pista.R_MEDIO
			if prec >= 0:
				var s_a: float = pista.celle[prec]["s"]
				for k in range(1, 6):
					var s := lerpf(s_a, s_fine, k / 5.0)
					var q := pista.punto(s, r)
					pts.append(Vector3(q.x, 0.04, q.y))
			for k in range(1, 4):
				var q := pista.punto(k * 2.5, r)
				pts.append(Vector3(q.x, 0.04, q.y))
			break
		if prec >= 0 and c >= 0 and pista.celle[prec]["corsia"] == pista.celle[c]["corsia"] and (pista.celle[prec]["tipo"] == "c" or pista.celle[c]["tipo"] == "c"):
			var r: float = Pista.R0 + (pista.celle[c]["corsia"] + 0.5) * Pista.LARG_CORSIA
			var s_a: float = pista.celle[prec]["s"]
			var s_b: float = pista.celle[c]["s"]
			if absf(s_b - s_a) > pista.lunghezza / 2.0:
				s_b += pista.lunghezza if s_b < s_a else -pista.lunghezza
			for k in range(1, 6):
				var q := pista.punto(lerpf(s_a, s_b, k / 5.0), r)
				pts.append(Vector3(q.x, 0.04, q.y))
		else:
			pts.append(pos_cavallo(cid, c))
		prec = c
	return pts

func anima_mossa(cid: int, perc: Array, da: int, velocita := 1.0) -> void:
	var h: Cavallo3D = cavalli[cid]
	_in_moto[cid] = true
	h.modello.rotation = Vector3.ZERO
	var pts := _punti_percorso(cid, perc, da)
	var avanti := true
	if perc.size() >= 2 and perc[-1] != Pista.TRAGUARDO and perc[0] != Pista.PARTENZA:
		avanti = pista.progresso(perc[-1]) >= pista.progresso(perc[0]) or perc[0] < 0
	if perc.size() >= 2 and perc[-1] == Pista.PARTENZA:
		avanti = false
	h.galoppa(true)
	_segui = h
	var vel := VEL * velocita * (1.0 if avanti else 0.55)
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var L := a.distance_to(b)
		if L < 0.01:
			continue
		var dir := (b - a).normalized()
		if not avanti:
			dir = -dir
		var base_obj := Basis.looking_at(dir, Vector3.UP)
		var t := 0.0
		while t < L:
			var dt := get_process_delta_time()
			t += dt * vel
			h.position = a.lerp(b, minf(t / L, 1.0))
			h.basis = h.basis.slerp(base_obj, minf(1.0, dt * 9.0)).orthonormalized()
			await get_tree().process_frame
	h.galoppa(false)
	_segui = h   # resta inquadrato: la vista generale torna all'inizio del turno dopo
	if perc.size() and perc[-1] >= 0:
		var fin := _base_dir(dir_cella(perc[-1]))
		for k in 10:
			h.basis = h.basis.slerp(fin, 0.3).orthonormalized()
			await get_tree().process_frame
	_in_moto.erase(cid)

func anima_zoppo(cid: int, cella: int, fuori: bool) -> void:
	var h: Cavallo3D = cavalli[cid]
	if fuori:
		var tw := create_tween()
		tw.tween_property(h.modello, "rotation:z", 0.5, 0.15)
		tw.tween_property(h.modello, "rotation:z", -0.5, 0.15)
		tw.tween_property(h.modello, "rotation:z", 0.0, 0.15)
		await tw.finished
		h.imposta(false, true)
		_metti_zoppo(h, cella)
	else:
		h.modello.rotation = Vector3.ZERO

# ------------------------------------------------------------------ dado 3D
const LATO_DADO := 3.6
const NORMALI_DADO := [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]

## Un dado con le sei facce di Dati.DADO (la faccia i sta sulla normale NORMALI_DADO[i])
func _nodo_dado() -> Node3D:
	var d := Node3D.new()
	var cubo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * LATO_DADO
	cubo.mesh = bm
	cubo.material_override = _mat(Color("#f6efdc"), 0.45)
	d.add_child(cubo)
	var mezzo := LATO_DADO / 2.0 + 0.01
	for i in 6:
		var f: Dictionary = Dati.DADO[i]
		var n: Vector3 = NORMALI_DADO[i]
		var su := Vector3.FORWARD if absf(n.y) > 0.5 else Vector3.UP
		var faccia := Node3D.new()
		faccia.basis = Basis.looking_at(-n, su)
		faccia.position = n * mezzo
		d.add_child(faccia)
		var l := Label3D.new()
		l.text = ("+%d\n-%d" % [f["n"], f["n"]]) if f.get("e", false) else ("+%d" % f["n"])
		l.font = font
		l.font_size = 120 if not f.get("e", false) else 80
		l.line_spacing = -18
		l.pixel_size = 0.017
		l.modulate = Color("#2a1608")
		l.outline_size = 0
		l.double_sided = false
		faccia.add_child(l)
		if f.get("v", false):
			var pv := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.36
			cm.bottom_radius = 0.36
			cm.height = 0.04
			pv.mesh = cm
			var mv := _mat(Color("#22b04a"), 0.4)
			pv.material_override = mv
			pv.rotation_degrees.x = 90
			pv.position = Vector3(1.15, 1.15, 0.0)
			faccia.add_child(pv)
	return d

## Tira i dadi davvero: rotolano sulla pista e si fermano con la faccia giusta in alto
## Dove sta la pista sullo schermo (pixel), per mettere i dadi sotto senza coprirla
func rettangolo_pista() -> Rect2:
	var r := Rect2()
	var primo := true
	var mn: Vector2 = pista.minimo
	var mx: Vector2 = pista.massimo + Vector2(0, 8.0)   # compresi i cavalli fermi alla partenza, sotto la pista
	for p in [Vector3(mn.x, 0, mn.y), Vector3(mx.x, 0, mn.y), Vector3(mn.x, 0, mx.y), Vector3(mx.x, 0, mx.y)]:
		var q := cam.unproject_position(p)
		if primo:
			r = Rect2(q, Vector2.ZERO)
			primo = false
		else:
			r = r.expand(q)
	return r

## Punto del prato che si vede in quel punto dello schermo
func punto_a_terra(schermo: Vector2) -> Vector3:
	var o := cam.project_ray_origin(schermo)
	var d := cam.project_ray_normal(schermo)
	if absf(d.y) < 0.001:
		return _cam_target
	return o + d * (-o.y / d.y)

func lancia_dadi(facce: Array, suono: Callable, velocita := 1.0, zona := Rect2()) -> Array:
	var dadi := []
	var arrivi := []
	var n := facce.size()
	for k in n:
		var d := _nodo_dado()
		add_child(d)
		var base := _cam_target + Vector3(0, 0, 4.0)
		var passo := 5.6
		if zona.size.x > 0:
			# i dadi rotolano sul prato sotto la pista
			base = punto_a_terra(zona.get_center())
			var b := punto_a_terra(zona.get_center() + Vector2(zona.size.x / maxf(1.0, n), 0))
			passo = minf(5.6, base.distance_to(b))
		var centro := base + Vector3((k - (n - 1) / 2.0) * passo, 0, 0)
		var inizio := centro + Vector3(randf_range(-8, 8), 9.0, 16.0)
		d.position = inizio
		d.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var idx := Dati.DADO.find(facce[k])
		if idx < 0:
			idx = 0
		var finale := Basis(Quaternion(Vector3.UP, randf() * TAU)) * Basis(Quaternion(NORMALI_DADO[idx], Vector3.UP))
		dadi.append({"n": d, "da": inizio, "a": centro + Vector3(0, LATO_DADO / 2.0, 0), "fin": finale,
			"w": Vector3(randf_range(6, 11), randf_range(-4, 4), randf_range(6, 11)), "rimbalzo": -1})
		arrivi.append(centro)
	var durata := 1.7 / clampf(velocita, 0.5, 3.0)
	var t := 0.0
	while t < durata:
		var dt := get_process_delta_time()
		t += dt
		var u := minf(t / durata, 1.0)
		for x in dadi:
			var d: Node3D = x["n"]
			var e := 1.0 - pow(1.0 - u, 2.0)
			var pos: Vector3 = x["da"].lerp(x["a"], e)
			var rimb := int(u * 3.0)
			pos.y = x["a"].y + absf(sin(u * PI * 3.0)) * 7.0 * pow(1.0 - u, 2.0) + (1.0 - u) * 0.0
			d.position = pos
			if rimb != x["rimbalzo"]:
				x["rimbalzo"] = rimb
				suono.call()
			if u < 0.72:
				var w: Vector3 = x["w"] * (1.0 - u)
				d.basis = (Basis(Vector3.RIGHT, w.x * dt) * Basis(Vector3.UP, w.y * dt) * Basis(Vector3.BACK, w.z * dt) * d.basis).orthonormalized()
			else:
				d.basis = d.basis.slerp(x["fin"], minf(1.0, dt * 9.0)).orthonormalized()
		await get_tree().process_frame
	var nodi := []
	for x in dadi:
		x["n"].basis = x["fin"]
		x["n"].position = x["a"]
		nodi.append(x["n"])
	return nodi

func togli_dadi_3d(nodi: Array) -> void:
	for d in nodi:
		if is_instance_valid(d):
			var tw := create_tween()
			tw.tween_property(d, "scale", Vector3.ONE * 0.01, 0.3)
			tw.tween_callback(d.queue_free)

# ------------------------------------------------------------------ token
## Carta della versione con le carte: spunta da sotto il bordo esterno, si vede la parte di sotto
func _nodo_carta(k: int, cella: int) -> Node3D:
	var n := Node3D.new()
	n.set_meta("tipo", k)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.3, 2.53)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/carte/s%02d.webp" % (k + 1))
	m.roughness = 0.7
	q.material_override = m
	q.position.y = 0.03
	n.add_child(q)
	n.rotation.y = -dir_cella(cella).angle()
	return n

func _nodo_token(tipo, cella := -1) -> Node3D:
	if not (tipo is String):
		return _nodo_carta(int(tipo), cella)
	var n := Node3D.new()
	n.set_meta("tipo", tipo)
	var d := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.05
	cm.bottom_radius = 1.05
	cm.height = 0.16
	cm.radial_segments = 32
	d.mesh = cm
	d.material_override = _mat(Color("#e8e8e8"), 0.5)
	d.position.y = 0.08
	n.add_child(d)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.06, 2.06)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex_token[tipo]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.6
	q.material_override = m
	q.position.y = 0.17
	n.add_child(q)
	return n

func metti_token(cella: int, tipo) -> Node3D:
	var n := _nodo_token(tipo, cella)
	add_child(n)
	token_nodi[cella] = n
	n.position = pos_token(cella)
	return n

func anima_token_rivela(tipo: String, cella: int, esistente: bool) -> void:
	var n: Node3D
	if esistente and token_nodi.has(cella):
		n = token_nodi[cella]
	else:
		if token_nodi.has(cella):
			token_nodi[cella].queue_free()
		n = metti_token(cella, tipo)
	var base := pos_token(cella)
	var tw := create_tween()
	tw.tween_property(n, "position", base + Vector3(0, 5.5, 0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "scale", Vector3.ONE * 2.2, 0.45)
	tw.parallel().tween_property(n, "rotation:x", PI / 2.6, 0.45)
	tw.tween_interval(1.0)
	tw.tween_property(n, "position", base, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "scale", Vector3.ONE, 0.4)
	tw.parallel().tween_property(n, "rotation:x", 0.0, 0.3)
	await tw.finished

func anima_token_sposta(da: int, a: int, tipo: String) -> void:
	var n: Node3D = token_nodi.get(da)
	token_nodi.erase(da)
	if n == null:
		n = _nodo_token(tipo)
		add_child(n)
		n.position = pos_token(da)
	token_nodi[a] = n
	var tw := create_tween()
	var mid := (pos_token(da) + pos_token(a)) / 2.0 + Vector3(0, 2.5, 0)
	tw.tween_property(n, "position", mid, 0.3)
	tw.tween_property(n, "position", pos_token(a), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished

func anima_token_via(celle: Array) -> void:
	var tw: Tween = null
	for c in celle:
		if token_nodi.has(c):
			var n: Node3D = token_nodi[c]
			token_nodi.erase(c)
			tw = create_tween()
			tw.tween_property(n, "position:y", 6.0, 0.4)
			tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.1, 0.4)
			tw.tween_callback(n.queue_free)
	if tw:
		await tw.finished

# ------------------------------------------------------------------ caselle da scegliere
func mostra_marcatori(opzioni: Array) -> void:
	togli_marcatori()
	for o in opzioni:
		if not o.has("cella"):
			continue
		var n := Node3D.new()
		var d := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.75
		tm.outer_radius = 1.0
		d.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#ff2d55")
		m.emission_enabled = true
		m.emission = Color("#ff2d55")
		m.emission_energy_multiplier = 1.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		d.material_override = m
		d.position.y = 0.2
		n.add_child(d)
		var l := Label3D.new()
		l.text = str(o["t"])
		l.font = font
		l.font_size = 96
		l.pixel_size = 0.012
		l.outline_size = 20
		l.modulate = Color.WHITE
		l.outline_modulate = Color("#b0002a")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position.y = 1.4
		l.render_priority = 3
		n.add_child(l)
		add_child(n)
		n.position = pos_cella(int(o["cella"]))
		marcatori.append(n)

func togli_marcatori() -> void:
	for n in marcatori:
		n.queue_free()
	marcatori = []

func evidenzia_cavalli(ids: Array) -> void:
	for h in cavalli:
		h.evidenzia(ids.has(h.id))

# ------------------------------------------------------------------ telecamera
func _inquadra_tutto(subito := false) -> void:
	var larg := pista.massimo.x - pista.minimo.x + 6.0
	var prof := pista.massimo.y - pista.minimo.y + 8.0
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var aspetto := vp.x / maxf(1.0, vp.y)
	var fov_v := deg_to_rad(cam.fov)
	var fov_h := 2.0 * atan(tan(fov_v / 2.0) * aspetto)
	var pitch := deg_to_rad(52.0)
	if aree_libere.is_empty():
		var d1 := (larg / 2.0) / tan(fov_h / 2.0) * 1.28
		var d2 := (prof / 2.0) / tan(fov_v / 2.0) * 1.05
		_cam_dist_obj = maxf(d1, d2) * zoom_extra
		_cam_target_obj = Vector3(spostamento_ui.x * larg, 0, -2.0 + spostamento_ui.y * prof)
	else:
		# la pista occupa tutto il rettangolo libero più grande, centrata in esso
		var best := 1.0e9
		var bt := Vector3.ZERO
		for a in aree_libere:
			var r: Rect2 = a
			var fx := r.size.x / vp.x
			var fy := r.size.y / vp.y
			if fx <= 0.05 or fy <= 0.05:
				continue
			var dd := maxf(larg / (2.0 * tan(fov_h / 2.0) * fx), prof * sin(pitch) * 1.1 / (2.0 * tan(fov_v / 2.0) * fy)) * 1.04
			if dd < best:
				best = dd
				var wv := 2.0 * dd * tan(fov_h / 2.0)
				var hv := 2.0 * dd * tan(fov_v / 2.0)
				var c := r.get_center()
				bt = Vector3(-(c.x - vp.x / 2.0) / vp.x * wv, 0, -1.0 - (c.y - vp.y / 2.0) / vp.y * hv / sin(pitch))
		_cam_dist_obj = best
		_cam_target_obj = bt
	if subito:
		_cam_dist = _cam_dist_obj
		_cam_target = _cam_target_obj

func vista_generale() -> void:
	_segui = null
	_inquadra_tutto()

var camera_libera := false

func _process(delta: float) -> void:
	if cam == null or camera_libera:
		return
	if _segui:
		_inquadra_tutto()
		var gen_d := _cam_dist_obj
		var p := _segui.global_position
		_cam_target_obj = _cam_target_obj.lerp(Vector3(p.x, 0, p.z), 0.65)
		_cam_dist_obj = gen_d * zoom_segui
	else:
		_inquadra_tutto()
	var k := minf(1.0, delta * 1.6)
	_cam_target = _cam_target.lerp(_cam_target_obj, k)
	_cam_dist = lerpf(_cam_dist, _cam_dist_obj, k)
	var pitch := deg_to_rad(52.0)
	cam.position = _cam_target + Vector3(0, sin(pitch), cos(pitch)) * _cam_dist
	cam.look_at(_cam_target, Vector3.UP)

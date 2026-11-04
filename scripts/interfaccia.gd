class_name Interfaccia
extends Control
## Tutto quello che sta sopra la pista: cronista con il fumetto, classifica, chi tocca, dadi,
## sala d'attesa con il QR code, scelta delle pile, risultati finali. Solo testo e disegni:
## nessun simbolo speciale (il font non li ha).

signal comando(nome: String, valore)

const ROSSO := Color("#b8202a")
const CREMA := Color("#fff4d6")
const GIALLO := Color("#ffd23f")
const SCURO := Color("#2a1608")

var f_titolo: Font
var f_testo: Font
var f_medio: Font
var avatar: TextureRect
var fumetto: PanelContainer
var testo_fumetto: Label
var pose := {}
var banner: PanelContainer
var banner_titolo: Label
var banner_sotto: Label
var dadi_box: HBoxContainer
var presi_box: HBoxContainer      # corsa al dado: i dadi già presi, con il nome di chi li ha presi
var _dadi_ws := []
var _presi_nome := {}
var classifica: VBoxContainer
var righe_cavalli := []
var lista_giocatori: VBoxContainer
var montepremi: Label
var pannello_destra: PanelContainer
var comandi: HBoxContainer
var bt_decidi: Button
var bt_voce: Button
var sala: Control
var sala_qr: TextureRect
var sala_codice: Label
var sala_url: Label
var sala_giocatori: GridContainer
var sala_conteggio: Label
var sala_parti: Button
var sala_bot: Button
var sala_riprendi: Button
var bt_sacchetto: Button
var sacchetto_box: Control
var sacchetto_righe := {}
var mazzo_box: Control
var mazzo_bottoni := []
var _versione := "token"
var sala_togli: Button
var _sacchetto_testo := ""
var _mazzo_testo := ""
var sala_opzioni := {}
var pile_box: Control
var pile_celle := []
var finale: Control
var _pose_tween: Tween
var titolo_img: TextureRect
var velocita := 1.0
var giro_box: PanelContainer        # in basso a destra: i ritratti dei giocatori, chi ha già giocato nel giro
var giro_flow: GridContainer
var quota_lbl: Label
var giro_carte := {}                # uid -> {p, ritratto, nome, timbro}
var _giro_chiave := ""
var _tex_ritratti := {}
var _in_roulette := false
var _accesi_fissi := []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_adatta)
	_adatta()
	f_titolo = load("res://assets/font/Bangers-Regular.ttf")
	f_testo = load("res://assets/font/BarlowCondensed-Bold.ttf")
	f_medio = load("res://assets/font/BarlowCondensed-Medium.ttf")
	var th := Theme.new()
	th.default_font = f_testo
	th.default_font_size = 30
	theme = th
	for p in ["saluta", "parla", "indica"]:
		posa_tex(p)
	_crea_titolo()
	_crea_destra()
	_crea_banner()
	_crea_avatar()
	_crea_comandi()
	_crea_giro()
	_crea_sala()
	_crea_pile()
	move_child(avatar, -1)
	move_child(fumetto, -1)
	finale = Control.new()
	finale.set_anchors_preset(Control.PRESET_FULL_RECT)
	finale.visible = false
	add_child(finale)
	move_child(avatar, -1)
	move_child(fumetto, -1)

func _adatta() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

# ------------------------------------------------------------------ mattoncini
func stile(bg: Color, bordo: Color, raggio := 18, spess := 5, ombra := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(spess)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	if ombra:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 4)
	return s

func etichetta(t: String, font: Font, size: int, col := SCURO, outline := 0, col_out := Color.BLACK) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", col_out)
	return l

func bottone(t: String, size := 30, col := ROSSO) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", f_titolo)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", GIALLO)
	b.add_theme_color_override("font_pressed_color", GIALLO)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_stylebox_override("normal", stile(col, col.darkened(0.4), 14, 4))
	b.add_theme_stylebox_override("hover", stile(col.lightened(0.12), col.darkened(0.4), 14, 4))
	b.add_theme_stylebox_override("pressed", stile(col.darkened(0.15), col.darkened(0.5), 14, 4))
	b.add_theme_stylebox_override("disabled", stile(Color(0.45, 0.42, 0.4), Color(0.3, 0.28, 0.26), 14, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

# ------------------------------------------------------------------ titolo e comandi
func _crea_titolo() -> void:
	titolo_img = TextureRect.new()
	titolo_img.texture = load("res://assets/ui/titolo.png")
	titolo_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	titolo_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	titolo_img.position = Vector2(16, 10)
	titolo_img.size = Vector2(440, 122)
	titolo_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(titolo_img)

func _crea_comandi() -> void:
	comandi = HBoxContainer.new()
	comandi.position = Vector2(24, 136)
	comandi.add_theme_constant_override("separation", 10)
	add_child(comandi)
	var fs := bottone("Schermo intero", 22, Color("#3d5a80"))
	fs.pressed.connect(func(): comando.emit("schermo", null))
	comandi.add_child(fs)
	bt_voce = bottone("Voce: sì", 22, Color("#3d5a80"))
	bt_voce.pressed.connect(func(): comando.emit("voce", null))
	comandi.add_child(bt_voce)
	bt_decidi = bottone("Decidi tu", 22, Color("#6a4c93"))
	bt_decidi.pressed.connect(func(): comando.emit("decidi", null))
	bt_decidi.visible = false
	comandi.add_child(bt_decidi)

# ------------------------------------------------------------------ pannello a destra
func _crea_destra() -> void:
	pannello_destra = PanelContainer.new()
	pannello_destra.add_theme_stylebox_override("panel", stile(Color(1.0, 0.96, 0.84, 0.94), ROSSO, 20, 5))
	pannello_destra.anchor_left = 1.0
	pannello_destra.anchor_right = 1.0
	pannello_destra.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pannello_destra.offset_right = -16
	pannello_destra.custom_minimum_size = Vector2(330, 0)
	pannello_destra.offset_top = 16
	pannello_destra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pannello_destra)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pannello_destra.add_child(v)
	var tit_corsa := etichetta("IN CORSA", f_titolo, 38, ROSSO)
	tit_corsa.visible = false
	v.add_child(tit_corsa)
	classifica = VBoxContainer.new()
	classifica.visible = false
	classifica.add_theme_constant_override("separation", 3)
	v.add_child(classifica)
	for i in 8:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var pos := etichetta("%d" % (i + 1), f_titolo, 28, SCURO)
		pos.custom_minimum_size = Vector2(30, 0)
		r.add_child(pos)
		var col := ColorRect.new()
		col.custom_minimum_size = Vector2(26, 26)
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(col)
		var nome := etichetta("", f_testo, 28, SCURO)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nome)
		var st := etichetta("", f_medio, 24, Color("#6b4a2a"))
		r.add_child(st)
		classifica.add_child(r)
		righe_cavalli.append({"riga": r, "col": col, "nome": nome, "stato": st})
	# della colonna di destra resta solo il montepremi: i cavalli si vedono in pista e i giocatori nei ritratti
	montepremi = etichetta("", f_titolo, 34, Color("#1d6b3a"))
	montepremi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(montepremi)
	quota_lbl = etichetta("", f_testo, 26, SCURO)
	quota_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(quota_lbl)
	var tg := etichetta("GIOCATORI", f_titolo, 30, ROSSO)
	tg.visible = false
	v.add_child(tg)
	lista_giocatori = VBoxContainer.new()
	lista_giocatori.visible = false
	lista_giocatori.add_theme_constant_override("separation", 0)
	v.add_child(lista_giocatori)

func aggiorna_classifica(m: Motore) -> void:
	if m.cavalli.size() < 8:
		return
	var ord := m.cavalli.duplicate()
	ord.sort_custom(func(a, b):
		var pa := -100.0 if a["zoppo"] else m.pista.progresso(a["cella"])
		var pb := -100.0 if b["zoppo"] else m.pista.progresso(b["cella"])
		if a["zoppo"]:
			pa = m.pista.progresso(a["cella_zoppo"]) - 0.01
		if b["zoppo"]:
			pb = m.pista.progresso(b["cella_zoppo"]) - 0.01
		return pa > pb)
	for i in 8:
		var c: Dictionary = ord[i]
		var r: Dictionary = righe_cavalli[i]
		r["col"].color = Dati.colore(c["id"])
		r["nome"].text = Dati.nome(c["id"])
		r["stato"].text = m._stato_cavallo(c) if c["cella"] != Pista.TRAGUARDO else "ARRIVATO"
		r["nome"].add_theme_color_override("font_color", SCURO if c["attivo"] else Color("#8a7a6a"))
	if m.giocatori.size():
		montepremi.text = "MONTEPREMI " + m.euro(m.montepremi()).to_upper() if m.cfg["posta"] > 0 else "PER LA GLORIA"
		quota_lbl.text = ("una quota vale " + m.euro(m.quota_euro())) if m.cfg["posta"] > 0 else "contano le quote"
	else:
		montepremi.text = ""
	for c in lista_giocatori.get_children():
		c.queue_free()
	for g in m.giocatori:
		var t: String = g["nome"]
		var l := etichetta(t, f_testo, 27, SCURO)
		if g["uid"] == m.di_turno:
			l.text = "> " + t + " <"
			l.add_theme_color_override("font_color", ROSSO)
		lista_giocatori.add_child(l)

# ------------------------------------------------------------------ banner "tocca a"
func _crea_banner() -> void:
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", stile(ROSSO, Color("#ffd23f"), 22, 6))
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.position = Vector2(0, 18)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	add_child(banner)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(v)
	banner_titolo = etichetta("", f_titolo, 64, GIALLO, 10, Color("#3a0505"))
	banner_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_titolo)
	banner_sotto = etichetta("", f_testo, 30, Color.WHITE)
	banner_sotto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_sotto)
	dadi_box = HBoxContainer.new()
	dadi_box.anchor_left = 0.5
	dadi_box.anchor_right = 0.5
	dadi_box.position = Vector2(0, 190)
	dadi_box.add_theme_constant_override("separation", 30)
	dadi_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dadi_box)
	presi_box = HBoxContainer.new()
	presi_box.position = Vector2(0, 400)
	presi_box.add_theme_constant_override("separation", 30)
	presi_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(presi_box)

func mostra_banner(titolo: String, sotto := "") -> void:
	banner.visible = titolo != ""
	banner_titolo.text = titolo
	banner_sotto.text = sotto
	banner_sotto.visible = sotto != ""
	await get_tree().process_frame
	banner.reset_size()
	banner.position.x = size.x / 2.0 - banner.size.x / 2.0 - 120

func sotto_banner(sotto: String) -> void:
	banner_sotto.text = sotto
	banner_sotto.visible = sotto != ""
	await get_tree().process_frame
	banner.reset_size()
	banner.position.x = size.x / 2.0 - banner.size.x / 2.0 - 120

func tex_ritratto(id: String) -> Texture2D:
	if id == "":
		return null
	if not _tex_ritratti.has(id):
		_tex_ritratti[id] = load("res://assets/ritratti/%s.webp" % id)
	return _tex_ritratti[id]

# ------------------------------------------------------------------ ritratti del giro (in basso a destra)
func _crea_giro() -> void:
	giro_box = PanelContainer.new()
	giro_box.add_theme_stylebox_override("panel", stile(Color(1.0, 0.96, 0.84, 0.92), ROSSO, 18, 4))
	giro_box.anchor_left = 1.0
	giro_box.anchor_right = 1.0
	giro_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	giro_box.offset_right = -16
	giro_box.offset_top = 128
	giro_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	giro_box.visible = false
	add_child(giro_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	giro_box.add_child(v)
	var t := etichetta("CHI GIOCA", f_titolo, 28, ROSSO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	giro_flow = GridContainer.new()
	giro_flow.add_theme_constant_override("h_separation", 8)
	giro_flow.add_theme_constant_override("v_separation", 6)
	v.add_child(giro_flow)

func _stile_carta(acceso: bool) -> StyleBoxFlat:
	var s := stile(Color("#fff8e6"), Color("#ffd23f") if acceso else Color("#8a5a2a"), 10, 7 if acceso else 3, acceso)
	s.content_margin_left = 3
	s.content_margin_right = 3
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s

func aggiorna_giro(m: Motore) -> void:
	giro_box.visible = m.fase == "corsa" or m.fase == "pile"
	var chiave := ""
	for g in m.giocatori:
		chiave += g["uid"] + g.get("ritratto", "") + "|"
	if chiave != _giro_chiave:
		_giro_chiave = chiave
		for c in giro_flow.get_children():
			c.queue_free()
		giro_carte = {}
		# tutti su una fila: più sono, più piccoli (da 150 a 90 pixel)
		# in colonna sulla destra: una colonna fino a 4 giocatori, poi due
		var ng := maxi(1, m.giocatori.size())
		var colonne := 1 if ng <= 4 else 2
		giro_flow.columns = colonne
		var righe := int(ceil(float(ng) / colonne))
		var alto := get_viewport_rect().size.y - 128.0 - 16.0 - 60.0
		var lato := clampf(alto / righe - 44.0, 70.0, 150.0)
		for g in m.giocatori:
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", _stile_carta(false))
			var vv := VBoxContainer.new()
			vv.add_theme_constant_override("separation", 0)
			p.add_child(vv)
			var r := TextureRect.new()
			r.texture = tex_ritratto(g.get("ritratto", ""))
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.custom_minimum_size = Vector2(lato, lato)
			vv.add_child(r)
			var n := etichetta(str(g.get("base", g["nome"])), f_testo, int(clampf(lato / 6.0, 17, 26)), SCURO)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.custom_minimum_size = Vector2(lato, 0)
			n.clip_text = true
			vv.add_child(n)
			var timbro := etichetta("GIOCATO", f_titolo, int(lato / 3.6), Color("#c8202b"), 6, Color.WHITE)
			timbro.rotation = -0.35
			timbro.position = Vector2(lato * 0.08, lato * 0.42)
			timbro.visible = false
			p.add_child(timbro)
			timbro.set_anchors_preset(Control.PRESET_TOP_LEFT)
			giro_flow.add_child(p)
			giro_carte[g["uid"]] = {"p": p, "r": r, "timbro": timbro}
	for g in m.giocatori:
		var c: Dictionary = giro_carte.get(g["uid"], {})
		if c.is_empty():
			continue
		var gioc: bool = m.giro.has(g["uid"]) and g["uid"] != m.di_turno
		c["r"].modulate = Color(0.45, 0.45, 0.45) if gioc else Color.WHITE
		c["timbro"].visible = gioc
		if not _in_roulette:
			if not m.in_corsa_dado:
				_accesi_fissi = []
			var acceso: bool = g["uid"] == m.di_turno if m.di_turno != "" else _accesi_fissi.has(g["uid"])
			c["p"].add_theme_stylebox_override("panel", _stile_carta(acceso))

func _accendi(uid: String) -> void:
	for u in giro_carte:
		giro_carte[u]["p"].add_theme_stylebox_override("panel", _stile_carta(u == uid))

## Estrazione del giocatore: la luce corre sui ritratti di chi non ha ancora giocato e si ferma sullo scelto
func roulette_ritratti(m: Motore, scelto: String, suono: Callable) -> void:
	giro_box.visible = true
	var cand := []
	for g in m.giocatori:
		if not m.giro.has(g["uid"]) or g["uid"] == scelto:
			cand.append(g["uid"])
	_in_roulette = true
	_accesi_fissi = []
	if cand.size() > 1:
		var i0 := randi() % cand.size()
		var fine := cand.find(scelto)
		var giri := 7 if cand.size() > 3 else 5
		var passi := giri + ((fine - i0 - giri) % cand.size() + cand.size()) % cand.size()
		for k in passi + 1:
			_accendi(cand[(i0 + k) % cand.size()])
			suono.call()
			await get_tree().create_timer((0.035 + 0.008 * k) / velocita).timeout
	_accendi(scelto)
	_in_roulette = false
	var c: Dictionary = giro_carte.get(scelto, {})
	if not c.is_empty():
		var p: Control = c["p"]
		p.pivot_offset = p.size / 2.0
		var tw := create_tween()
		tw.tween_property(p, "scale", Vector2(1.2, 1.2), 0.1)
		tw.tween_property(p, "scale", Vector2.ONE, 0.15)
	await mostra_banner("TOCCA A " + m.nome_g(scelto).to_upper())

func accendi_molti(uids: Array) -> void:
	_accesi_fissi = uids.duplicate()
	for u in giro_carte:
		giro_carte[u]["p"].add_theme_stylebox_override("panel", _stile_carta(uids.has(u)))

## Estrazione a sorte del giocatore: i nomi girano e rallentano
func roulette(nomi: Array, scelto: String, suono: Callable) -> void:
	banner.visible = true
	banner_sotto.visible = false
	var n := 18
	for i in n:
		var t: String = nomi[(i + randi() % max(1, nomi.size())) % nomi.size()] if i < n - 1 else scelto
		banner_titolo.text = t.to_upper()
		banner.reset_size()
		banner.position.x = size.x / 2.0 - banner.size.x / 2.0 - 120
		suono.call()
		await get_tree().create_timer((0.04 + 0.012 * i * i / 4.0) / velocita).timeout
	banner_titolo.text = "TOCCA A " + scelto.to_upper()
	banner.reset_size()
	banner.position.x = size.x / 2.0 - banner.size.x / 2.0 - 120
	var tw := create_tween()
	banner.pivot_offset = banner.size / 2.0
	tw.tween_property(banner, "scale", Vector2(1.15, 1.15), 0.12)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.18)
	await tw.finished

# ------------------------------------------------------------------ dadi
func _dado_widget(f: Dictionary) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(150, 200)
	var p := Panel.new()
	p.name = "Faccia"
	p.size = Vector2(150, 150)
	p.add_theme_stylebox_override("panel", stile(Color("#fbf6e9"), Color("#3a2a1a"), 26, 5))
	p.pivot_offset = Vector2(75, 75)
	box.add_child(p)
	var l := etichetta("", f_titolo, 84, SCURO)
	l.name = "N"
	_testo_dado(l, f)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 0)
	l.size = Vector2(150, 150)
	p.add_child(l)
	var pallino := Panel.new()
	var sp := StyleBoxFlat.new()
	sp.bg_color = Color("#22b04a")
	sp.set_corner_radius_all(20)
	sp.border_color = Color("#0d5a24")
	sp.set_border_width_all(3)
	pallino.add_theme_stylebox_override("panel", sp)
	pallino.position = Vector2(100, 12)
	pallino.size = Vector2(38, 38)
	pallino.name = "V"
	pallino.visible = f.get("v", false)
	p.add_child(pallino)
	var chi := etichetta("", f_titolo, 32, Color.WHITE, 8, Color.BLACK)
	chi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chi.name = "Chi"
	chi.position = Vector2(-40, 152)
	chi.size = Vector2(230, 44)
	box.add_child(chi)
	return box

func _testo_dado(l: Label, f: Dictionary) -> void:
	if f.get("e", false):
		l.text = "+%d\n-%d" % [f["n"], f["n"]]
		l.add_theme_font_size_override("font_size", 58)
		l.add_theme_constant_override("line_spacing", -14)
	else:
		l.text = "+%d" % f["n"]
		l.add_theme_font_size_override("font_size", 84)

## Dopo il lancio sulla pista il risultato si ingrandisce al centro dello schermo, poi va in alto
func mostra_dadi(facce: Array, _suono: Callable) -> void:
	togli_dadi()
	if facce.is_empty():
		return
	var ws := []
	for f in facce:
		var w := _dado_widget(f)
		dadi_box.add_child(w)
		ws.append(w)
	_dadi_ws = ws
	await get_tree().process_frame
	dadi_box.reset_size()
	var finale := minf(1.0, (size.x - 560.0) / maxf(1.0, dadi_box.size.x))
	var alto_x := size.x / 2.0 - dadi_box.size.x / 2.0 - 120
	var grande := minf(2.0, (size.x - 120.0) / maxf(1.0, dadi_box.size.x))
	dadi_box.set_meta("scala", finale)
	dadi_box.pivot_offset = Vector2(dadi_box.size.x / 2.0, 75)
	dadi_box.position = Vector2(size.x / 2.0 - dadi_box.size.x / 2.0, size.y / 2.0 - 75)
	dadi_box.scale = Vector2(0.2, 0.2)
	dadi_box.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(dadi_box, "scale", Vector2(grande, grande), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dadi_box, "modulate", Color.WHITE, 0.2)
	tw.tween_interval(0.9 / velocita)
	tw.tween_property(dadi_box, "scale", Vector2(finale, finale), 0.4).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(dadi_box, "position", Vector2(alto_x, 190), 0.4).set_trans(Tween.TRANS_CUBIC)
	await tw.finished

## Corsa al dado: il dado preso scende nella fila di sotto con il nome di chi l'ha preso
func dado_preso(i: int, nome: String) -> void:
	if i >= _dadi_ws.size() or not is_instance_valid(_dadi_ws[i]):
		return
	var w: Control = _dadi_ws[i]
	(w.get_node("Chi") as Label).text = nome
	if w.get_parent() == dadi_box:
		dadi_box.remove_child(w)
		presi_box.add_child(w)
	_presi_nome[nome] = w
	w.pivot_offset = Vector2(75, 75)
	w.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(w, "scale", Vector2.ONE, 0.25)
	await _centra(dadi_box)
	await _centra(presi_box)

## Corsa al dado: si illumina il dado di chi sta giocando, gli altri si spengono un po'
func evidenzia_preso(nome: String) -> void:
	for c in presi_box.get_children():
		var su: bool = _presi_nome.get(nome) == c
		c.modulate = Color(1, 1, 1, 1.0 if su else 0.45)
		c.scale = Vector2(1.12, 1.12) if su else Vector2.ONE

func _centra(box: Control) -> void:
	await get_tree().process_frame
	box.reset_size()
	var sc := minf(1.0, (size.x - 560.0) / maxf(1.0, box.size.x))
	box.pivot_offset = Vector2(box.size.x / 2.0, 0)
	box.scale = Vector2(sc, sc)
	box.position.x = size.x / 2.0 - box.size.x / 2.0 - 120

func togli_dadi() -> void:
	dadi_box.scale = Vector2.ONE
	dadi_box.modulate = Color.WHITE
	for c in dadi_box.get_children():
		c.queue_free()
	for c in presi_box.get_children():
		c.queue_free()
	_dadi_ws = []
	_presi_nome = {}

# ------------------------------------------------------------------ cronista
func _crea_avatar() -> void:
	avatar = TextureRect.new()
	avatar.texture = pose["saluta"]
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.anchor_top = 1.0
	avatar.anchor_bottom = 1.0
	avatar.offset_left = 0
	avatar.offset_right = 330
	avatar.offset_top = -420
	avatar.offset_bottom = 0
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avatar)
	fumetto = PanelContainer.new()
	fumetto.add_theme_stylebox_override("panel", stile(Color("#fffdf6"), SCURO, 28, 5))
	fumetto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fumetto.visible = false
	add_child(fumetto)
	testo_fumetto = etichetta("", f_testo, 40, SCURO)
	testo_fumetto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	testo_fumetto.custom_minimum_size = Vector2(200, 0)
	fumetto.add_child(testo_fumetto)

## Le pose si caricano la prima volta che servono (sono tante)
func posa_tex(p: String) -> Texture2D:
	if not pose.has(p):
		if not Dati.TUTTE_POSE.has(p):
			return null
		pose[p] = load("res://assets/avatar/%s.webp" % p)
	return pose[p]

func parla(testo: String, posa: String) -> void:
	var tx := posa_tex(posa)
	avatar.texture = tx if tx else posa_tex("parla")
	fumetto.visible = testo != "" and not sala.visible
	testo_fumetto.text = testo
	var larg := clampf(testo.length() * 18.0, 260.0, maxf(300.0, minf(900.0, get_viewport_rect().size.x - 760.0)))
	testo_fumetto.custom_minimum_size = Vector2(larg, 0)
	fumetto.size = Vector2.ZERO
	_posiziona_fumetto()
	call_deferred("_posiziona_fumetto")
	if _pose_tween:
		_pose_tween.kill()
	avatar.pivot_offset = Vector2(165, 420)
	_pose_tween = create_tween()
	_pose_tween.tween_property(avatar, "scale", Vector2(1.04, 0.97), 0.09)
	_pose_tween.tween_property(avatar, "scale", Vector2.ONE, 0.14)

func _posiziona_fumetto() -> void:
	fumetto.reset_size()
	var vp := get_viewport_rect().size
	var fondo := vp.y - 150.0
	fumetto.position = Vector2(300, fondo - fumetto.size.y)

func zitto() -> void:
	fumetto.visible = false

# ------------------------------------------------------------------ sala d'attesa
func _crea_sala() -> void:
	sala = ColorRect.new()
	(sala as ColorRect).color = Color(0.05, 0.12, 0.06, 0.55)
	sala.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sala)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(CREMA, ROSSO, 30, 8))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.offset_left = 130
	p.offset_right = 130
	p.name = "Pannello"
	sala.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	p.add_child(h)
	var sx := VBoxContainer.new()
	sx.alignment = BoxContainer.ALIGNMENT_CENTER
	sx.add_theme_constant_override("separation", 8)
	h.add_child(sx)
	var t := etichetta("INQUADRA E GIOCA!", f_titolo, 50, ROSSO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sx.add_child(t)
	sala_qr = TextureRect.new()
	sala_qr.custom_minimum_size = Vector2(400, 400)
	sala_qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sala_qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sala_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sx.add_child(sala_qr)
	sala_codice = etichetta("----", f_titolo, 96, SCURO)
	sala_codice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sx.add_child(sala_codice)
	sala_url = etichetta("", f_medio, 24, Color("#6b4a2a"))
	sala_url.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sala_url.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	sala_url.custom_minimum_size = Vector2(420, 0)
	sx.add_child(sala_url)
	var dx := VBoxContainer.new()
	dx.add_theme_constant_override("separation", 12)
	dx.custom_minimum_size = Vector2(640, 0)
	h.add_child(dx)
	sala_conteggio = etichetta("Giocatori: 0 di 10", f_titolo, 44, ROSSO)
	dx.add_child(sala_conteggio)
	sala_giocatori = GridContainer.new()
	sala_giocatori.columns = 2
	sala_giocatori.custom_minimum_size = Vector2(620, 110)
	sala_giocatori.add_theme_constant_override("h_separation", 14)
	sala_giocatori.add_theme_constant_override("v_separation", 8)
	dx.add_child(sala_giocatori)
	dx.add_child(HSeparator.new())
	dx.add_child(etichetta("REGOLE DELLA CASA", f_titolo, 34, ROSSO))
	_opzione(dx, "versione", "Token o carte", [["token", "token"], ["carte", "carte"]], "token")
	_opzione(dx, "pista", "Pista", [["corta", 2], ["media", 4], ["lunga", 6]], 4)
	_opzione(dx, "posta", "Posta a testa", [["15 euro", 15.0], ["10 euro", 10.0], ["3 euro", 3.0], ["1,50 euro", 1.5], ["per gioco", 0.0]], 15.0)
	_opzione(dx, "corsa_dado", "Corsa al dado", [["sì", true], ["no", false]], true)
	_opzione(dx, "cattiva", "Effetto multiplo", [["no", false], ["sì, versione cattiva", true]], false)
	_opzione(dx, "velocita", "Velocità di gioco", [["lenta", 0.7], ["normale", 1.0], ["veloce", 1.8]], 1.0)
	var rs := HBoxContainer.new()
	rs.add_theme_constant_override("separation", 8)
	var ls := etichetta("Sacchetto", f_testo, 28, SCURO)
	ls.custom_minimum_size = Vector2(200, 0)
	rs.add_child(ls)
	bt_sacchetto = bottone("Modifica sacchetto (20 token)", 24, Color("#a08c74"))
	bt_sacchetto.pressed.connect(func():
		if _versione == "carte":
			mazzo_box.visible = true
		else:
			sacchetto_box.visible = true)
	rs.add_child(bt_sacchetto)
	dx.add_child(rs)
	_crea_sacchetto()
	_crea_mazzo()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	dx.add_child(hb)
	sala_parti = bottone("NUOVA CORSA!", 50, Color("#1d7a3a"))
	sala_parti.custom_minimum_size = Vector2(320, 90)
	sala_parti.disabled = true
	sala_parti.pressed.connect(func(): comando.emit("parti", null))
	hb.add_child(sala_parti)
	sala_riprendi = bottone("RIPRENDI", 36, Color("#3d5a80"))
	sala_riprendi.custom_minimum_size = Vector2(0, 90)
	sala_riprendi.visible = false
	sala_riprendi.pressed.connect(func(): comando.emit("riprendi", null))
	hb.add_child(sala_riprendi)
	sala_bot = bottone("+ giocatore finto", 26, Color("#7a6a5a"))
	sala_bot.pressed.connect(func(): comando.emit("bot", null))
	hb.add_child(sala_bot)
	sala_togli = bottone("Togli i finti", 26, Color("#7a6a5a"))
	sala_togli.pressed.connect(func(): comando.emit("togli_bot", null))
	hb.add_child(sala_togli)

func _opzione(dove: Control, chiave: String, titolo: String, valori: Array, iniziale) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := etichetta(titolo, f_testo, 28, SCURO)
	l.custom_minimum_size = Vector2(200, 0)
	r.add_child(l)
	var bs := []
	for v in valori:
		var b := bottone(v[0], 24, Color("#a08c74"))
		b.toggle_mode = true
		b.set_meta("valore", v[1])
		b.add_theme_stylebox_override("pressed", stile(ROSSO, ROSSO.darkened(0.4), 14, 4))
		b.button_pressed = v[1] == iniziale
		b.pressed.connect(func():
			for x in bs:
				x.button_pressed = x == b
			comando.emit("opzione", [chiave, v[1]]))
		bs.append(b)
		r.add_child(b)
	sala_opzioni[chiave] = bs
	dove.add_child(r)

## Finestra per scegliere quanti token di ogni tipo ci sono nel sacchetto
func _crea_sacchetto() -> void:
	sacchetto_box = ColorRect.new()
	(sacchetto_box as ColorRect).color = Color(0, 0, 0, 0.5)
	sacchetto_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	sacchetto_box.visible = false
	sala.add_child(sacchetto_box)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(CREMA, ROSSO, 26, 7))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	sacchetto_box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := etichetta("I TOKEN NEL SACCHETTO", f_titolo, 46, ROSSO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for tipo in Dati.TOKEN:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/token/%s.png" % tipo)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(54, 54)
		r.add_child(ic)
		var n := etichetta(Dati.TOKEN[tipo]["nome"], f_testo, 28, SCURO)
		n.custom_minimum_size = Vector2(190, 0)
		r.add_child(n)
		var meno := bottone("-", 30, Color("#a08c74"))
		meno.custom_minimum_size = Vector2(54, 50)
		meno.pressed.connect(func(): comando.emit("sacchetto", [tipo, -1]))
		r.add_child(meno)
		var q := etichetta("0", f_titolo, 36, SCURO)
		q.custom_minimum_size = Vector2(44, 0)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(q)
		var piu := bottone("+", 30, Color("#a08c74"))
		piu.custom_minimum_size = Vector2(54, 50)
		piu.pressed.connect(func(): comando.emit("sacchetto", [tipo, 1]))
		r.add_child(piu)
		g.add_child(r)
		sacchetto_righe[tipo] = q
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	var rip := bottone("Come nel gioco", 28, Color("#7a6a5a"))
	rip.pressed.connect(func(): comando.emit("sacchetto", ["", 0]))
	hb.add_child(rip)
	var ok := bottone("FATTO", 36, Color("#1d7a3a"))
	ok.pressed.connect(func(): sacchetto_box.visible = false)
	hb.add_child(ok)
	v.add_child(hb)

func aggiorna_sacchetto(m: Motore) -> void:
	var tot := 0
	for tipo in Dati.TOKEN:
		var q := m.quanti_token(tipo)
		tot += q
		(sacchetto_righe[tipo] as Label).text = str(q)
	_sacchetto_testo = "Modifica sacchetto (%d token)" % tot
	mostra_opzioni_versione(_versione)

## Con le carte non servono le opzioni dei token (sacchetto, token sulla pista)
func mostra_opzioni_versione(v: String) -> void:
	_versione = v
	var ls: Label = bt_sacchetto.get_parent().get_child(0)
	ls.text = "Carte" if v == "carte" else "Sacchetto"
	bt_sacchetto.text = _mazzo_testo if v == "carte" else _sacchetto_testo

## Finestra per scegliere quali delle 32 carte ci sono nel mazzo
func _crea_mazzo() -> void:
	mazzo_box = ColorRect.new()
	(mazzo_box as ColorRect).color = Color(0, 0, 0, 0.5)
	mazzo_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	mazzo_box.visible = false
	sala.add_child(mazzo_box)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(CREMA, ROSSO, 26, 7))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	mazzo_box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var t := etichetta("LE CARTE NEL MAZZO (tocca per togliere o rimettere)", f_titolo, 38, ROSSO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var g := GridContainer.new()
	g.columns = 11
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for k in Dati.CARTE.size():
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/carte/c%02d.webp" % (k + 1))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(108, 166)
		b.pressed.connect(func(): comando.emit("carta", k))
		g.add_child(b)
		mazzo_bottoni.append(b)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	var tutte := bottone("Tutte le carte", 28, Color("#7a6a5a"))
	tutte.pressed.connect(func(): comando.emit("carta", -1))
	hb.add_child(tutte)
	var ok := bottone("FATTO", 36, Color("#1d7a3a"))
	ok.pressed.connect(func(): mazzo_box.visible = false)
	hb.add_child(ok)
	v.add_child(hb)

func aggiorna_mazzo(m: Motore) -> void:
	var escl: Array = m.cfg.get("carte_escluse", [])
	for k in mazzo_bottoni.size():
		mazzo_bottoni[k].modulate = Color(1, 1, 1, 0.25) if escl.has(k) else Color.WHITE
	_mazzo_testo = "Modifica carte (%d nel mazzo)" % (Dati.CARTE.size() - escl.size())
	mostra_opzioni_versione(_versione)

## La carta pescata (o quella che si attiva da sotto la pista) compare grande sullo schermo
func mostra_carta(k: int, sotto: bool) -> void:
	var t := TextureRect.new()
	t.texture = load("res://assets/carte/%s%02d.webp" % ["s" if sotto else "c", k + 1])
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var vp := get_viewport_rect().size
	var sz := Vector2(560, 268) if sotto else Vector2(340, 524)
	t.size = sz
	t.pivot_offset = sz / 2.0
	t.position = Vector2(vp.x / 2.0 - sz.x / 2.0 - 120, vp.y / 2.0 - sz.y / 2.0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.scale = Vector2(0.1, 0.1)
	add_child(t)
	var tw := create_tween()
	tw.tween_property(t, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2 / velocita)
	tw.tween_property(t, "scale", Vector2(0.05, 0.05), 0.25)
	tw.tween_callback(t.queue_free)
	await get_tree().create_timer(0.8 / velocita).timeout

func imposta_opzione(chiave: String, valore) -> void:
	for b in sala_opzioni.get(chiave, []):
		b.button_pressed = b.get_meta("valore") == valore

func mostra_sala(si: bool) -> void:
	sala.visible = si
	if si:
		fumetto.visible = false
	pannello_destra.visible = not si
	titolo_img.visible = true

func imposta_qr(bits: String, n: int, codice: String, url: String) -> void:
	sala_codice.text = codice
	sala_url.text = url
	if n <= 0:
		sala_qr.texture = null
		return
	var bordo := 3
	var img := Image.create(n + bordo * 2, n + bordo * 2, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in n:
		for x in n:
			if bits[y * n + x] == "1":
				img.set_pixel(x + bordo, y + bordo, SCURO)
	sala_qr.texture = ImageTexture.create_from_image(img)

func aggiorna_sala(m: Motore) -> void:
	for c in sala_giocatori.get_children():
		c.queue_free()
	for g in m.giocatori:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", stile(Color("#fff"), Color("#d9c39a"), 14, 3, false))
		p.custom_minimum_size = Vector2(300, 0)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var t := TextureRect.new()
		t.texture = tex_ritratto(g.get("ritratto", ""))
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.custom_minimum_size = Vector2(46, 46)
		h.add_child(t)
		var l := etichetta(g["nome"] + (" (finto)" if g["bot"] else ""), f_testo, 26, SCURO)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		p.add_child(h)
		sala_giocatori.add_child(p)
	sala_conteggio.text = "Giocatori: %d di %d" % [m.giocatori.size(), Motore.MAX_GIOCATORI]
	sala_parti.disabled = m.giocatori.size() < 2

# ------------------------------------------------------------------ pile
func _crea_pile() -> void:
	pile_box = PanelContainer.new()
	pile_box.add_theme_stylebox_override("panel", stile(Color(1.0, 0.96, 0.84, 0.96), ROSSO, 24, 6))
	pile_box.anchor_left = 0.5
	pile_box.anchor_right = 0.5
	pile_box.anchor_top = 0.5
	pile_box.anchor_bottom = 0.5
	pile_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pile_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	pile_box.visible = false
	pile_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pile_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pile_box.add_child(v)
	var t := etichetta("SCEGLIETE LA PILA DI TALLONCINI", f_titolo, 50, ROSSO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 18)
	v.add_child(g)
	g.columns = 5
	for i in 10:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(230, 150)
		p.add_theme_stylebox_override("panel", stile(Color("#f7e2b0"), Color("#8a5a2a"), 16, 4))
		var vv := VBoxContainer.new()
		vv.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(vv)
		var l := etichetta("PILA " + Dati.LETTERE_PILE[i], f_titolo, 46, SCURO)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vv.add_child(l)
		var chi := etichetta("libera", f_testo, 30, Color("#8a7a6a"))
		chi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vv.add_child(chi)
		g.add_child(p)
		pile_celle.append({"p": p, "chi": chi})

func mostra_pile(m: Motore) -> void:
	pile_box.visible = true
	for i in 10:
		pile_celle[i]["p"].visible = i < m.pile.size()
	for i in m.pile.size():
		pile_celle[i]["chi"].text = "libera"
		pile_celle[i]["chi"].add_theme_color_override("font_color", Color("#8a7a6a"))
		pile_celle[i]["p"].add_theme_stylebox_override("panel", stile(Color("#f7e2b0"), Color("#8a5a2a"), 16, 4))
	for g in m.giocatori:
		if g["pila"] >= 0:
			pila_presa(g["pila"], g["nome"])

func pila_presa(i: int, nome: String) -> void:
	pile_celle[i]["chi"].text = nome
	pile_celle[i]["chi"].add_theme_color_override("font_color", Color.WHITE)
	pile_celle[i]["p"].add_theme_stylebox_override("panel", stile(ROSSO, Color("#5a0a0a"), 16, 4))
	var p: Control = pile_celle[i]["p"]
	p.pivot_offset = p.size / 2.0
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(1.12, 1.12), 0.1)
	tw.tween_property(p, "scale", Vector2.ONE, 0.15)

func nascondi_pile() -> void:
	pile_box.visible = false

# ------------------------------------------------------------------ risultati
func mostra_risultati(m: Motore, ris: Array, rivela_fino: int) -> void:
	for c in finale.get_children():
		c.queue_free()
	finale.visible = true
	var sfondo := ColorRect.new()
	sfondo.color = Color(0, 0, 0, 0.45)
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	finale.add_child(sfondo)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(CREMA, ROSSO, 30, 8))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	finale.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var w := m.vincitore
	var tt := HBoxContainer.new()
	tt.alignment = BoxContainer.ALIGNMENT_CENTER
	tt.add_theme_constant_override("separation", 18)
	var cr := ColorRect.new()
	cr.color = Dati.colore(w)
	cr.custom_minimum_size = Vector2(56, 56)
	cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tt.add_child(cr)
	tt.add_child(etichetta("HA VINTO " + Dati.nome(w).to_upper() + "!", f_titolo, 72, ROSSO))
	v.add_child(tt)
	var q := "Ogni quota vale " + m.euro(m.quota_euro()) if m.cfg["posta"] > 0 else "Si gioca per la gloria: contano le quote"
	var sub := etichetta(q, f_testo, 30, Color("#6b4a2a"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 34)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	for h in ["GIOCATORE", "TALLONCINI DI " + Dati.nome(w).to_upper(), "QUOTE", "VINCITA", "SALDO SERATA"]:
		g.add_child(etichetta(h, f_titolo, 28, ROSSO))
	for i in ris.size():
		var r: Dictionary = ris[i]
		var gg := m.trova(r["uid"])
		var vis := i < rivela_fino
		var hn := HBoxContainer.new()
		hn.add_theme_constant_override("separation", 8)
		var tr := TextureRect.new()
		tr.texture = tex_ritratto(gg.get("ritratto", ""))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(42, 42)
		hn.add_child(tr)
		hn.add_child(etichetta(r["nome"], f_testo, 30, SCURO))
		g.add_child(hn)
		var tal := HBoxContainer.new()
		tal.add_theme_constant_override("separation", 6)
		if vis:
			var ce := false
			for t in r["talloncini"]:
				if t["c"] == w:
					ce = true
					var pt := PanelContainer.new()
					pt.add_theme_stylebox_override("panel", stile(Dati.colore(w), Color.BLACK, 8, 2, false))
					pt.add_child(etichetta(str(t["q"]), f_titolo, 30, Color.WHITE, 6, Color.BLACK))
					tal.add_child(pt)
			if not ce:
				tal.add_child(etichetta("nessuno", f_medio, 30, Color("#8a7a6a")))
		else:
			tal.add_child(etichetta("...", f_titolo, 30, Color("#8a7a6a")))
		g.add_child(tal)
		g.add_child(etichetta(str(r["quote"]) if vis else "", f_titolo, 34, SCURO))
		var vin := etichetta((m.euro(r["premio"]) if m.cfg["posta"] > 0 else "-") if vis and r["quote"] > 0 else ("" if not vis else "-"), f_titolo, 34, Color("#1d7a3a"))
		g.add_child(vin)
		var sal: float = gg.get("saldo", 0.0)
		var sl := etichetta(((("+" if sal > 0 else "-" if sal < 0 else "") + m.euro(absf(sal))) if m.cfg["posta"] > 0 else "") if vis else "", f_testo, 32, Color("#1d7a3a") if sal >= 0 else ROSSO)
		g.add_child(sl)
	if rivela_fino >= ris.size():
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 30)
		var b1 := bottone("UN'ALTRA CORSA!", 44, Color("#1d7a3a"))
		b1.pressed.connect(func(): comando.emit("altra", null))
		hb.add_child(b1)
		var b2 := bottone("Torna alla sala", 30, Color("#7a6a5a"))
		b2.pressed.connect(func(): comando.emit("sala", null))
		hb.add_child(b2)
		v.add_child(hb)

func nascondi_risultati() -> void:
	finale.visible = false
	for c in finale.get_children():
		c.queue_free()

## Coriandoli quando si vince
func coriandoli() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x / 2.0, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x / 2.0, 10)
	p.amount = 260
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 0.8
	p.direction = Vector2(0, 1)
	p.spread = 25
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 80
	p.initial_velocity_max = 260
	p.angular_velocity_min = -300
	p.angular_velocity_max = 300
	p.scale_amount_min = 6
	p.scale_amount_max = 12
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#e63946"), Color("#ffd166"), Color("#06d6a0"), Color("#118ab2"), Color("#f15bb5")])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(5.0).timeout.connect(p.queue_free)

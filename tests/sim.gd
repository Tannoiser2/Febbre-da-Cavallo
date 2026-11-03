extends SceneTree
## Simulazione: tante corse con giocatori automatici, controlla che le regole non si rompano.
## godot --headless --path . -s tests/sim.gd -- 200

func _init() -> void:
	var n := 100
	var args := OS.get_cmdline_user_args()
	if args.size():
		n = int(args[0])
	# controlli sulla pista
	for r in [2, 4, 6]:
		var p := Pista.new(r)
		var tot := []
		for l in 3:
			tot.append(p.corsie[l].size())
		print("pista %d rettilinei: caselle per corsia %s, lunghezza %.1f" % [r, str(tot), p.lunghezza])
		for c in p.celle:
			assert(p.adiacenti[c["id"]].size() >= 2, "casella isolata")
	# un giocatore per giro: in ogni blocco di 4 estrazioni escono tutti e 4
	var mg := Motore.new()
	for g in 4:
		mg.aggiungi_giocatore("p%d" % g, "P%d" % g)
	for blocco in 30:
		var visti := {}
		for k in 4:
			var u := mg.estrai_giocatore()
			mg.giro.append(u)
			mg.ultimo_uid = u
			assert(not visti.has(u), "giocatore ripetuto nel giro")
			if visti.has(u):
				_err += 1
			visti[u] = true
	print("giri senza ripetizioni: ok")
	var turni := []
	var vinc := {}
	var errori := 0
	for i in n:
		var m := Motore.new()
		m.cfg["rettilinei"] = [2, 4, 6][i % 3]
		m.cfg["token_sempre"] = i % 2 == 0
		m.cfg["cattiva"] = i % 4 < 2
		if i % 5 == 0:
			m.cfg["sacchetto"] = {"piu3": 4, "indietro": 4, "tre": 3, "azzoppato": 3, "allarme": 0}
		m.v = VistaVuota.new()
		var io := IOBot.new()
		io.motore = m
		m.io = io
		var ng := 2 + i % 7
		for g in ng:
			m.aggiungi_giocatore("g%d" % g, "Gioc%d" % g, true)
		m.cambiato.connect(func(): _controlla(m))
		await m.gioca_corsa()
		if m.vincitore < 0:
			errori += 1
			print("corsa %d senza vincitore" % i)
		turni.append([m.cfg["rettilinei"], m.n_turno])
		vinc[m.vincitore] = vinc.get(m.vincitore, 0) + 1
		var tot_q := 0
		for r in m.risultati:
			tot_q += r["quote"]
		assert(tot_q <= 15)
	for r in [2, 4, 6]:
		var l := turni.filter(func(x): return x[0] == r).map(func(x): return x[1])
		if l.size():
			var s := 0
			for x in l:
				s += x
			print("rettilinei %d: turni medi %.1f (min %d, max %d)" % [r, float(s) / l.size(), l.min(), l.max()])
	print("vittorie per cavallo: ", vinc)
	print("ERRORI: %d" % (errori + _err))
	quit(1 if errori + _err else 0)

var _err := 0
func _controlla(m: Motore) -> void:
	if m.fase != "corsa":
		return
	var occ := {}
	for c in m.cavalli:
		if c["cella"] >= 0 and not c["zoppo"]:
			if occ.has(c["cella"]):
				_err += 1
				print("due cavalli sulla casella ", c["cella"], " ", m.registro.slice(-6))
			occ[c["cella"]] = true
	var n: int = m.sacchetto.size() + m.token.size() + m.in_mano
	if n != m.sacchetto_iniziale().size():
		_err += 1
		print("token: %d invece di %d " % [n, m.sacchetto_iniziale().size()], m.registro.slice(-4))

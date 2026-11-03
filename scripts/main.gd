extends Node
## La TV dell'ippodromo: crea la stanza, accoglie i telefoni, fa girare le corse.
## Parametri dell'indirizzo (per le prove): ?bot=3 giocatori finti, ?auto=1 parte e continua da solo,
## ?veloce=4 animazioni più rapide, ?rete=locale telefoni nello stesso browser (senza Firebase).

var m: Motore
var ip: Ippodromo
var ui: Interfaccia
var rete: Rete
var vista: Vista
var veloce := 1.0
var params := {}
var auto := false
var _domanda := {}
var _risposta := {}
var _forza := false
var _sporco := false
var _t_invio := 0.0
var _scelta_fine := ""
var _in_gioco := false
var _n_bot := 0
var _frase := ""
var _salvata := ""

func _ready() -> void:
	randomize()
	ip = Ippodromo.new()
	add_child(ip)
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Interfaccia.new()
	cl.add_child(ui)
	rete = Rete.new()
	add_child(rete)
	m = Motore.new()
	vista = Vista.new(self)
	m.v = vista
	m.io = self
	m.cambiato.connect(func(): _sporco = true)
	rete.evento.connect(_evento)
	ui.comando.connect(_comando)
	ip.spostamento_ui = Vector2(0.1, 0.12)
	await get_tree().process_frame
	params = rete.parametri()
	veloce = maxf(1.0, float(params.get("veloce", "1")))
	auto = params.get("auto", "") != ""
	if params.has("pista"):
		m.cfg["rettilinei"] = int(params["pista"])
		ui.imposta_opzione("pista", int(params["pista"]))
	ui.mostra_sala(true)
	ui.aggiorna_sala(m)
	ui.aggiorna_classifica(m)
	if rete.web:
		_salvata = rete.carica("fdc_partita")
		var cod := ""
		if _salvata != "":
			var s = JSON.parse_string(_salvata)
			if s is Dictionary and s.get("fase", "") == "corsa":
				cod = s.get("codice", "")
			else:
				_salvata = ""
		rete.avvia(cod)
		if _salvata != "":
			ui.sala_parti.text = "RIPRENDI LA CORSA"
	else:
		ui.imposta_qr("", 0, "PROVA", "Versione di prova sul computer: aggiungi i giocatori finti")
	for i in int(params.get("bot", "0")):
		_aggiungi_bot()
	vista.dici(Dati.frase("benvenuto"), "saluta")

func _aggiungi_bot() -> void:
	_n_bot += 1
	var nomi := ["Mandrake", "Pomata", "Felice", "Gabriella", "Zia Rosa", "Nonno Pino", "Cugino Ugo", "Marisa"]
	m.aggiungi_giocatore("bot%d" % _n_bot, nomi[(_n_bot - 1) % nomi.size()], true)
	ui.aggiorna_sala(m)

# ------------------------------------------------------------------ eventi dalla pagina
func _evento(e: Dictionary) -> void:
	match e.get("e", ""):
		"stanza":
			var bits := rete.qr(e["url"])
			var n := int(sqrt(bits.length()))
			ui.imposta_qr(bits, n, e["codice"], e["url"])
			_sporco = true
		"entra":
			var uid: String = e["uid"]
			var nome: String = str(e.get("nome", "")).strip_edges().substr(0, 16)
			if nome == "":
				return
			var nuovo := m.aggiungi_giocatore(uid, nome)
			ui.aggiorna_sala(m)
			if nuovo:
				rete.suono("ding")
				vista.dici(Dati.frase("arriva", {"g": nome}), "saluta")
			invia_segreto(uid)
			_sporco = true
		"esce":
			m.togli_giocatore(e["uid"])
			ui.aggiorna_sala(m)
		"azione":
			_azione(e["uid"], e)
		"errore":
			ui.imposta_qr("", 0, "OPS", "Non riesco a collegarmi: " + str(e.get("msg", "")))

func _azione(uid: String, e: Dictionary) -> void:
	if _domanda.is_empty() or not _risposta.is_empty():
		return
	if int(e.get("p", -1)) != int(_domanda["id"]):
		return
	if not _domanda["per"].has(uid):
		return
	for o in _domanda["opzioni"]:
		if str(o["k"]) == str(e.get("k")) and o["ok"]:
			_risposta = {"uid": uid, "k": o["k"]}
			return

# ------------------------------------------------------------------ comandi della TV
func _comando(nome: String, valore) -> void:
	match nome:
		"parti":
			if _salvata != "":
				_riprendi()
			elif m.giocatori.size() >= 2 and not _in_gioco:
				_gioca()
		"bot":
			if m.fase == "attesa":
				_aggiungi_bot()
		"opzione":
			var k: String = valore[0]
			var v = valore[1]
			match k:
				"pista":
					m.cfg["rettilinei"] = int(v)
					m.pista = Pista.new(int(v))
					ip.costruisci(m.pista)
				"posta":
					m.cfg["posta"] = float(v)
				"token":
					m.cfg["token_sempre"] = bool(v)
				"corsa_dado":
					m.cfg["corsa_dado"] = bool(v)
			_sporco = true
			ui.aggiorna_classifica(m)
		"voce":
			vista.voce_attiva = not vista.voce_attiva
			rete.voce(vista.voce_attiva)
			ui.bt_voce.text = "Voce: " + ("sì" if vista.voce_attiva else "no")
		"schermo":
			rete.schermo_intero()
		"decidi":
			_forza = true
		"altra":
			_scelta_fine = "altra"
		"sala":
			_scelta_fine = "sala"

func _gioca() -> void:
	_in_gioco = true
	_salvata = ""
	ui.mostra_sala(false)
	while true:
		await m.gioca_corsa()
		rete.salva("fdc_partita", "")
		if not await _dopo_corsa():
			break
	_in_gioco = false

func _riprendi() -> void:
	var s = JSON.parse_string(_salvata)
	_salvata = ""
	ui.sala_parti.text = "SI PARTE!"
	if not (s is Dictionary):
		return
	_in_gioco = true
	m.carica(s["motore"])
	ip.costruisci(m.pista)
	ui.mostra_sala(false)
	invia_tutti_i_segreti()
	await vista.dici("Si riprende la corsa da dove eravamo rimasti!", "occhiolino")
	await m.riprendi_corsa()
	rete.salva("fdc_partita", "")
	if await _dopo_corsa():
		while true:
			await m.gioca_corsa()
			if not await _dopo_corsa():
				break
	_in_gioco = false

## true = un'altra corsa, false = torna alla sala d'attesa
func _dopo_corsa() -> bool:
	_scelta_fine = ""
	var t0 := Time.get_ticks_msec()
	while _scelta_fine == "":
		await get_tree().process_frame
		if auto and Time.get_ticks_msec() - t0 > 4000:
			_scelta_fine = "altra"
	ui.nascondi_risultati()
	ui.mostra_banner("")
	if _scelta_fine == "sala":
		m.fase = "attesa"
		ui.mostra_sala(true)
		ui.aggiorna_sala(m)
		_sporco = true
		return false
	return true

# ------------------------------------------------------------------ domande (io del motore)
func chiedi(d: Dictionary) -> Dictionary:
	_domanda = d
	_risposta = {}
	_forza = false
	vista.mostra_domanda(d)
	_sporco = true
	var corsa: bool = d.get("corsa", false)
	for uid in d["per"]:
		var g := m.trova(uid)
		if g.get("bot", false):
			var ritardo := randf_range(0.4, 1.4) if corsa else randf_range(0.7, 1.8)
			get_tree().create_timer(ritardo / veloce).timeout.connect(_risposta_bot.bind(d["id"], uid))
	var t0 := Time.get_ticks_msec()
	var sollecito := false
	var limite := 25.0 if corsa else 90.0
	while _risposta.is_empty():
		await get_tree().process_frame
		var passato := (Time.get_ticks_msec() - t0) / 1000.0
		if not sollecito and passato > limite * 0.5 and d["tipo"] != "pila":
			sollecito = true
			vista.dici(Dati.frase("aspetta", {"g": m.nome_g(d["per"][0])}), "pensa")
		if _forza or passato > limite or (auto and passato > 8.0):
			var uid: String = d["per"][randi() % d["per"].size()]
			_risposta = {"uid": uid, "k": m.scelta_automatica(d, uid)}
			if _forza or passato > limite:
				vista.dici(Dati.frase("ci_penso_io", {"g": m.nome_g(uid)}), "occhiolino")
	var r := _risposta
	_domanda = {}
	_risposta = {}
	vista.togli_domanda()
	rete.suono("click")
	return r

func _risposta_bot(id: int, uid: String) -> void:
	if _domanda.is_empty() or int(_domanda["id"]) != id or not _risposta.is_empty():
		return
	if not _domanda["per"].has(uid):
		return
	_risposta = {"uid": uid, "k": m.scelta_automatica(_domanda, uid)}

# ------------------------------------------------------------------ verso i telefoni
func frase_per_telefoni(t: String) -> void:
	_frase = t
	_sporco = true

func invia_segreto(uid: String) -> void:
	rete.segreto(uid, m.segreto(uid))

func invia_tutti_i_segreti() -> void:
	for g in m.giocatori:
		if not g["bot"]:
			invia_segreto(g["uid"])

func _process(delta: float) -> void:
	if auto and not _in_gioco and m.fase == "attesa" and _salvata == "" and m.giocatori.size() >= int(params.get("parti", "3")):
		_gioca()
	_t_invio -= delta
	if _sporco and _t_invio <= 0.0:
		_sporco = false
		_t_invio = 0.12
		var s := m.stato_pubblico()
		s["frase"] = _frase
		s["codice"] = rete.codice
		rete.stato(s)
		if m.fase == "corsa" and _domanda.is_empty():
			_salva_punto()
		if m.fase != "attesa" and ui.sala.visible:
			ui.mostra_sala(false)
		if m.fase == "corsa" and m.di_turno == "" and _domanda.is_empty() and m.n_turno > 0:
			ui.togli_dadi()
			if ui.banner.visible and not ui.banner_titolo.text.begins_with("CORSA"):
				ui.mostra_banner("")

var _ultimo_turno_salvato := -1
func _salva_punto() -> void:
	if not rete.web or m.n_turno == _ultimo_turno_salvato or m.di_turno != "":
		return
	_ultimo_turno_salvato = m.n_turno
	var s := {"fase": "corsa", "codice": rete.codice, "motore": m.salva()}
	rete.salva("fdc_partita", JSON.stringify(s))

class_name Motore
extends RefCounted
## Regole di Febbre da Cavallo. Il motore non disegna e non parla con la rete:
## - "v" (la vista) anima e commenta: ogni metodo può essere atteso con await;
## - "io" fa le domande ai giocatori: io.chiedi(domanda) restituisce {"uid", "k"}.
## Così lo stesso motore gira sulla TV e nei test automatici senza grafica.

signal cambiato   # lo stato pubblico è cambiato (da mandare ai telefoni)

const MAX_GIOCATORI := 10

var pista: Pista
var v = null
var io = null

# impostazioni della casa
var cfg := {
	"rettilinei": 4,        # 2 = corta, 4 = media, 6 = lunga
	"posta": 15.0,          # euro a testa per corsa
	"token_sempre": false,  # true: i token sulla pista scattano anche senza pallino verde
	"corsa_dado": true,     # a volte più dadi e corsa a prenderli
	"cattiva": false,       # effetto multiplo: se un token porta il cavallo su un altro token, scatta anche quello
	"sacchetto": {},        # quanti token di ogni tipo (vuoto = quelli del gioco)
}

# stato
var fase := "attesa"        # attesa, pile, corsa, svela, fine
var giocatori := []         # {uid, nome, bot, pila, turni, saldo, vinto}
var cavalli := []           # {id, cella, attivo, zoppo, cella_zoppo}
var token := {}             # cella -> tipo
var sacchetto := []
var pile := []              # una pila per giocatore: tutti i 40 talloncini {c: cavallo, q: quota}
var vincitore := -1
var n_corsa := 0
var n_turno := 0
var salta_prossimo := false
var in_corsa_dado := false
var corsa_per_tutti := false   # il "?" chiede la corsa al dado per tutti i giocatori, alla fine del turno
var cella_interrogativo := -1
var _quasi := {}             # cavalli già annunciati vicino al traguardo  # dove sta il "?" che ha chiesto la corsa (torna nel sacchetto dopo la corsa)
var giro := []              # chi ha già giocato in questo giro (si ricomincia quando hanno giocato tutti)
var ultimo_uid := ""
var di_turno := ""          # uid di chi sta giocando ora
var dado_attuale := []      # facce in mostra
var domanda := {}           # domanda in corso (per i telefoni)
var risultati := []         # alla fine: {uid, nome, quote, premio, talloncini}
var _pid := 0
var registro := []          # ultime cose successe (per i test)
var in_mano := 0            # token pescato non ancora rimesso a posto (per i controlli dei test)

func _init() -> void:
	pista = Pista.new(cfg["rettilinei"])
	for i in 8:
		cavalli.append({"id": i, "cella": Pista.PARTENZA, "attivo": true, "zoppo": false, "cella_zoppo": -1})

# ------------------------------------------------------------------ giocatori
func trova(uid: String) -> Dictionary:
	for g in giocatori:
		if g["uid"] == uid:
			return g
	return {}

func nome_g(uid: String) -> String:
	var g := trova(uid)
	return g.get("nome", "?")

## Un ritratto libero: quello chiesto se nessun altro l'ha preso, altrimenti il primo libero
func ritratto_libero(chiesto: String, uid := "") -> String:
	var presi := {}
	for g in giocatori:
		if g["uid"] != uid:
			presi[g.get("ritratto", "")] = true
	if chiesto != "" and Dati.nome_ritratto(chiesto) != "" and not presi.has(chiesto):
		return chiesto
	for r in Dati.RITRATTI:
		if not presi.has(r["id"]):
			return r["id"]
	return ""

func _nome_completo(base: String, ritratto: String) -> String:
	var r := Dati.nome_ritratto(ritratto)
	return base if r == "" or r == base else "%s (%s)" % [base, r]

func aggiungi_giocatore(uid: String, nome: String, bot := false, ritratto := "") -> bool:
	var g := trova(uid)
	if not g.is_empty():
		if fase == "attesa":
			g["ritratto"] = ritratto_libero(ritratto if ritratto != "" else g.get("ritratto", ""), uid)
		g["base"] = nome
		g["nome"] = _nome_completo(nome, g.get("ritratto", ""))
		cambiato.emit()
		return false
	if giocatori.size() >= MAX_GIOCATORI or fase != "attesa":
		return false
	var rt := ritratto_libero(ritratto, uid)
	giocatori.append({"uid": uid, "nome": _nome_completo(nome, rt), "base": nome, "ritratto": rt, "bot": bot,
		"pila": -1, "turni": 0, "saldo": 0.0, "vinto": 0.0})
	cambiato.emit()
	return true

func togli_giocatore(uid: String) -> void:
	if fase != "attesa":
		return
	for i in giocatori.size():
		if giocatori[i]["uid"] == uid:
			giocatori.remove_at(i)
			cambiato.emit()
			return

# ------------------------------------------------------------------ preparazione
func prepara_corsa() -> void:
	pista = Pista.new(cfg["rettilinei"])
	cavalli = []
	for i in 8:
		cavalli.append({"id": i, "cella": Pista.PARTENZA, "attivo": true, "zoppo": false, "cella_zoppo": -1})
	token = {}
	sacchetto = sacchetto_iniziale()
	sacchetto.shuffle()
	vincitore = -1
	n_turno = 0
	salta_prossimo = false
	ultimo_uid = ""
	giro = []
	_quasi = {}
	corsa_per_tutti = false
	di_turno = ""
	dado_attuale = []
	risultati = []
	for g in giocatori:
		g["pila"] = -1
		g["turni"] = 0
	pile = distribuisci_talloncini(max(2, giocatori.size()))

## Tutti i 40 talloncini (8 cavalli x quote da 1 a 5) divisi in tante pile quanti sono i giocatori,
## con lo stesso valore totale in ogni pila (più o meno uno). Così su ogni cavallo ci sono sempre 15 quote
## in mano ai giocatori e chi vince si divide tutto il montepremi, qualunque sia il cavallo vincente.
func distribuisci_talloncini(n: int) -> Array:
	var tal := []
	for c in 8:
		for q in Dati.VALORI_TALLONCINI:
			tal.append({"c": c, "q": q})
	tal.shuffle()
	tal.sort_custom(func(a, b): return a["q"] > b["q"])
	var ps := []
	var somme := []
	for p in n:
		ps.append([])
		somme.append(0)
	for t in tal:
		var migliore := -1
		var punti := 1.0e9
		for p in n:
			var ha := false
			for x in ps[p]:
				if x["c"] == t["c"]:
					ha = true
			var v: float = somme[p] * 100.0 + (50.0 if ha else 0.0) + ps[p].size() + randf() * 0.5
			if v < punti:
				punti = v
				migliore = p
		ps[migliore].append(t)
		somme[migliore] += t["q"]
	for p in ps:
		p.sort_custom(func(a, b): return a["q"] > b["q"])
	ps.shuffle()
	return ps

func quanti_token(t: String) -> int:
	return int(cfg["sacchetto"].get(t, Dati.TOKEN[t]["n"]))

func sacchetto_iniziale() -> Array:
	var l := []
	for t in Dati.TOKEN:
		for i in quanti_token(t):
			l.append(t)
	return l

## Una corsa intera: pile, partenza, turni fino al traguardo, svelamento.
func gioca_corsa() -> void:
	n_corsa += 1
	prepara_corsa()
	fase = "pile"
	cambiato.emit()
	await v.aggiorna()
	await v.dici(Dati.frase("pile"), "busta")
	await _scegli_pile()
	for g in giocatori:
		g["saldo"] -= cfg["posta"]
	fase = "corsa"
	cambiato.emit()
	await v.partenza()
	await v.dici(Dati.frase("partenza"), "conta3")
	while vincitore < 0:
		await gioca_turno()
		if n_turno > 600:
			break   # sicurezza: non dovrebbe mai succedere
	await _fine_corsa()

func _scegli_pile() -> void:
	var liberi := []
	for g in giocatori:
		liberi.append(g["uid"])
	var prese := {}
	while liberi.size():
		var op := []
		for p in pile.size():
			op.append({"k": p, "t": "Pila " + Dati.LETTERE_PILE[p], "ok": not prese.has(p)})
		var r: Dictionary = await _chiedi(liberi, "pila", "Scegli la tua pila di talloncini", op,
			{"sotto": "Costa %s. Dentro ci sono %d talloncini: guardali di nascosto!" % [euro(cfg["posta"]), pile[0].size()], "scopo": "pila"})
		var g := trova(r["uid"])
		g["pila"] = int(r["k"])
		prese[int(r["k"])] = true
		liberi.erase(r["uid"])
		cambiato.emit()
		await v.pila_scelta(r["uid"], int(r["k"]))

# ------------------------------------------------------------------ turno
func occupate(tranne := -99) -> Dictionary:
	var o := {}
	for c in cavalli:
		if c["cella"] >= 0 and c["id"] != tranne and not c["zoppo"]:
			o[c["cella"]] = c["id"]
	return o

func in_pista(c: Dictionary) -> bool:
	return not c["zoppo"]

func gioca_turno() -> void:
	n_turno += 1
	if _corsa_al_dado_ora():
		await corsa_al_dado()
	else:
		var uid := estrai_giocatore()
		giro.append(uid)
		di_turno = uid
		trova(uid)["turni"] += 1
		ultimo_uid = uid
		cambiato.emit()
		await v.estrazione(uid)
		if salta_prossimo:
			salta_prossimo = false
			await v.dici(Dati.frase("salta", {"g": nome_g(uid)}), "triste")
			_log("salta " + uid)
			return
		v.commenta(Dati.frase("turno", {"g": nome_g(uid)}), "indica")
		await _chiedi([uid], "tira", "Tira il dado!", [{"k": "tira", "t": "TIRA IL DADO", "ok": true}], {"scopo": "tira"})
		var faccia: Dictionary = Dati.DADO[randi() % Dati.DADO.size()]
		dado_attuale = [faccia]
		cambiato.emit()
		await v.dado([faccia])
		if faccia["v"]:
			v.commenta(Dati.frase("verde"), "sorpreso")
		await esegui_mossa(uid, faccia)
	while corsa_per_tutti and vincitore < 0:
		corsa_per_tutti = false
		await corsa_al_dado(true)
		# risolta la corsa al dado, il "?" torna subito nel sacchetto
		if cella_interrogativo >= 0 and token.get(cella_interrogativo, "") == "sorpresa":
			token.erase(cella_interrogativo)
			sacchetto.append("sorpresa")
			sacchetto.shuffle()
			await v.token_via([cella_interrogativo])
			await v.dici("Il punto interrogativo torna nel sacchetto.", "parla")
		cella_interrogativo = -1
		cambiato.emit()
	di_turno = ""
	dado_attuale = []
	cambiato.emit()

## Il giocatore di turno lo estrae la sorte, ma una sola volta per giro: chi ha giocato aspetta
## che abbiano giocato tutti. Nella corsa al dado (tutti = true) possono uscire anche loro.
func estrai_giocatore(escludi := [], tutti := false) -> String:
	var cand := []
	for g in giocatori:
		if not escludi.has(g["uid"]) and (tutti or not giro.has(g["uid"])):
			cand.append(g["uid"])
	if cand.is_empty() and not tutti:
		giro = []
		for g in giocatori:
			if not escludi.has(g["uid"]) and (g["uid"] != ultimo_uid or giocatori.size() == 1):
				cand.append(g["uid"])
	if cand.is_empty():
		for g in giocatori:
			if not escludi.has(g["uid"]):
				cand.append(g["uid"])
	if cand.is_empty():
		return giocatori[0]["uid"]
	return cand[randi() % cand.size()]

func _corsa_al_dado_ora() -> bool:
	return cfg["corsa_dado"] and giocatori.size() >= 3 and n_turno >= 3 and not salta_prossimo and randf() < 0.22

func corsa_al_dado(tutti := false) -> void:
	var k := (2 if giocatori.size() <= 5 else 3) if not tutti else giocatori.size()
	var facce := []
	for i in k:
		facce.append(Dati.DADO[randi() % Dati.DADO.size()])
	var scelti := []
	for i in k:
		scelti.append(estrai_giocatore(scelti, true))
	dado_attuale = facce
	in_corsa_dado = true
	cambiato.emit()
	await v.dici("Corsa al dado per tutti! Veloci col dito!" if tutti else Dati.frase("corsa_dado"), "sorpreso")
	await v.dado(facce)
	await v.estrazione_multipla(scelti)
	var liberi := scelti.duplicate()
	var presi := {}
	var ordine := []
	while liberi.size() > 1:
		var op := []
		for i in facce.size():
			op.append({"k": i, "t": Dati.testo_faccia(facce[i]), "n": facce[i]["n"], "v": facce[i]["v"], "e": facce[i].get("e", false), "ok": not presi.has(i)})
		var r: Dictionary = await _chiedi(liberi, "prendi", "Prendi un dado, presto!", op,
			{"sotto": "Il più veloce sceglie per primo", "scopo": "prendi", "corsa": true})
		presi[int(r["k"])] = r["uid"]
		liberi.erase(r["uid"])
		ordine.append([r["uid"], facce[int(r["k"])]])
		if ordine.size() == 1:
			await v.dici(Dati.frase("preso", {"g": nome_g(r["uid"])}), "ride")
		await v.dado_preso(int(r["k"]), r["uid"])
	for i in facce.size():
		if not presi.has(i):
			ordine.append([liberi[0], facce[i]])
			await v.dado_preso(i, liberi[0])
			break
	# si gioca dal più lento al più veloce: chi ha preso per primo gioca per ultimo
	ordine.reverse()
	await v.dici("Ora tutti giocano il loro dado: dal più lento al più veloce!", "parla")
	for p in ordine:
		if vincitore >= 0:
			break
		var uid: String = p[0]
		di_turno = uid
		trova(uid)["turni"] += 1
		dado_attuale = [p[1]]
		cambiato.emit()
		await v.dado_corsa_turno(uid)
		await v.dici("Tocca a %s con il suo %s!" % [nome_g(uid), Dati.testo_faccia(p[1])], "indica")
		await esegui_mossa(uid, p[1])
	in_corsa_dado = false

## Le mosse possibili per un cavallo con n passi: {"avanti": dest, "indietro": dest}.
## Indietro solo se la faccia del dado è "+N -N".
func mosse(cid: int, n: int, indietro := true) -> Dictionary:
	var c: Dictionary = cavalli[cid]
	var occ := occupate(cid)
	var res := {}
	var a := pista.destinazioni(c["cella"], n, true, occ)
	if a["celle"].size() or a["traguardo"]:
		res["avanti"] = a
	if indietro:
		var d := pista.destinazioni(c["cella"], n, false, occ)
		if d["celle"].size():
			res["indietro"] = d
	return res

func esegui_mossa(uid: String, faccia: Dictionary) -> void:
	var n: int = faccia["n"]
	var e: bool = faccia.get("e", false)
	var validi := []
	for c in cavalli:
		if c["attivo"] and not c["zoppo"] and mosse(c["id"], n, e).size():
			validi.append(c["id"])
	if validi.is_empty():
		await v.dici(Dati.frase("nessuna"), "pensa")
		_log("nessuna mossa")
		await _controlla_ripristino()
		return
	var tit := ("Quale cavallo muovi di %d (avanti o indietro)?" % n) if e else ("Quale cavallo fai avanzare di %d?" % n)
	var cid: int = await chiedi_cavallo(uid, tit, validi, "muovi")
	var m := mosse(cid, n, e)
	var verso := "avanti"
	if m.size() > 1:
		var op := [
			{"k": "avanti", "t": "+%d  avanti" % n, "ok": true},
			{"k": "indietro", "t": "-%d  indietro" % n, "ok": true},
		]
		var r: Dictionary = await _chiedi([uid], "verso", Dati.nome(cid) + ": quale risultato usi?", op, {"scopo": "verso", "cavallo": cid})
		verso = r["k"]
	else:
		verso = m.keys()[0]
	var d: Dictionary = m[verso]
	var da: int = cavalli[cid]["cella"]
	var dest: int = await chiedi_destinazione(uid, cid, d, "Dove si ferma " + Dati.nome(cid) + "?")
	await muovi(cid, da, dest, d, verso == "avanti")
	cavalli[cid]["attivo"] = false
	cambiato.emit()
	await v.aggiorna()
	if vincitore >= 0:
		return
	if verso == "avanti":
		await risolvi_casella(uid, cid, faccia["v"], da, 0)
	if vincitore >= 0:
		return
	await _controlla_ripristino()

func _controlla_ripristino() -> void:
	for c in cavalli:
		if c["attivo"] and not c["zoppo"]:
			return
	await nuovo_turno_cavalli()
	await v.dici(Dati.frase("ripristino"), "festeggia")

## Nuovo turno dei cavalli (tutti Disattivi, oppure il "?"): tutti tornano Attivi, tranne
## l'azzoppato, che rientra in pista ma Disattivato.
func nuovo_turno_cavalli() -> void:
	var zoppi := []
	for c in cavalli:
		if c["zoppo"]:
			zoppi.append(c["id"])
		else:
			c["attivo"] = true
	await _rientro_zoppi()
	for z in zoppi:
		cavalli[z]["attivo"] = false
	cambiato.emit()
	await v.aggiorna()

## Sposta un cavallo (animazione compresa). dest può essere Pista.TRAGUARDO.
func muovi(cid: int, da: int, dest: int, d: Dictionary, avanti: bool) -> void:
	var perc := pista.percorso(da, dest, d)
	var prima := _primo()
	cavalli[cid]["cella"] = dest
	if dest == Pista.TRAGUARDO:
		vincitore = cid
	_log("muove %d da %d a %d" % [cid, da, dest])
	await v.muovi(cid, perc, da)
	if dest == Pista.TRAGUARDO:
		return
	if avanti:
		var ora := _primo()
		if ora == cid and prima != cid and pista.progresso(dest) > 0:
			v.commenta(Dati.frase("testa", {"c": Dati.nome(cid)}), "occhiolino")
		elif pista.progresso(dest) > pista.lunghezza * 0.8 and not _quasi.has(cid):
			_quasi[cid] = true
			v.commenta(Dati.frase("quasi", {"c": Dati.nome(cid)}), "sorpreso")
		else:
			v.commenta(Dati.frase("avanti", {"c": Dati.nome(cid)}), "parla")
	else:
		v.commenta(Dati.frase("indietro", {"c": Dati.nome(cid)}), "sorpreso")

func _primo() -> int:
	var best := -1
	var bp := -2.0
	for c in cavalli:
		if c["zoppo"]:
			continue
		var p := pista.progresso(c["cella"])
		if p > bp:
			bp = p
			best = c["id"]
	return best

func chiedi_cavallo(uid: String, titolo: String, validi: Array, scopo: String, extra := {}) -> int:
	if validi.size() == 0:
		return -1
	var op := []
	for c in cavalli:
		op.append({"k": c["id"], "t": Dati.nome(c["id"]), "c": Dati.CAVALLI[c["id"]]["colore"],
			"ok": validi.has(c["id"]), "s": _stato_cavallo(c)})
	var e := {"scopo": scopo}
	e.merge(extra)
	var r: Dictionary = await _chiedi([uid], "cavallo", titolo, op, e)
	return int(r["k"])

func _stato_cavallo(c: Dictionary) -> String:
	if c["zoppo"]:
		return "azzoppato"
	if c["cella"] == Pista.PARTENZA:
		return "in partenza" + ("" if c["attivo"] else ", riposa")
	return ("pronto" if c["attivo"] else "riposa")

## Se c'è più di una casella possibile chiede dove fermarsi (le caselle si vedono numerate sulla TV).
func chiedi_destinazione(uid: String, cid: int, d: Dictionary, titolo: String) -> int:
	var scelte: Array = d["celle"].duplicate()
	if d.get("traguardo", false):
		return Pista.TRAGUARDO
	if scelte.size() == 1:
		return scelte[0]
	return await chiedi_casella(uid, titolo, scelte, cavalli[cid]["cella"], {"cavallo": cid, "scopo": "casella"})

func chiedi_casella(uid: String, titolo: String, scelte: Array, rispetto: int, extra := {}) -> int:
	scelte = scelte.duplicate()
	scelte.sort_custom(func(a, b): return pista.celle[a]["s"] < pista.celle[b]["s"] or (pista.celle[a]["s"] == pista.celle[b]["s"] and pista.celle[a]["corsia"] < pista.celle[b]["corsia"]))
	var op := []
	for i in scelte.size():
		var c: int = scelte[i]
		var s: String = pista.nome_corsia(pista.celle[c]["corsia"])
		if rispetto >= 0 and pista.adiacenti[rispetto].has(c):
			s = pista.descrivi_vicina(rispetto, c)
		if extra.get("scopo", "") == "sposta_token":
			var ds: float = pista.progresso(c) - pista.progresso(rispetto)
			if ds > pista.lunghezza / 2.0:
				ds -= pista.lunghezza
			elif ds < -pista.lunghezza / 2.0:
				ds += pista.lunghezza
			s = "una colonna avanti" if ds > 0 else "una colonna indietro"
		op.append({"k": c, "t": str(i + 1), "s": s, "ok": true, "cella": c})
	var r: Dictionary = await _chiedi([uid], "casella", titolo, op, extra)
	return int(r["k"])

# ------------------------------------------------------------------ token
## Il token vale per tutta la "colonna": le caselle affiancate da un bordo all'altro della pista.
func token_nella_colonna(cella: int, ignora := -99) -> int:
	for c in pista.colonna[cella]:
		if c != ignora and token.has(c):
			return c
	return -1

## Un cavallo arriva in una colonna: se c'è un token (o col pallino verde se ne pesca uno) scatta l'effetto.
## I token restano sulla pista; tornano nel sacchetto solo la Volata a tre e l'Azzoppato quando un cavallo
## ci capita sopra, e quelli dietro l'ultimo cavallo con la Spazzata.
## "visti": i token già scattati in questa catena (opzione cattiva), così ognuno vale una volta sola.
func risolvi_casella(uid: String, cid: int, verde: bool, origine: int, prof: int, visti := {}) -> void:
	var cella: int = cavalli[cid]["cella"]
	if cella < 0 or prof > 12 or cavalli[cid]["zoppo"]:
		return
	var tipo := ""
	var esistente := false
	var tc := token_nella_colonna(cella)
	if tc >= 0:
		if visti.has(tc):
			return
		if verde or cfg["token_sempre"] or prof > 0:
			tipo = token[tc]
			esistente = true
	elif verde and prof == 0:
		if sacchetto.is_empty():
			return
		tipo = sacchetto.pop_back()
		tc = cella
	if tipo == "":
		return
	visti[tc] = true
	_log("token %s %s su %d" % [tipo, "esistente" if esistente else "pescato", tc])
	await v.token_rivela(tipo, tc, esistente)
	await v.dici(Dati.frase_token(tipo) + " " + Dati.TOKEN[tipo]["nome"] + ": " + Dati.TOKEN[tipo]["testo"], "sussurra")
	var efficace := tipo
	if not esistente and tipo != "allarme":
		token[tc] = tipo
	elif not esistente:
		in_mano = 1   # la Spazzata pescata è in mano finché non torna nel sacchetto
	elif esistente and tipo in ["tre", "azzoppato"]:
		token.erase(tc)
		sacchetto.append(tipo)
		sacchetto.shuffle()
		await v.token_via([tc])
	cambiato.emit()
	await applica(uid, cid, efficace, origine, prof, tc, visti)
	cambiato.emit()
	await v.aggiorna()

## Opzione cattiva: dopo uno spostamento dovuto a un token, se il cavallo è finito su un altro token scatta anche quello
func _catena(uid: String, cid: int, origine: int, prof: int, visti: Dictionary) -> void:
	if not cfg["cattiva"] or vincitore >= 0:
		return
	var c: Dictionary = cavalli[cid]
	if c["zoppo"] or c["cella"] < 0:
		return
	var tc := token_nella_colonna(c["cella"])
	if tc < 0 or visti.has(tc):
		return
	await v.dici("Effetto multiplo! Un altro token...", "sorpreso")
	await risolvi_casella(uid, cid, false, origine, prof + 1, visti)

func applica(uid: String, cid: int, tipo: String, origine: int, prof: int, cella_token: int, visti := {}) -> void:
	var c: Dictionary = cavalli[cid]
	match tipo:
		"piu1", "piu2", "piu3":
			var n := int(tipo.substr(3))
			var d := pista.destinazioni(c["cella"], n, true, occupate(cid))
			if d["celle"].is_empty() and not d["traguardo"]:
				await v.dici("Non c'è posto: " + Dati.nome(cid) + " resta fermo.", "pensa")
				return
			var da: int = c["cella"]
			var dest := await chiedi_destinazione(uid, cid, d, "Dove si ferma " + Dati.nome(cid) + "?")
			await muovi(cid, da, dest, d, true)
			await _catena(uid, cid, da, prof, visti)
		"supera":
			var da: int = c["cella"]
			await _supera(uid, cid)
			if c["cella"] != da:
				await _catena(uid, cid, da, prof, visti)
		"attiva":
			var scelte := []
			for x in cavalli:
				if not x["attivo"] and not x["zoppo"] and x["id"] != cid:
					scelte.append(x["id"])
			if scelte.is_empty() and not c["attivo"]:
				scelte = [cid]
			if scelte.is_empty():
				return
			var k: int = scelte[0]
			if scelte.size() > 1:
				k = await chiedi_cavallo(uid, "Quale cavallo risvegli?", scelte, "attiva")
			cavalli[k]["attivo"] = true
			await v.aggiorna()
			await v.dici(Dati.nome(k) + " si risveglia!", "festeggia")
		"disattiva":
			var scelte := []
			for x in cavalli:
				if x["attivo"] and not x["zoppo"]:
					scelte.append(x["id"])
			if scelte.is_empty():
				for x in cavalli:
					if not x["zoppo"]:
						x["attivo"] = true
						scelte.append(x["id"])
				await v.aggiorna()
			var k: int = await chiedi_cavallo(uid, "Quale cavallo mandi a riposare?", scelte, "disattiva")
			cavalli[k]["attivo"] = false
			await v.aggiorna()
			await v.dici(Dati.nome(k) + " si fa una pennichella.", "ride")
		"tre":
			var fatti := []
			for i in 3:
				var scelte := []
				for x in cavalli:
					if not x["zoppo"] and not fatti.has(x["id"]):
						var d := pista.destinazioni(x["cella"], 2, true, occupate(x["id"]))
						if d["celle"].size() or d["traguardo"]:
							scelte.append(x["id"])
				if scelte.is_empty():
					break
				var k: int = await chiedi_cavallo(uid, "Volata a tre: scegli il cavallo %d di 3" % (i + 1), scelte, "tre")
				fatti.append(k)
				var d2 := pista.destinazioni(cavalli[k]["cella"], 2, true, occupate(k))
				var da: int = cavalli[k]["cella"]
				var dest := await chiedi_destinazione(uid, k, d2, "Dove si ferma " + Dati.nome(k) + "?")
				await muovi(k, da, dest, d2, true)
				if vincitore >= 0:
					return
				await _catena(uid, k, da, prof, visti)
				if vincitore >= 0:
					return
		"indietro":
			if origine == c["cella"]:
				return
			if origine >= 0 and occupate(cid).has(origine):
				await v.dici("La casella di prima è occupata: " + Dati.nome(cid) + " resta qui.", "pensa")
				return
			var da: int = c["cella"]
			c["cella"] = origine
			await v.muovi(cid, [da, origine], da)
			await v.dici(Dati.nome(cid) + " torna da dove era partito!", "sorpreso")
			# di regola il token della casella di partenza non conta; con l'effetto multiplo sì
			await _catena(uid, cid, da, prof, visti)
		"sorpresa":
			# il punto interrogativo: nuovo giro, tutti i cavalli Attivi e corsa al dado per tutti
			await nuovo_turno_cavalli()
			giro = []
			corsa_per_tutti = true
			cella_interrogativo = cella_token
			cambiato.emit()
			await v.aggiorna()
			await v.dici("Nuovo giro! Tutti i cavalli rialzano la testa e alla fine del turno corsa al dado per tutti!", "festeggia")
		"salta":
			salta_prossimo = true
			await v.dici("Il prossimo giocatore estratto salterà il turno!", "occhiolino")
		"azzoppato":
			c["zoppo"] = true
			c["cella_zoppo"] = c["cella"]
			c["attivo"] = false
			await v.zoppo(cid, true)
			await v.dici(Dati.frase("azzoppato", {"c": Dati.nome(cid)}), "triste")
		"allarme":
			if token.get(cella_token, "") == "allarme":
				token.erase(cella_token)
			var minp := 99999.0
			for x in cavalli:
				var cc: int = x["cella_zoppo"] if x["zoppo"] else x["cella"]
				minp = min(minp, pista.progresso(cc))
			var via := []
			for t in token.keys():
				if pista.progresso(t) < minp:
					via.append(t)
			for t in via:
				sacchetto.append(token[t])
				token.erase(t)
			sacchetto.append("allarme")
			in_mano = 0
			sacchetto.shuffle()
			await v.token_via(via)
			await v.dici("Spazzata! %d token tornano nel sacchetto." % (via.size() + 1), "ride")

func _supera(uid: String, cid: int) -> void:
	var c: Dictionary = cavalli[cid]
	var mio := pista.progresso(c["cella"])
	var davanti := -1
	var pd := 99999.0
	for x in cavalli:
		if x["zoppo"] or x["id"] == cid:
			continue
		var p := pista.progresso(x["cella"])
		if p > mio and p < pd:
			pd = p
			davanti = x["id"]
	if davanti < 0:
		await v.dici(Dati.nome(cid) + " è già in testa: niente sorpasso.", "occhiolino")
		return
	var occ := occupate(cid)
	for n in range(1, 40):
		var d := pista.destinazioni(c["cella"], n, true, occ)
		var buone := []
		for x in d["celle"]:
			if pista.progresso(x) > pd:
				buone.append(x)
		if buone.size():
			d["celle"] = buone
			var da: int = c["cella"]
			var dest := await chiedi_destinazione(uid, cid, d, "Dove si ferma " + Dati.nome(cid) + "?")
			await muovi(cid, da, dest, d, true)
			await v.dici(Dati.nome(cid) + " supera " + Dati.nome(davanti) + "!", "festeggia")
			return
		if d["traguardo"]:
			await muovi(cid, c["cella"], Pista.TRAGUARDO, d, true)
			return
	await v.dici("Niente spazio per il sorpasso.", "pensa")

func _rientro_zoppi() -> void:
	for c in cavalli:
		if not c["zoppo"]:
			continue
		var occ := occupate()
		var dove: int = c["cella_zoppo"]
		if occ.has(dove):
			var libere := []
			for a in pista.adiacenti[dove]:
				if not occ.has(a):
					libere.append(a)
			libere.sort_custom(func(a, b): return pista.progresso(a) < pista.progresso(b))
			dove = libere[0] if libere.size() else Pista.PARTENZA
		c["zoppo"] = false
		c["cella"] = dove
		c["attivo"] = false
		await v.zoppo(c["id"], false)
		await v.dici(Dati.frase("rientra", {"c": Dati.nome(c["id"])}), "parla")
	cambiato.emit()

# ------------------------------------------------------------------ fine
func quota_euro() -> float:
	return cfg["posta"] * giocatori.size() / 15.0

func euro(x: float) -> String:
	if x <= 0.0:
		return "0 euro"
	var cent := int(round(x * 100.0))
	if cent % 100 == 0:
		return "%d euro" % (cent / 100)
	return ("%d,%02d euro" % [cent / 100, cent % 100])

func _fine_corsa() -> void:
	fase = "svela"
	di_turno = ""
	cambiato.emit()
	await v.arrivo(vincitore)
	await v.dici(Dati.frase("traguardo", {"c": Dati.nome(vincitore)}), "festeggia")
	await v.dici(Dati.frase("svela"), "sussurra")
	risultati = []
	var qe := quota_euro()
	for g in giocatori:
		var tal: Array = pile[g["pila"]] if g["pila"] >= 0 else []
		var quote := 0
		for t in tal:
			if t["c"] == vincitore:
				quote += t["q"]
		var premio := quote * qe
		g["saldo"] += premio
		g["vinto"] = premio
		risultati.append({"uid": g["uid"], "nome": g["nome"], "quote": quote, "premio": premio, "talloncini": tal})
	cambiato.emit()
	await v.svela(risultati)
	var qualcuno := false
	var ordinati := risultati.duplicate()
	ordinati.sort_custom(func(a, b): return a["quote"] > b["quote"])
	for r in ordinati:
		if r["quote"] > 0:
			qualcuno = true
			await v.dici(Dati.frase("vince", {"g": r["nome"], "n": (euro(r["premio"]) if cfg["posta"] > 0 else "%d quote" % r["quote"])}), "soldi")
	if not qualcuno:
		await v.dici(Dati.frase("nessuno_vince"), "ride")
	fase = "fine"
	cambiato.emit()

# ------------------------------------------------------------------ domande
func _chiedi(per: Array, tipo: String, titolo: String, opzioni: Array, extra := {}) -> Dictionary:
	_pid += 1
	var d := {"id": _pid, "per": per.duplicate(), "tipo": tipo, "titolo": titolo, "opzioni": opzioni}
	d.merge(extra)
	domanda = d
	cambiato.emit()
	var r: Dictionary = await io.chiedi(d)
	domanda = {}
	cambiato.emit()
	return r

## Scelta automatica (bot, o giocatore che non risponde): un po' di furbizia sui propri talloncini.
func scelta_automatica(d: Dictionary, uid: String):
	var ok := []
	for o in d["opzioni"]:
		if o["ok"]:
			ok.append(o)
	if ok.is_empty():
		return null
	var g := trova(uid)
	var valore := {}
	for i in 8:
		valore[i] = 0
	if not g.is_empty() and g.get("pila", -1) >= 0:
		for t in pile[g["pila"]]:
			valore[t["c"]] += t["q"]
	match d.get("scopo", ""):
		"muovi", "attiva", "tre":
			ok.sort_custom(func(a, b): return valore[int(a["k"])] > valore[int(b["k"])])
			if randf() < 0.75:
				return ok[0]["k"]
		"disattiva":
			ok.sort_custom(func(a, b): return valore[int(a["k"])] < valore[int(b["k"])])
			return ok[0]["k"]
		"verso":
			var cid: int = d.get("cavallo", 0)
			return "avanti" if valore[cid] > 0 or randf() < 0.3 else "indietro"
		"prendi":
			ok.sort_custom(func(a, b): return int(a["n"]) + (0.5 if a.get("v", false) else 0.0) + (0.3 if a.get("e", false) else 0.0) > int(b["n"]) + (0.5 if b.get("v", false) else 0.0) + (0.3 if b.get("e", false) else 0.0))
			return ok[0]["k"]
	return ok[randi() % ok.size()]["k"]

func _log(t: String) -> void:
	registro.append(t)
	if registro.size() > 200:
		registro.pop_front()

# ------------------------------------------------------------------ stato pubblico per i telefoni
func stato_pubblico() -> Dictionary:
	var gs := []
	for g in giocatori:
		gs.append({"uid": g["uid"], "nome": g["nome"], "base": g.get("base", g["nome"]), "ritratto": g.get("ritratto", ""),
			"pila": g["pila"], "saldo": g["saldo"], "vinto": g["vinto"], "turni": g["turni"], "giocato": giro.has(g["uid"])})
	var cs := []
	for c in cavalli:
		cs.append({"id": c["id"], "nome": Dati.nome(c["id"]), "col": Dati.CAVALLI[c["id"]]["colore"], "attivo": c["attivo"],
			"zoppo": c["zoppo"], "p": pista.progresso(c["cella"] if not c["zoppo"] else c["cella_zoppo"]) / pista.lunghezza, "stato": _stato_cavallo(c)})
	return {
		"fase": fase, "corsa": n_corsa, "turno": n_turno, "giocatori": gs, "cavalli": cs,
		"di_turno": di_turno, "nome_turno": nome_g(di_turno) if di_turno != "" else "",
		"dado": dado_attuale, "domanda": domanda, "vincitore": vincitore, "risultati": risultati,
		"cfg": cfg, "quota": quota_euro(), "salta": salta_prossimo,
	}

## Talloncini segreti di un giocatore
func segreto(uid: String) -> Dictionary:
	var g := trova(uid)
	if g.is_empty() or g["pila"] < 0:
		return {"pila": -1, "talloncini": []}
	var t := []
	for x in pile[g["pila"]]:
		t.append({"c": x["c"], "nome": Dati.nome(x["c"]), "col": Dati.CAVALLI[x["c"]]["colore"], "q": x["q"]})
	return {"pila": g["pila"], "lettera": Dati.LETTERE_PILE[g["pila"]], "talloncini": t}

# ------------------------------------------------------------------ salvataggio (per riprendere)
func salva() -> Dictionary:
	return {"cfg": cfg, "fase": fase, "giocatori": giocatori, "cavalli": cavalli, "token": token, "sacchetto": sacchetto,
		"pile": pile, "n_corsa": n_corsa, "n_turno": n_turno, "salta": salta_prossimo, "ultimo": ultimo_uid, "giro": giro}

func carica(s: Dictionary) -> void:
	cfg.merge(s["cfg"], true)
	pista = Pista.new(int(cfg["rettilinei"]))
	fase = s["fase"]
	giocatori = s["giocatori"]
	cavalli = []
	for c in s["cavalli"]:
		cavalli.append({"id": int(c["id"]), "cella": int(c["cella"]), "attivo": c["attivo"], "zoppo": c["zoppo"], "cella_zoppo": int(c["cella_zoppo"])})
	token = {}
	for k in s["token"]:
		token[int(k)] = s["token"][k]
	sacchetto = s["sacchetto"]
	pile = []
	for p in s["pile"]:
		var l := []
		for t in p:
			l.append({"c": int(t["c"]), "q": int(t["q"])})
		pile.append(l)
	for g in giocatori:
		g["pila"] = int(g["pila"])
		g["turni"] = int(g["turni"])
	n_corsa = int(s["n_corsa"])
	n_turno = int(s["n_turno"])
	salta_prossimo = s["salta"]
	ultimo_uid = s["ultimo"]
	giro = s.get("giro", [])
	vincitore = -1

## Riprende una corsa salvata dall'inizio del turno.
func riprendi_corsa() -> void:
	fase = "corsa"
	cambiato.emit()
	await v.aggiorna()
	while vincitore < 0:
		await gioca_turno()
		if n_turno > 600:
			break
	await _fine_corsa()

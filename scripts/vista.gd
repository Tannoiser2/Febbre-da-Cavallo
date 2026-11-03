class_name Vista
extends RefCounted
## Quello che il motore mostra: anima la pista 3D, aggiorna l'interfaccia, fa parlare il cronista.

var main
var ip: Ippodromo
var ui: Interfaccia
var rete: Rete
var m: Motore
var ultima_frase := ""
var voce_attiva := true

func _init(mn) -> void:
	main = mn
	ip = mn.ip
	ui = mn.ui
	rete = mn.rete
	m = mn.m

func _attendi(sec: float) -> void:
	await main.get_tree().create_timer(sec / float(main.veloce)).timeout

func aggiorna() -> void:
	if ip.pista != m.pista:
		ip.costruisci(m.pista)
	ip.sincronizza(m)
	ui.aggiorna_classifica(m)

func dici(t: String, posa := "parla") -> void:
	ultima_frase = t
	main.frase_per_telefoni(t)
	ui.parla(t, posa)
	var id := -1
	if voce_attiva and main.veloce <= 2.0:
		id = rete.parla(t)
	var stima: float = (0.9 + t.length() * 0.055) / main.veloce
	var t0 := Time.get_ticks_msec()
	while true:
		await main.get_tree().process_frame
		var passato := (Time.get_ticks_msec() - t0) / 1000.0
		if id >= 0:
			if rete.parlato(id) and passato > 0.4:
				break
			if passato > stima + 6.0:
				break
		elif passato > stima:
			break

func partenza() -> void:
	ui.nascondi_pile()
	ip.vista_generale()
	aggiorna()
	rete.suono("tromba")
	for n in ["3", "2", "1"]:
		ui.parla(n + "...", "conta" + n)
		await ui.mostra_banner(n)
		rete.suono("tick")
		await _attendi(0.7)
	await ui.mostra_banner("VIA!")
	rete.suono("sparo")
	await _attendi(0.6)
	ui.mostra_banner("")

func pila_scelta(uid: String, p: int) -> void:
	ui.pila_presa(p, m.nome_g(uid))
	rete.suono("moneta")
	main.invia_segreto(uid)
	await _attendi(0.3)

func estrazione(uid: String) -> void:
	ui.togli_dadi()
	var nomi := []
	for g in m.giocatori:
		nomi.append(g["nome"])
	await ui.roulette(nomi, m.nome_g(uid), func(): rete.suono("tick"))
	rete.suono("ding")

func estrazione_multipla(uids: Array) -> void:
	var nomi := []
	for u in uids:
		nomi.append(m.nome_g(u))
	await ui.mostra_banner("CORSA AL DADO!", " - ".join(nomi))
	rete.suono("ding")
	await _attendi(0.6)

func dado(facce: Array) -> void:
	ui.togli_dadi()
	var nodi: Array = await ip.lancia_dadi(facce, func(): rete.suono("dado"), main.veloce)
	await _attendi(0.3)
	await ui.mostra_dadi(facce, func(): pass)
	ip.togli_dadi_3d(nodi)
	if facce.size() == 1 and facce[0].get("v", false):
		rete.suono("verde")
	await _attendi(0.4)

func dado_corsa_turno(uid: String) -> void:
	ui.evidenzia_preso(m.nome_g(uid))
	await _attendi(0.3)

func dado_preso(i: int, uid: String) -> void:
	await ui.dado_preso(i, m.nome_g(uid))
	rete.suono("preso")
	await _attendi(0.2)

func muovi(cid: int, perc: Array, da: int) -> void:
	rete.suono("galoppo_via")
	await ip.anima_mossa(cid, perc, da, main.veloce)
	rete.suono("galoppo_stop")
	ui.aggiorna_classifica(m)

func token_rivela(tipo: String, cella: int, esistente: bool) -> void:
	rete.suono("token")
	await ip.anima_token_rivela(tipo, cella, esistente)

func token_via(celle: Array) -> void:
	await ip.anima_token_via(celle)

func token_sposta(da: int, a: int, tipo: String) -> void:
	await ip.anima_token_sposta(da, a, tipo)

func zoppo(cid: int, fuori: bool) -> void:
	if fuori:
		rete.suono("ahi")
	await ip.anima_zoppo(cid, m.cavalli[cid]["cella_zoppo"], fuori)
	aggiorna()

func arrivo(cid: int) -> void:
	ui.togli_dadi()
	ui.mostra_banner("HA VINTO " + Dati.nome(cid).to_upper() + "!")
	rete.suono("vittoria")
	ui.coriandoli()
	ip._segui = ip.cavalli[cid]
	await _attendi(2.5)
	ip.vista_generale()

func svela(ris: Array) -> void:
	ui.mostra_banner("")
	for i in ris.size() + 1:
		ui.mostra_risultati(m, ris, i)
		if i > 0:
			rete.suono("gira" if ris[i - 1]["quote"] == 0 else "moneta")
		await _attendi(0.9)
	main.invia_tutti_i_segreti()

# ------------------------------------------------------------------ domande ai telefoni
func mostra_domanda(d: Dictionary) -> void:
	var chi := []
	for u in d["per"]:
		chi.append(m.nome_g(u))
	ui.bt_decidi.visible = true
	match d["tipo"]:
		"pila":
			ui.mostra_pile(m)
			return
		"prendi":
			ui.sotto_banner("Presto! Prendi un dado dal telefono")
			return
		"tira":
			ui.sotto_banner(chi[0] + ", tira il dado dal telefono!")
			return
	ui.sotto_banner(d["titolo"] + "  (decide " + ", ".join(chi) + ")")
	var celle := []
	for o in d["opzioni"]:
		if o.has("cella"):
			celle.append(o)
	if celle.size():
		ip.mostra_marcatori(celle)
	if d["tipo"] == "cavallo":
		var ok := []
		for o in d["opzioni"]:
			if o["ok"]:
				ok.append(int(o["k"]))
		ip.evidenzia_cavalli(ok)

func togli_domanda() -> void:
	ui.bt_decidi.visible = false
	ip.togli_marcatori()
	ip.evidenzia_cavalli([])

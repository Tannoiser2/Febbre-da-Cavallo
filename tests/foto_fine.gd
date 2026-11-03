extends SceneTree
## Fotografia della schermata dei risultati sulla TV.
func _init() -> void:
	var out := "/tmp/foto_fine.png"
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var m: Motore = main.m
	for n in ["Stefano", "Nonna Lina", "Zio Gigi", "Chiara"]:
		m.aggiungi_giocatore(n, n, false)
	m.prepara_corsa()
	for i in 4:
		m.giocatori[i]["pila"] = i
	m.vincitore = 2
	m.cavalli[2]["cella"] = Pista.TRAGUARDO
	main.ui.mostra_sala(false)
	main.ip.sincronizza(m)
	var ris := []
	var qe := m.quota_euro()
	for g in m.giocatori:
		var q := 0
		for t in m.pile[g["pila"]]:
			if t["c"] == 2:
				q += t["q"]
		g["saldo"] = q * qe - 15.0
		ris.append({"uid": g["uid"], "nome": g["nome"], "quote": q, "premio": q * qe, "talloncini": m.pile[g["pila"]]})
	main.ui.mostra_risultati(m, ris, ris.size())
	main.ui.parla("Complimenti Stefano, porti a casa 12 euro!", "soldi")
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()

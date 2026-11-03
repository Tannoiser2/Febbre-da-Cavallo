extends SceneTree
## Fotografie del lancio del dado: in volo, fermo sulla pista, ingrandito al centro.
func _init() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var m: Motore = main.m
	m.prepara_corsa()
	m.cavalli[2]["attivo"] = false
	m.cavalli[3]["zoppo"] = true
	m.cavalli[3]["cella_zoppo"] = 9
	m.cavalli[0]["cella"] = 4
	m.cavalli[2]["cella"] = 7
	main.ui.mostra_sala(false)
	main.ip.sincronizza(m)
	for i in 30:
		await process_frame
	main.vista.dado([Dati.DADO[4], Dati.DADO[5]])
	var t0 := Time.get_ticks_msec()
	for tt in [1000, 2500, 4000, 6500]:
		while Time.get_ticks_msec() - t0 < tt:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/lancio_%d.png" % tt)
	quit()

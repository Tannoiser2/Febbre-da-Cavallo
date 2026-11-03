extends SceneTree
## Fotografia di dadi e colonne dei token sulla TV.
func _init() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var m: Motore = main.m
	m.prepara_corsa()
	main.ui.mostra_sala(false)
	m.token = {4: "piu2", 25: "salta", 30: "supera"}
	m.cavalli[0]["cella"] = 3
	main.ip.sincronizza(m)
	main.ui.mostra_dadi([Dati.DADO[1], Dati.DADO[2], Dati.DADO[5]], func(): pass)
	for i in 120:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/foto_dadi.png")
	quit()

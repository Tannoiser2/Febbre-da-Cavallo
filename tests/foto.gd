extends SceneTree
## Partita automatica con la grafica e fotografie: godot --path . -s tests/foto.gd -- cartella secondi...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := a[0] if a.size() else "/tmp/foto"
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.veloce = 6.0
	main.auto = true
	for i in 4:
		main._aggiungi_bot()
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/0_sala.png")
	main._comando("parti", null)
	var tempi := [3.0, 8.0, 20.0, 40.0, 60.0, 90.0]
	var t0 := Time.get_ticks_msec()
	var k := 1
	for t in tempi:
		while (Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(dir + "/%d_t%d.png" % [k, int(t)])
		print("foto ", k, " fase ", main.m.fase, " turno ", main.m.n_turno)
		k += 1
	# fino alla fine della corsa
	while main.m.fase != "fine" and (Time.get_ticks_msec() - t0) < 400000:
		await process_frame
	await create_timer(3.0).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/9_fine.png")
	print("fine: fase ", main.m.fase, " vincitore ", main.m.vincitore, " turni ", main.m.n_turno)
	quit()

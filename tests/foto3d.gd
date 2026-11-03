extends SceneTree
## Fotografia della sola pista 3D: godot --path . -s tests/foto3d.gd -- uscita.png
func _init() -> void:
	var out := "/tmp/foto3d.png"
	var a := OS.get_cmdline_user_args()
	if a.size():
		out = a[0]
	await process_frame
	var ip := Ippodromo.new()
	root.add_child(ip)
	await process_frame
	var m := Motore.new()
	m.prepara_corsa()
	var celle := [0, 4, 7, 13, 20, 25, 31, -1]
	for i in 8:
		m.cavalli[i]["cella"] = celle[i]
		m.cavalli[i]["attivo"] = i % 3 != 0
	m.token = {10: "piu2", 16: "azzoppato", 28: "supera", 40: "allarme"}
	m.cavalli[3]["zoppo"] = true
	m.cavalli[3]["cella_zoppo"] = 13
	ip.sincronizza(m)
	ip.cavalli[2].galoppa(true)
	ip.mostra_marcatori([{"t": "1", "cella": 2}, {"t": "2", "cella": 5}])
	if a.size() > 1:
		ip._segui = ip.cavalli[int(a[1])]
		if a.size() > 2:
			ip.camera_libera = true
			var h: Node3D = ip.cavalli[int(a[1])]
			ip.cam.position = h.position + Vector3(float(a[2]), 3.0, 6.0)
			ip.cam.look_at(h.position + Vector3(0, 1.2, 0))
		ip.cavalli[int(a[1])].galoppa(true)
	for i in 90:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("salvata ", out)
	quit()

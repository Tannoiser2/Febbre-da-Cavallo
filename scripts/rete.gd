class_name Rete
extends Node
## Ponte tra Godot e la pagina web (web/js/ponte.js): stanza su Firebase, telefoni, voce e suoni.
## Fuori dal browser (editor di Godot, test) non fa nulla: si gioca con i giocatori finti.

signal evento(e: Dictionary)

var web := false
var fr = null
var codice := ""
var url := ""

func _ready() -> void:
	web = OS.has_feature("web")
	if web:
		fr = JavaScriptBridge.get_interface("FR")
		if fr == null:
			web = false

func _process(_d: float) -> void:
	if fr == null:
		return
	var s = fr.preleva()
	if s == null or str(s) == "" or str(s) == "[]":
		return
	var l = JSON.parse_string(str(s))
	if l is Array:
		for e in l:
			if e is Dictionary:
				if e.get("e") == "stanza":
					codice = e.get("codice", "")
					url = e.get("url", "")
				evento.emit(e)

func parametri() -> Dictionary:
	if fr == null:
		return {}
	var p = JSON.parse_string(str(fr.parametri()))
	return p if p is Dictionary else {}

func avvia(riprendi := "") -> void:
	if fr:
		fr.avvia(riprendi)

func stato(d: Dictionary) -> void:
	if fr:
		fr.stato(JSON.stringify(d))

func segreto(uid: String, d: Dictionary) -> void:
	if fr:
		fr.segreto(uid, JSON.stringify(d))

func parla(t: String) -> int:
	if fr:
		return int(fr.parla(t))
	return -1

func parlato(id: int) -> bool:
	if fr == null or id < 0:
		return true
	return bool(fr.parlato(id))

func suono(n: String) -> void:
	if fr:
		fr.suono(n)

func voce(si: bool) -> void:
	if fr:
		fr.voce(si)

func velocita_voce(x: float) -> void:
	if fr:
		fr.velocitaVoce(x)

func schermo_intero() -> void:
	if fr:
		fr.schermoIntero()

func qr(testo: String) -> String:
	if fr:
		return str(fr.qr(testo))
	return ""

func salva(k: String, v: String) -> void:
	if fr:
		fr.salva(k, v)

func carica(k: String) -> String:
	if fr:
		var s = fr.carica(k)
		return "" if s == null else str(s)
	return ""

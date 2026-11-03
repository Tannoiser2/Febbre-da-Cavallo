class_name IOBot
extends RefCounted
## Risponde alle domande al posto dei giocatori (test automatici).

var motore

func chiedi(d: Dictionary) -> Dictionary:
	var uid: String = d["per"][randi() % d["per"].size()]
	return {"uid": uid, "k": motore.scelta_automatica(d, uid)}

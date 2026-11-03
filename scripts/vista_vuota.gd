class_name VistaVuota
extends RefCounted
## Vista che non fa nulla: per i test automatici senza grafica.

func aggiorna() -> void: pass
func dici(_t: String, _posa := "parla") -> void: pass
func partenza() -> void: pass
func pila_scelta(_uid: String, _p: int) -> void: pass
func estrazione(_uid: String) -> void: pass
func estrazione_multipla(_uids: Array) -> void: pass
func dado(_facce: Array) -> void: pass
func dado_preso(_i: int, _uid: String) -> void: pass
func dado_corsa_turno(_uid: String) -> void: pass
func muovi(_cid: int, _perc: Array, _da: int) -> void: pass
func token_rivela(_tipo: String, _cella: int, _esistente: bool) -> void: pass
func token_via(_celle: Array) -> void: pass
func token_sposta(_da: int, _a: int, _tipo: String) -> void: pass
func zoppo(_cid: int, _fuori: bool) -> void: pass
func arrivo(_cid: int) -> void: pass
func svela(_ris: Array) -> void: pass

class_name Pista
extends RefCounted
## La pista è una catena chiusa di pezzi, percorsa in senso antiorario (le curve girano tutte verso l'interno).
## Unità: 1 = 1 cm, come i pezzi stampati.
## Pezzi:
##   "R"    rettilineo, 3 corsie per 3 file (la versione con i token usa file_per_tratto = 4)
##   "S"    strettoia: come il rettilineo ma la corsia interna è siepe (2 corsie)
##   "C45"  curva di 45 gradi, caselle 1, 1, 2 (dalla corsia interna all'esterna)
##   "C90"  curva di 90 gradi, caselle 1, 2, 3
##   "C180" curva di 180 gradi, caselle 2, 3, 4
## Tutte le curve hanno lo stesso raggio, quindi 2 x 45 = 90 e 2 x 90 = 180.

const PARTENZA := -1
const TRAGUARDO := -2
const CORSIE := 3
const LARG_CORSIA := 2.33
const R0 := 3.75            # raggio del bordo interno delle curve
const BORDO := 0.4
const LUNG_FILA := 5.8      # lunghezza di una fila nel rettilineo
const R_MEDIO := R0 + LARG_CORSIA * 1.5
const ANGOLO := {"C45": 45.0, "C90": 90.0, "C180": 180.0}
const CELLE := {"C45": [1, 1, 2], "C90": [1, 2, 3], "C180": [2, 3, 4]}

var pezzi := []             # sequenza dei pezzi
var file_per_tratto := 4
var lunghezza := 0.0        # lunghezza totale (linea a R_MEDIO)
var segmenti := []          # {tipo, pezzo, s0, s1, p (inizio bordo interno), d (direzione), n (verso l'interno), ang}
var celle := []
var corsie := []            # per corsia: elenco ordinato degli id
var file := []              # file dei rettilinei: [id delle corsie presenti]
var succ := {}
var prec := {}
var adiacenti := {}
var colonna := {}           # caselle affiancate da un bordo all'altro (sovrapposte lungo la pista)
var minimo := Vector2.ZERO  # ingombro (bordo esterno compreso)
var massimo := Vector2.ZERO
var centro := Vector2.ZERO
var lato := 0.0             # larghezza del riquadro della pista (per l'arredo)
var _primi := []            # caselle da cui si parte

## rettilinei e file_tratto: l'ovale classico (versione con i token); pz: una sequenza di pezzi qualunque
func _init(rettilinei: int = 4, file_tratto := 4, pz := []) -> void:
	file_per_tratto = file_tratto
	if pz.is_empty():
		var k: int = max(1, rettilinei / 2)
		for lato_i in 2:
			for i in k:
				pz.append("R")
			pz.append("C90")
			pz.append("C90")
	pezzi = pz
	_costruisci()

## Una pista a sorpresa con i pezzi nuovi: due lati con "dritti" pezzi dritti (qualche strettoia)
## e le due testate fatte in modi diversi (180, 90+90, 90+45+45, 45+90+45...).
static func a_sorpresa(dritti: int, rng: RandomNumberGenerator) -> Pista:
	var testate := [["C180"], ["C90", "C90"], ["C90", "C45", "C45"], ["C45", "C45", "C90"], ["C45", "C90", "C45"], ["C45", "C45", "C45", "C45"]]
	var pz := []
	for lato_i in 2:
		var lato_p := []
		for i in dritti:
			lato_p.append("R")
		# una strettoia per lato (mai il primo pezzo: lì c'è la partenza)
		if dritti >= 2:
			lato_p[rng.randi_range(1, dritti - 1)] = "S"
		pz.append_array(lato_p)
		pz.append_array(testate[rng.randi() % testate.size()])
	return Pista.new(0, 3, pz)

# ------------------------------------------------------------------ costruzione
func _costruisci() -> void:
	var p := Vector2.ZERO
	var d := Vector2(1, 0)
	var s := 0.0
	for i in pezzi.size():
		var t: String = pezzi[i]
		var nrm := Vector2(d.y, -d.x)
		if t == "R" or t == "S":
			var L := file_per_tratto * LUNG_FILA
			segmenti.append({"tipo": "r", "pezzo": t, "s0": s, "s1": s + L, "p": p, "d": d, "n": nrm, "ang": 0.0})
			p += d * L
			s += L
		else:
			var a := deg_to_rad(ANGOLO[t])
			var L2 := a * R_MEDIO
			segmenti.append({"tipo": "c", "pezzo": t, "s0": s, "s1": s + L2, "p": p, "d": d, "n": nrm, "ang": a})
			var cc := p + nrm * R0
			var u := -nrm * cos(a) + d * sin(a)
			p = cc + u * R0
			d = d * cos(a) + nrm * sin(a)
			s += L2
	lunghezza = s
	# ingombro e centratura
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var n := int(lunghezza / 0.5)
	for i in n:
		for r in [R0 - BORDO, R0 + CORSIE * LARG_CORSIA + BORDO]:
			var q := _punto_grezzo(lunghezza * i / n, r)
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var sposta := -(lo + hi) / 2.0
	for sg in segmenti:
		sg["p"] += sposta
	minimo = lo + sposta
	massimo = hi + sposta
	centro = Vector2.ZERO
	lato = massimo.x - minimo.x - 2.0 * (R0 + CORSIE * LARG_CORSIA + BORDO)
	# caselle
	for l in CORSIE:
		corsie.append([])
	for si in segmenti.size():
		var sg: Dictionary = segmenti[si]
		if sg["tipo"] == "r":
			var nf := int(round((sg["s1"] - sg["s0"]) / LUNG_FILA))
			for j in nf:
				var fila := []
				for l in CORSIE:
					if sg["pezzo"] == "S" and l == 0:
						continue
					var id := _nuova_cella(l, "r", sg["s0"] + j * LUNG_FILA, sg["s0"] + (j + 1) * LUNG_FILA, file.size(), si)
					fila.append(id)
					corsie[l].append(id)
				file.append(fila)
		else:
			for l in CORSIE:
				var k: int = CELLE[sg["pezzo"]][l]
				var q2: float = (sg["s1"] - sg["s0"]) / k
				for j in k:
					var id := _nuova_cella(l, "c", sg["s0"] + j * q2, sg["s0"] + (j + 1) * q2, -1, si)
					corsie[l].append(id)
	# successivi nella stessa corsia (solo se le caselle si toccano: la strettoia interrompe la corsia interna)
	for l in CORSIE:
		var c: Array = corsie[l]
		for i in c.size():
			var nx := -99
			if i + 1 < c.size():
				if absf(celle[c[i + 1]]["s0"] - celle[c[i]]["s1"]) < 0.05:
					nx = c[i + 1]
			elif absf(celle[c[i]]["s1"] - lunghezza) < 0.05:
				nx = TRAGUARDO
			succ[c[i]] = nx
			var pv := -99
			if i > 0 and absf(celle[c[i]]["s0"] - celle[c[i - 1]]["s1"]) < 0.05:
				pv = c[i - 1]
			elif i == 0 and celle[c[i]]["s0"] < 0.05:
				pv = PARTENZA
			prec[c[i]] = pv
	_primi = file[0].duplicate() if segmenti[0]["tipo"] == "r" else []
	# caselle adiacenti (si toccano per un lato o per uno spigolo, anche a cavallo del traguardo)
	for a in celle:
		var l := []
		for b in celle:
			if a["id"] == b["id"] or absi(a["corsia"] - b["corsia"]) > 1:
				continue
			if _intervalli_toccano(a["s0"], a["s1"], b["s0"], b["s1"]):
				l.append(b["id"])
		adiacenti[a["id"]] = l
	for a in celle:
		var l := []
		for b in celle:
			var sov := minf(a["s1"], b["s1"]) - maxf(a["s0"], b["s0"])
			if sov > 0.05:
				l.append(b["id"])
		colonna[a["id"]] = l

func _intervalli_toccano(a0: float, a1: float, b0: float, b1: float) -> bool:
	var e := 0.01
	for sh in [0.0, lunghezza, -lunghezza]:
		if a1 >= b0 + sh - e and b1 + sh >= a0 - e:
			return true
	return false

func _nuova_cella(corsia: int, tipo: String, s0: float, s1: float, fila: int, seg: int) -> int:
	var id := celle.size()
	var r0 := R0 + corsia * LARG_CORSIA
	var r1 := r0 + LARG_CORSIA
	var sc := (s0 + s1) / 2.0
	celle.append({
		"id": id, "corsia": corsia, "tipo": tipo, "fila": fila, "seg": seg, "s0": s0, "s1": s1, "s": sc,
		"centro": punto(sc, (r0 + r1) / 2.0), "dir": direzione(sc),
	})
	return id

func segmento(s: float) -> Dictionary:
	s = fposmod(s, lunghezza)
	for sg in segmenti:
		if s <= sg["s1"] + 0.0001:
			return sg
	return segmenti[-1]

func _punto_grezzo(s: float, r: float) -> Vector2:
	return punto(s, r)

## Punto (x, z) del piano a distanza s lungo la pista e a "raggio" r: r = R0 è il bordo interno,
## r = R0 + 3 corsie il bordo esterno (nelle curve è proprio la distanza dal centro della curva).
func punto(s: float, r: float) -> Vector2:
	var sg := segmento(s)
	var t: float = fposmod(s, lunghezza) - sg["s0"]
	var p: Vector2 = sg["p"]
	var d: Vector2 = sg["d"]
	var nrm: Vector2 = sg["n"]
	if sg["tipo"] == "r":
		return p + d * t - nrm * (r - R0)
	var phi: float = t / R_MEDIO
	var cc: Vector2 = p + nrm * R0
	return cc + (-nrm * cos(phi) + d * sin(phi)) * r

## Direzione di marcia (versore x, z) alla distanza s.
func direzione(s: float) -> Vector2:
	var a := punto(s - 0.05, R_MEDIO)
	var b := punto(s + 0.05, R_MEDIO)
	return (b - a).normalized()

# ------------------------------------------------------------------ movimento
func _fila_successiva(id: int) -> Array:
	# da un rettilineo al rettilineo successivo si cambia corsia liberamente
	var f: int = celle[id]["fila"]
	if f < 0 or f + 1 >= file.size():
		return []
	var nf: Array = file[f + 1]
	if absf(celle[nf[0]]["s0"] - celle[id]["s1"]) < 0.05:
		return nf.duplicate()
	return []

func _fila_precedente(id: int) -> Array:
	var f: int = celle[id]["fila"]
	if f <= 0:
		return []
	var pf: Array = file[f - 1]
	if absf(celle[pf[0]]["s1"] - celle[id]["s0"]) < 0.05:
		return pf.duplicate()
	return []

func passi_avanti(id: int) -> Array:
	if id == PARTENZA:
		return _primi.duplicate()
	var fs := _fila_successiva(id)
	if fs.size():
		return fs
	var n: int = succ[id]
	if n == TRAGUARDO:
		return [TRAGUARDO]
	if n >= 0:
		return [n]
	# la corsia finisce (strettoia): si passa nella corsia accanto
	var l: int = celle[id]["corsia"]
	for c in corsie[l + 1] if l + 1 < CORSIE else []:
		if absf(celle[c]["s0"] - celle[id]["s1"]) < 0.05:
			return [c]
	return []

func passi_indietro(id: int) -> Array:
	if id == PARTENZA:
		return []
	var fp := _fila_precedente(id)
	if fp.size():
		return fp
	var p: int = prec[id]
	if p == PARTENZA:
		return []
	if p >= 0:
		return [p]
	var l: int = celle[id]["corsia"]
	for c in corsie[l + 1] if l + 1 < CORSIE else []:
		if absf(celle[c]["s1"] - celle[id]["s0"]) < 0.05:
			return [c]
	return []

## Caselle raggiungibili con esattamente n passi (avanti o indietro), senza fermarsi su caselle occupate.
## Restituisce {"celle": [...], "traguardo": bool, "padri": {...}} (padri serve a ricostruire il percorso).
func destinazioni(da: int, n: int, avanti: bool, occupate: Dictionary) -> Dictionary:
	var cur := {da: true}
	var padri := {}
	var traguardo := false
	for i in n:
		var nxt := {}
		for c in cur:
			var pp: Array = passi_avanti(c) if avanti else passi_indietro(c)
			for x in pp:
				if x == TRAGUARDO:
					traguardo = true
					if not padri.has(TRAGUARDO):
						padri[TRAGUARDO] = c
				elif not nxt.has(x):
					nxt[x] = true
					if not padri.has([i, x]):
						padri[[i, x]] = c
		cur = nxt
	var res := []
	for c in cur:
		if not occupate.has(c):
			res.append(c)
	res.sort()
	return {"celle": res, "traguardo": traguardo, "padri": padri, "n": n}

## Percorso casella per casella da 'da' a 'a' (usando i padri trovati da destinazioni).
func percorso(da: int, a: int, d: Dictionary) -> Array:
	var p := []
	if a == TRAGUARDO:
		var c: int = d["padri"][TRAGUARDO]
		p = _risali(da, c, d)
		p.append(TRAGUARDO)
		return p
	return _risali(da, a, d)

func _risali(da: int, a: int, d: Dictionary) -> Array:
	var p := [a]
	var i: int = d["n"] - 1
	var c := a
	while i >= 0 and not d["padri"].has([i, c]):
		i -= 1
	while i >= 0 and c != da:
		c = d["padri"][[i, c]]
		p.push_front(c)
		i -= 1
	return p

func progresso(id: int) -> float:
	if id == PARTENZA:
		return -1.0
	if id == TRAGUARDO:
		return lunghezza + 10.0
	return celle[id]["s"]

## Descrizione a parole di una casella vicina rispetto a quella di partenza (per i telefoni).
func descrivi_vicina(da: int, a: int) -> String:
	var ca: Dictionary = celle[da]
	var cb: Dictionary = celle[a]
	var ds: float = cb["s"] - ca["s"]
	if ds > lunghezza / 2.0:
		ds -= lunghezza
	elif ds < -lunghezza / 2.0:
		ds += lunghezza
	var parti := []
	if ds > 0.3:
		parti.append("avanti")
	elif ds < -0.3:
		parti.append("dietro")
	if cb["corsia"] < ca["corsia"]:
		parti.append("verso l'interno")
	elif cb["corsia"] > ca["corsia"]:
		parti.append("verso l'esterno")
	return ", ".join(parti) if parti.size() else "accanto"

func nome_corsia(c: int) -> String:
	return ["corsia interna", "corsia centrale", "corsia esterna"][c]

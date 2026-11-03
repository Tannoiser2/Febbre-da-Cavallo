class_name Pista
extends RefCounted
## Geometria e collegamenti delle caselle della pista ovale.
## Unità: 1 = 1 cm (i pezzi stampati: rettilineo 7,8 x 23,7 cm con 3 corsie e 4 file; curva a 90 gradi
## con 1 casella nella corsia interna, 2 in quella centrale e 3 in quella esterna).
## Le caselle si percorrono in senso antiorario visto dall'alto: rettilineo in basso verso +X,
## curva a destra, rettilineo in alto verso -X, curva a sinistra e di nuovo al traguardo.

const PARTENZA := -1
const TRAGUARDO := -2
const CORSIE := 3
const LARG_CORSIA := 2.33
const R0 := 3.75            # raggio del bordo interno della prima corsia
const BORDO := 0.4
const LUNG_FILA := 5.8      # lunghezza di una fila nel rettilineo
const FILE_PER_TRATTO := 4
const CELLE_CURVA := [1, 2, 3]   # caselle per corsia in ogni curva da 90 gradi
const R_MEDIO := R0 + LARG_CORSIA * 1.5

var n_rettilinei := 4
var lato := 0.0             # lunghezza di un lato dritto
var lunghezza := 0.0        # lunghezza totale (linea centrale)
var segmenti := []          # {tipo "r"/"c", s0, s1, lato 0/1 (basso/alto), centro: Vector2, phi0}
var celle := []             # vedi _nuova_cella
var corsie := []            # per corsia: elenco ordinato degli id
var file := []              # file dei rettilinei: [id corsia 0, 1, 2]
var succ := {}
var prec := {}
var adiacenti := {}
var colonna := {}          # caselle affiancate da un bordo all'altro (sovrapposte lungo la pista)

func _init(rettilinei: int = 4) -> void:
	n_rettilinei = max(2, rettilinei - rettilinei % 2)
	_costruisci()

# ------------------------------------------------------------------ costruzione
func _costruisci() -> void:
	var k := n_rettilinei / 2
	lato = k * FILE_PER_TRATTO * LUNG_FILA
	var quarto := PI / 2.0 * R_MEDIO
	var s := 0.0
	# rettilineo in basso, curva destra (2 pezzi), rettilineo in alto, curva sinistra (2 pezzi)
	segmenti.append({"tipo": "r", "s0": s, "s1": s + lato, "lato": 0}); s += lato
	for i in 2:
		segmenti.append({"tipo": "c", "s0": s, "s1": s + quarto, "centro": Vector2(lato / 2.0, 0), "phi0": i * PI / 2.0}); s += quarto
	segmenti.append({"tipo": "r", "s0": s, "s1": s + lato, "lato": 1}); s += lato
	for i in 2:
		segmenti.append({"tipo": "c", "s0": s, "s1": s + quarto, "centro": Vector2(-lato / 2.0, 0), "phi0": PI + i * PI / 2.0}); s += quarto
	lunghezza = s
	for l in CORSIE:
		corsie.append([])
	for seg in segmenti:
		if seg["tipo"] == "r":
			var n_file := int(round((seg["s1"] - seg["s0"]) / LUNG_FILA))
			for j in n_file:
				var fila := []
				for l in CORSIE:
					var id := _nuova_cella(l, "r", seg["s0"] + j * LUNG_FILA, seg["s0"] + (j + 1) * LUNG_FILA, file.size())
					fila.append(id)
					corsie[l].append(id)
				file.append(fila)
		else:
			for l in CORSIE:
				var n: int = CELLE_CURVA[l]
				var q: float = (seg["s1"] - seg["s0"]) / n
				for j in n:
					var id := _nuova_cella(l, "c", seg["s0"] + j * q, seg["s0"] + (j + 1) * q, -1)
					corsie[l].append(id)
	for l in CORSIE:
		var c: Array = corsie[l]
		for i in c.size():
			succ[c[i]] = c[i + 1] if i + 1 < c.size() else TRAGUARDO
			prec[c[i]] = c[i - 1] if i > 0 else PARTENZA
	# caselle adiacenti (si toccano per un lato o per uno spigolo, anche a cavallo del traguardo)
	for a in celle:
		var l := []
		for b in celle:
			if a["id"] == b["id"] or absi(a["corsia"] - b["corsia"]) > 1:
				continue
			if _intervalli_toccano(a["s0"], a["s1"], b["s0"], b["s1"]):
				l.append(b["id"])
		adiacenti[a["id"]] = l
	_calcola_colonne()

func _calcola_colonne() -> void:
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

func _nuova_cella(corsia: int, tipo: String, s0: float, s1: float, fila: int) -> int:
	var id := celle.size()
	var r0 := R0 + corsia * LARG_CORSIA
	var r1 := r0 + LARG_CORSIA
	var poly := PackedVector2Array()
	var passi := 1 if tipo == "r" else 8
	for i in passi + 1:
		poly.append(punto(lerpf(s0, s1, float(i) / passi), r0))
	for i in range(passi, -1, -1):
		poly.append(punto(lerpf(s0, s1, float(i) / passi), r1))
	var sc := (s0 + s1) / 2.0
	celle.append({
		"id": id, "corsia": corsia, "tipo": tipo, "fila": fila, "s0": s0, "s1": s1, "s": sc,
		"poly": poly, "centro": punto(sc, (r0 + r1) / 2.0), "dir": direzione(sc),
	})
	return id

func segmento(s: float) -> Dictionary:
	s = fposmod(s, lunghezza)
	for seg in segmenti:
		if s <= seg["s1"] + 0.0001:
			return seg
	return segmenti[-1]

## Punto (x, z) del piano a distanza s lungo la pista e a raggio r dall'asse dell'ovale.
func punto(s: float, r: float) -> Vector2:
	var seg := segmento(s)
	var t: float = fposmod(s, lunghezza) - seg["s0"]
	if seg["tipo"] == "r":
		if seg["lato"] == 0:
			return Vector2(-lato / 2.0 + t, r)
		return Vector2(lato / 2.0 - t, -r)
	var phi: float = seg["phi0"] + t / R_MEDIO
	return seg["centro"] + Vector2(sin(phi), cos(phi)) * r

## Direzione di marcia (versore x, z) alla distanza s.
func direzione(s: float) -> Vector2:
	var a := punto(s - 0.05, R_MEDIO)
	var b := punto(s + 0.05, R_MEDIO)
	return (b - a).normalized()

# ------------------------------------------------------------------ movimento
func passi_avanti(id: int) -> Array:
	if id == PARTENZA:
		return file[0].duplicate()
	var n: int = succ[id]
	if n == TRAGUARDO:
		return [TRAGUARDO]
	if celle[id]["tipo"] == "r" and celle[n]["tipo"] == "r":
		return file[celle[n]["fila"]].duplicate()
	return [n]

func passi_indietro(id: int) -> Array:
	if id == PARTENZA:
		return []
	var p: int = prec[id]
	if p == PARTENZA:
		return []
	if celle[id]["tipo"] == "r" and celle[p]["tipo"] == "r":
		return file[celle[p]["fila"]].duplicate()
	return [p]

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
	# trova a quale livello si trova 'a' (l'ultimo, salvo il traguardo raggiunto prima)
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

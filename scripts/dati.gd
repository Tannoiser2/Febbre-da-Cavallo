class_name Dati
extends RefCounted
## Dati fissi del gioco: cavalli, token, dado, frasi del cronista.

const CAVALLI := [
	{"nome": "Saetta", "colore": "#d62828"},
	{"nome": "Ciambella", "colore": "#f2c200"},
	{"nome": "Tornado", "colore": "#1f5fd6"},
	{"nome": "Trottolino", "colore": "#2a9d3f"},
	{"nome": "Mandrakino", "colore": "#8e44ad"},
	{"nome": "Polpetta", "colore": "#f77f00"},
	{"nome": "Caramella", "colore": "#ff5fa2"},
	{"nome": "Nerone", "colore": "#2b2b2b"},
]

## Facce del dado movimento: n = caselle, v = pallino verde (si pesca un TOKEN),
## e = "+N -N" (il giocatore sceglie se andare avanti o indietro). Le altre facce vanno solo avanti.
const DADO := [
	{"n": 1, "v": true, "e": false},
	{"n": 1, "v": false, "e": true},
	{"n": 2, "v": true, "e": false},
	{"n": 2, "v": false, "e": false},
	{"n": 2, "v": false, "e": true},
	{"n": 3, "v": true, "e": false},
]

static func testo_faccia(f: Dictionary) -> String:
	if f.get("e", false):
		return "+%d -%d" % [f["n"], f["n"]]
	return "+%d" % f["n"]

## I 20 TOKEN movimento del sacchetto: tipo -> quanti, nome, spiegazione breve
const TOKEN := {
	"piu1": {"n": 3, "nome": "Più uno", "testo": "Il cavallo avanza di 1 casella."},
	"piu2": {"n": 2, "nome": "Più due", "testo": "Il cavallo avanza di 2 caselle."},
	"piu3": {"n": 1, "nome": "Più tre", "testo": "Il cavallo avanza di 3 caselle."},
	"supera": {"n": 2, "nome": "Sorpasso", "testo": "Supera il cavallo davanti."},
	"attiva": {"n": 2, "nome": "Sveglia", "testo": "Riattiva un cavallo a scelta."},
	"tre": {"n": 1, "nome": "Volata a tre", "testo": "Tre cavalli a scelta avanzano di 2 caselle."},
	"disattiva": {"n": 2, "nome": "Pennichella", "testo": "Disattiva un cavallo a scelta."},
	"indietro": {"n": 2, "nome": "Retromarcia", "testo": "Il cavallo torna dov'era."},
	"salta": {"n": 1, "nome": "Salta il turno", "testo": "Il prossimo giocatore salta il turno."},
	"azzoppato": {"n": 1, "nome": "Azzoppato", "testo": "Il cavallo esce dalla pista per un turno."},
	"allarme": {"n": 1, "nome": "Spazzata", "testo": "Via tutti i token dietro l'ultimo cavallo."},
	"sorpresa": {"n": 2, "nome": "Nuovo giro", "testo": "Tutti i cavalli si rialzano e c'è la corsa al dado per tutti!"},
}

const VALORI_TALLONCINI := [1, 2, 3, 4, 5]
const LETTERE_PILE := ["A", "B", "C", "D", "E", "F", "G", "H"]

static func colore(i: int) -> Color:
	return Color(CAVALLI[i]["colore"])

static func nome(i: int) -> String:
	return CAVALLI[i]["nome"]

static func sacchetto_pieno() -> Array:
	var s := []
	for t in TOKEN:
		for i in TOKEN[t]["n"]:
			s.append(t)
	return s

## Frasi del cronista (il tuo avatar). {c} = cavallo, {g} = giocatore, {n} = numero
const FRASI := {
	"benvenuto": [
		"Benvenuti all'ippodromo di Natale! Inquadrate il codice col telefono e venite a puntare.",
		"Signori, l'ippodromo è aperto! Prendete il telefono e inquadrate il codice.",
	],
	"arriva": [
		"Ecco {g}! Un'altra vittima delle scommesse.",
		"Benvenuto {g}, accomodati in tribuna.",
		"È arrivato {g}: si sente già l'odore dei soldi.",
		"{g} è dei nostri! Speriamo che porti fortuna.",
	],
	"pile": [
		"Ognuno scelga la sua pila di talloncini. Guardateli di nascosto, mi raccomando!",
		"È il momento delle puntate: scegliete una pila sul telefono, e acqua in bocca!",
	],
	"partenza": [
		"I cavalli sono ai nastri di partenza. E... via!",
		"Silenzio in tribuna... si parteee!",
	],
	"turno": [
		"Tocca a {g}!",
		"La sorte ha scelto {g}.",
		"Sveglia {g}, tocca a te!",
		"{g}, il destino dei cavalli è nelle tue mani.",
		"Vediamo cosa combina {g}.",
	],
	"avanti": [
		"{c} avanza!",
		"Vai {c}, vai!",
		"{c} prende il galoppo!",
		"Che falcata, {c}!",
	],
	"indietro": [
		"{c} torna indietro! Che cattiveria.",
		"Ahia, {c} arretra. Qualcuno non ci ha puntato.",
		"Indietro tutta per {c}! Sospetto, molto sospetto.",
	],
	"nessuna": [
		"Nessun cavallo si può muovere. Si passa!",
		"Tutti bloccati! Niente da fare stavolta.",
	],
	"token": [
		"Attenzione, c'è un token!",
		"Oh oh, cosa abbiamo qui?",
		"Un token sulla pista!",
	],
	"ripristino": [
		"Tutti i cavalli hanno corso: si rialzano tutte le teste!",
		"Giro completato, tutti i cavalli di nuovo pronti!",
	],
	"corsa_dado": [
		"Corsa al dado! Chi prende per primo il dado migliore?",
		"Attenzione: corsa al dado! Veloci col dito!",
	],
	"preso": [
		"{g} è stato il più veloce!",
		"{g} se l'è preso al volo!",
	],
	"salta": [
		"{g} salta il turno. Peccato!",
		"Niente da fare per {g}, salta il giro.",
	],
	"azzoppato": [
		"Povero {c}, si è azzoppato! Fuori per un turno.",
	],
	"rientra": [
		"{c} rientra in pista, un po' acciaccato.",
	],
	"testa": [
		"{c} è in testa!",
		"Al comando c'è {c}!",
	],
	"traguardo": [
		"Ha vinto {c}! Che corsa, signori!",
		"{c} taglia il traguardo per primo! Vittoria!",
	],
	"svela": [
		"E ora, il momento della verità: vediamo chi ci aveva puntato!",
	],
	"vince": [
		"{g} vince {n}!",
		"Complimenti {g}, porti a casa {n}!",
	],
	"nessuno_vince": [
		"Nessuno ci aveva puntato! Il banco ringrazia.",
	],
	"aspetta": [
		"Dai {g}, che si raffreddano i cavalli!",
		"{g}, sei ancora con noi?",
		"Forza {g}, decidi!",
	],
	"ci_penso_io": [
		"Ci penso io per {g}!",
	],
}

static func frase(chiave: String, d: Dictionary = {}) -> String:
	var l: Array = FRASI.get(chiave, [chiave])
	var t: String = l[randi() % l.size()]
	for k in d:
		t = t.replace("{" + k + "}", str(d[k]))
	return t

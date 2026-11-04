class_name Dati
extends RefCounted
## Dati fissi del gioco: cavalli, token, dado, frasi del cronista.

const CAVALLI := [
	{"nome": "King", "colore": "#d62828"},
	{"nome": "Soldatino", "colore": "#f2c200"},
	{"nome": "Dartagnan", "colore": "#1f5fd6"},
	{"nome": "Apocalisse", "colore": "#2a9d3f"},
	{"nome": "Can Can", "colore": "#8e44ad"},
	{"nome": "Piripicchio", "colore": "#f77f00"},
	{"nome": "'O Sole Mio", "colore": "#ff5fa2"},
	{"nome": "Uragano", "colore": "#2b2b2b"},
]

## I ritratti dei protagonisti: ogni giocatore ne sceglie uno (diverso dagli altri) quando entra
const RITRATTI := [
	{"id": "mandrake", "nome": "Mandrake"},
	{"id": "pomata", "nome": "Pomata"},
	{"id": "felice", "nome": "Felice"},
	{"id": "gabriella", "nome": "Gabriella"},
	{"id": "giuliana", "nome": "Giuliana"},
	{"id": "mafalda", "nome": "Mafalda"},
	{"id": "avvocato", "nome": "Avvocato De Marchis"},
	{"id": "giudice", "nome": "Giudice"},
	{"id": "manzotin", "nome": "Manzotin"},
	{"id": "ventresca", "nome": "Ventresca"},
]

static func nome_ritratto(id: String) -> String:
	for r in RITRATTI:
		if r["id"] == id:
			return r["nome"]
	return ""

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
	"azzoppato": {"n": 1, "nome": "Azzoppato", "testo": "Il cavallo esce dalla pista fino al turno dopo, quando rientra Disattivato."},
	"allarme": {"n": 1, "nome": "Spazzata", "testo": "Via tutti i token dietro l'ultimo cavallo."},
	"sorpresa": {"n": 2, "nome": "Nuovo giro", "testo": "Tutti i cavalli si rialzano e c'è la corsa al dado per tutti!"},
}

const VALORI_TALLONCINI := [1, 2, 3, 4, 5]
const VALORI_TALLONCINI_CARTE := [1, 2, 3, 4]

## Versione con le carte: 32 carte (assets/carte/cNN.webp, la parte bassa in sNN.webp).
## "su" = effetto quando la carta si pesca, "giu" = effetto quando un cavallo finisce nella sua colonna,
## "scarta" = dopo l'effetto di sotto la carta lascia la pista e torna nel mazzo.
const CARTE := [
	{"titolo": "Via come il vento!", "su": "piu1", "giu": "piu2", "scarta": false},
	{"titolo": "Zizzignor Conte", "su": "disattiva", "giu": "piu1", "scarta": false},
	{"titolo": "Nervoso?", "su": "disattiva", "giu": "ultimo3", "scarta": false},
	{"titolo": "Ciò un cavallo che vince!", "su": "piu1", "giu": "piu2", "scarta": false},
	{"titolo": "Ci rifacciamo", "su": "attiva", "giu": "ultimo2", "scarta": false},
	{"titolo": "So' rovinato!!!", "su": "rimescola", "giu": "azzoppato", "scarta": false},
	{"titolo": "Ho un piano!", "su": "salta", "giu": "salta", "scarta": false},
	{"titolo": "Un whisky maschio", "su": "attiva", "giu": "piu1", "scarta": false},
	{"titolo": "È un foco de paia...", "su": "piu2", "giu": "supera", "scarta": false},
	{"titolo": "Manzotin!", "su": "piu1", "giu": "supera", "scarta": false},
	{"titolo": "'So un tantino preoccupato", "su": "indietro", "giu": "disattiva", "scarta": false},
	{"titolo": "Un etto di carne", "su": "supera", "giu": "attiva", "scarta": false},
	{"titolo": "E' 'na Mandrakata", "su": "supera", "giu": "attiva", "scarta": false},
	{"titolo": "Sorriso maggico", "su": "piu3", "giu": "supera", "scarta": false},
	{"titolo": "Si te pio!!!", "su": "indietro", "giu": "disattiva", "scarta": false},
	{"titolo": "Dico! 1, 14 e 4", "su": "piu4", "giu": "piu3", "scarta": false},
	{"titolo": "...Uragano e Apocalisse", "su": "indietro", "giu": "piu3", "scarta": true},
	{"titolo": "Piripicchio è figlio di...", "su": "piu3", "giu": "piu1", "scarta": true},
	{"titolo": "Cravatta giallorossa", "su": "piu1", "giu": "piu3", "scarta": true},
	{"titolo": "Dr. Magalini", "su": "supera", "giu": "supera", "scarta": true},
	{"titolo": "Sono... 47.500 lire", "su": "paga", "giu": "piu2", "scarta": true},
	{"titolo": "A buffoni!!!", "su": "indietro", "giu": "azzoppato", "scarta": true},
	{"titolo": "Sarvate Mandrà", "su": "salta", "giu": "salta", "scarta": true},
	{"titolo": "Disperati!!!", "su": "meno2", "giu": "azzoppato", "scarta": true},
	{"titolo": "'A tris de Gabriella", "su": "piu1", "giu": "tre", "scarta": true},
	{"titolo": "Er Ventresca", "su": "salta", "giu": "salta", "scarta": true},
	{"titolo": "...E lo guida Bocconi", "su": "piu4", "giu": "supera2", "scarta": true},
	{"titolo": "Non prendere soldi", "su": "paga", "giu": "azzoppato", "scarta": true},
	{"titolo": "Dispositivo di risposta", "su": "piu2", "giu": "riattivato", "scarta": true},
	{"titolo": "...Manco tu che sei pratica", "su": "paga", "giu": "primo_dis", "scarta": true},
	{"titolo": "Pora nonna", "su": "primo_dis", "giu": "salta", "scarta": true},
	{"titolo": "'So un tantino preoccupato", "su": "meno2", "giu": "primo_dis", "scarta": true},
]

## Testo degli effetti delle carte (anche quelli in più rispetto ai token)
const EFFETTI := {
	"piu1": "Il cavallo avanza di 1 casella.", "piu2": "Il cavallo avanza di 2 caselle.",
	"piu3": "Il cavallo avanza di 3 caselle.", "piu4": "Il cavallo avanza di 4 caselle.",
	"meno2": "Il cavallo arretra di 2 caselle.", "supera": "Supera il cavallo davanti.",
	"supera2": "Supera i due cavalli davanti.", "attiva": "Riattiva un cavallo a scelta.",
	"disattiva": "Disattiva un cavallo a scelta.", "indietro": "Il cavallo torna dov'era.",
	"salta": "Il prossimo giocatore salta il turno.", "azzoppato": "Il cavallo è azzoppato.",
	"tre": "Tre cavalli a scelta avanzano di 2 caselle.", "ultimo2": "L'ultimo cavallo avanza di 2 caselle.",
	"ultimo3": "L'ultimo cavallo avanza di 3 caselle.", "primo_dis": "Il primo cavallo viene disattivato.",
	"riattivato": "Il cavallo resta attivo.", "rimescola": "Le carte sulla pista tornano nel mazzo.",
	"paga": "Chi l'ha pescata paga un'altra quota al montepremi.",
}
const LETTERE_PILE := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]

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

## Frasi del cronista (il tuo avatar). {c} = cavallo, {g} = giocatore, {n} = numero o premio
const FRASI := {
	"benvenuto": [
		"Benvenuti all'ippodromo di Natale! Inquadrate il codice col telefono e venite a puntare.",
		"Signori, l'ippodromo è aperto! Prendete il telefono e inquadrate il codice.",
		"Buonasera e benvenuti! Stasera i cavalli corrono e i soldi pure.",
		"Avanti, avanti! Chi entra adesso trova ancora il posto in tribuna.",
		"Qui si vince, si perde, ma soprattutto si litiga. Inquadrate il codice!",
		"L'ippodromo apre i cancelli: telefoni alla mano, signori!",
	],
	"arriva": [
		"Ecco {g}! Un'altra vittima delle scommesse.",
		"Benvenuto {g}, accomodati in tribuna.",
		"È arrivato {g}: si sente già l'odore dei soldi.",
		"{g} è dei nostri! Speriamo che porti fortuna.",
		"Largo, largo: arriva {g}!",
		"{g}, ti avverto: qui nessuno esce con il portafoglio pieno.",
		"Guarda chi si vede: {g}! Stasera ti sento in forma.",
		"{g} entra in tribuna con l'aria di chi sa qualcosa...",
		"Applausi per {g}, il re delle scommesse!",
		"Anche {g} ha la febbre da cavallo, si vede subito.",
	],
	"pile": [
		"Ognuno scelga la sua pila di talloncini. Guardateli di nascosto, mi raccomando!",
		"È il momento delle puntate: scegliete una pila sul telefono, e acqua in bocca!",
		"Pile di talloncini per tutti! Chi sceglie per primo sceglie meglio... forse.",
		"Talloncini sul tavolo: prendete la vostra pila e non fate vedere niente al vicino.",
		"Scegliete la pila, guardate i cavalli e fate finta di niente. Faccia da poker!",
	],
	"partenza": [
		"I cavalli sono ai nastri di partenza. E... via!",
		"Silenzio in tribuna... si parteee!",
		"Scattano i cancelli! Che la corsa abbia inizio!",
		"Ecco la partenza! Otto cavalli e un solo vincitore.",
		"Si parte! E che vinca il più furbo, non il più veloce.",
	],
	"turno": [
		"Tocca a {g}!",
		"La sorte ha scelto {g}.",
		"Sveglia {g}, tocca a te!",
		"{g}, il destino dei cavalli è nelle tue mani.",
		"Vediamo cosa combina {g}.",
		"Forza {g}, tira quel dado!",
		"{g}, fai la tua mossa. Tutti ti guardano!",
		"Microfono a {g}!",
		"È il turno di {g}: occhio, che è uno furbo.",
		"Ecco {g}, con lo sguardo di chi ha un piano.",
		"{g}, niente scherzi eh!",
		"Adesso tocca a {g}. Si accettano scommesse.",
	],
	"tira": [
		"Rotola il dado...",
		"E il dado dice...",
		"Il dado gira, gira...",
		"Vediamo cosa esce!",
		"Dado in pista!",
	],
	"verde": [
		"Pallino verde! Si pesca un token!",
		"Uh, il pallino verde: arrivano le sorprese!",
		"Verde! Qualcosa sta per succedere...",
		"Il pallino verde porta guai. O fortuna.",
	],
	"avanti": [
		"{c} avanza!",
		"Vai {c}, vai!",
		"{c} prende il galoppo!",
		"Che falcata, {c}!",
		"{c} macina terreno!",
		"Guardate {c}, sembra un treno!",
		"{c} non si ferma più!",
		"Ottima scelta, {c} vola!",
		"{c} allunga il passo!",
		"Galoppa {c}, galoppa!",
		"{c} sente l'odore del traguardo!",
		"Che bella azione di {c}!",
	],
	"indietro": [
		"{c} torna indietro! Che cattiveria.",
		"Ahia, {c} arretra. Qualcuno non ci ha puntato.",
		"Indietro tutta per {c}! Sospetto, molto sospetto.",
		"Ma che fa {c}, il gambero?",
		"{c} va in retromarcia! Chi ha i suoi talloncini piange.",
		"Ecco il colpo basso: {c} indietro!",
		"Povero {c}, gli hanno tirato le redini!",
		"{c} indietreggia. Qui c'è sotto qualcosa...",
	],
	"nessuna": [
		"Nessun cavallo si può muovere. Si passa!",
		"Tutti bloccati! Niente da fare stavolta.",
		"Ingorgo in pista! Nessuna mossa possibile.",
		"Niente da fare, i cavalli non si schiodano.",
	],
	"ripristino": [
		"Tutti i cavalli hanno corso: si rialzano tutte le teste!",
		"Giro completato, tutti i cavalli di nuovo pronti!",
		"Teste alte, signori: nuovo turno per tutti i cavalli!",
		"I cavalli hanno ripreso fiato. Si riparte!",
		"Tutti di nuovo in forma: ogni cavallo si può muovere!",
	],
	"corsa_dado": [
		"Corsa al dado! Chi prende per primo il dado migliore?",
		"Attenzione: corsa al dado! Veloci col dito!",
		"Dadi in tavola! Il più svelto sceglie per primo!",
		"Chi dorme non piglia dadi! Corsa al dado!",
		"Pronti, partenza... prendete un dado!",
	],
	"preso": [
		"{g} è stato il più veloce!",
		"{g} se l'è preso al volo!",
		"Che riflessi, {g}!",
		"{g} ha la mano più lesta dell'ippodromo!",
		"Primo {g}! Ma giocherà per ultimo...",
	],
	"salta": [
		"{g} salta il turno. Peccato!",
		"Niente da fare per {g}, salta il giro.",
		"{g}, stavolta guardi e basta.",
		"Fermo un giro, {g}! È la legge della clessidra.",
	],
	"azzoppato": [
		"Povero {c}, si è azzoppato! Resta fuori per tutto questo turno.",
		"Ahi ahi, {c} zoppica! Fuori dalla pista per un po'.",
		"Chiamate il veterinario: {c} si è fatto male!",
		"{c} si siede a bordo pista. Che sfortuna!",
	],
	"rientra": [
		"{c} rientra in pista, un po' acciaccato.",
		"Bentornato {c}! Ma ancora con la testa bassa.",
		"{c} torna in gara, zoppicando un po'.",
	],
	"testa": [
		"{c} è in testa!",
		"Al comando c'è {c}!",
		"{c} passa al comando della corsa!",
		"Nuovo leader: {c}!",
		"Tutti dietro a {c}!",
		"{c} si prende la testa della corsa. Chi ci ha puntato sorride!",
	],
	"quasi": [
		"{c} vede il traguardo!",
		"Ultimi metri per {c}!",
		"{c} è vicinissimo all'arrivo!",
		"Attenzione, {c} può vincere da un momento all'altro!",
		"{c} sente già il profumo della vittoria!",
	],
	"traguardo": [
		"Ha vinto {c}! Che corsa, signori!",
		"{c} taglia il traguardo per primo! Vittoria!",
		"Vittoria di {c}! L'ippodromo esplode!",
		"{c} vince! Chi ci aveva puntato può stappare lo spumante!",
		"È finita! Primo all'arrivo: {c}!",
	],
	"svela": [
		"E ora, il momento della verità: vediamo chi ci aveva puntato!",
		"Fuori i talloncini! Vediamo chi ride e chi piange.",
		"Si svelano le puntate. Rullo di tamburi...",
	],
	"vince": [
		"{g} vince {n}!",
		"Complimenti {g}, porti a casa {n}!",
		"{g} incassa {n}! Offri tu il panettone?",
		"Che colpo, {g}: {n}!",
		"{g} si mette in tasca {n}!",
	],
	"nessuno_vince": [
		"Nessuno ci aveva puntato! Il banco ringrazia.",
		"Nessun talloncino vincente! Tutto al banco.",
	],
	"aspetta": [
		"Dai {g}, che si raffreddano i cavalli!",
		"{g}, sei ancora con noi?",
		"Forza {g}, decidi!",
		"{g}, guarda che il panettone finisce!",
		"Ehi {g}, il telefono è acceso?",
		"{g}, qui si invecchia!",
		"Pronto, {g}? I cavalli aspettano!",
	],
	"ci_penso_io": [
		"Ci penso io per {g}!",
		"{g} dorme: decido io!",
		"Va bene {g}, faccio io. Poi non ti lamentare!",
	],
}

## Frase colorita per ogni token, prima della spiegazione dell'effetto
const FRASI_TOKEN := {
	"piu1": ["Un passettino in più!", "Piccola spinta!", "Un altro passo, dai!"],
	"piu2": ["Due caselle di regalo!", "Turbo!", "Doppia spinta!"],
	"piu3": ["Tre caselle! Che colpo!", "Ha messo il razzo!", "Il jackpot dei token!"],
	"supera": ["Sorpasso in vista!", "Fatevi da parte!", "Si sorpassa!"],
	"attiva": ["Sveglia, dormiglione!", "Caffè per un cavallo!", "Qualcuno si risveglia!"],
	"tre": ["Volata a tre!", "Tre cavalli si scatenano!", "Galoppo di gruppo!"],
	"disattiva": ["Pennichella!", "Qualcuno va a dormire!", "Nanna per un cavallo!"],
	"indietro": ["Retromarcia!", "Ritorno al passato!", "Contrordine, si torna indietro!"],
	"salta": ["Clessidra!", "Il tempo si ferma!", "Uno resta a guardare!"],
	"azzoppato": ["Ahi, che botta!", "Infortunio in pista!", "Che sfortuna nera!"],
	"allarme": ["Allarme! Si fa pulizia!", "Spazzata generale!", "Via tutto quello che sta dietro!"],
	"sorpresa": ["Punto interrogativo! Nuovo giro!", "Il mistero del punto interrogativo!", "Sorpresa generale!"],
}

## Tutte le pose del cronista (assets/avatar/<nome>.webp, le stesse di Mercante in fiera)
const TUTTE_POSE := ["abbraccio", "affare", "applaude", "attesa", "attesa_b", "attesa_occhi", "base", "brindisi", "busta", "busta_premio", "campanella", "carretto", "carta", "carta_b", "conta1", "conta2", "conta3", "disperato", "doppietta", "festeggia", "inchino", "indica", "indica_b", "lacrima", "lente", "martello", "megafono", "mercato", "occhiolino", "occhiolino_b", "orecchio", "orologio", "parla", "parla_b", "parla_c", "pausa", "pensa", "pensieroso", "pergamena", "regalo", "ride", "rullo", "sacco_aperto", "saluta", "sbadiglio", "soldi", "soldi_pioggia", "sorpreso", "stretta", "sussurra", "tensione", "tripletta", "triste", "triste_b", "trofeo", "wow"]

## Per ogni posa chiesta se ne sceglie una simile, così il cronista cambia spesso espressione
const VARIANTI_POSA := {
	"parla": ["parla", "parla_b", "parla_c", "mercato", "abbraccio", "megafono", "occhiolino_b"],
	"indica": ["indica", "indica_b", "occhiolino_b", "megafono"],
	"saluta": ["saluta", "inchino", "abbraccio", "wow", "stretta"],
	"sorpreso": ["sorpreso", "wow", "disperato", "tensione", "lente"],
	"ride": ["ride", "applaude", "occhiolino", "festeggia"],
	"festeggia": ["festeggia", "applaude", "trofeo", "brindisi", "soldi_pioggia", "campanella"],
	"triste": ["triste", "triste_b", "lacrima", "disperato"],
	"pensa": ["pensa", "pensieroso", "lente", "orecchio"],
	"occhiolino": ["occhiolino", "occhiolino_b", "affare", "base"],
	"sussurra": ["sussurra", "orecchio", "affare"],
	"soldi": ["soldi", "soldi_pioggia", "busta_premio", "trofeo"],
	"busta": ["busta", "carta", "carta_b", "pergamena", "sacco_aperto"],
	"aspetta": ["orologio", "sbadiglio", "attesa", "attesa_b", "attesa_occhi", "pausa"],
	"suspense": ["rullo", "tensione", "campanella", "megafono"],
}

static func frase_token(t: String) -> String:
	var l: Array = FRASI_TOKEN.get(t, [""])
	return l[randi() % l.size()]

static func frase(chiave: String, d: Dictionary = {}) -> String:
	var l: Array = FRASI.get(chiave, [chiave])
	var t: String = l[randi() % l.size()]
	for k in d:
		t = t.replace("{" + k + "}", str(d[k]))
	return t

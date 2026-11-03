# Febbre da Cavallo - l'ippodromo di Natale

Versione digitale del gioco di corse e scommesse ispirato al film, pensata per la serata in famiglia:

- **la TV** (un iPad o un computer collegato al televisore) mostra l'ippodromo in 3D: la pista ovale a caselle
  come i pezzi stampati, gli otto cavalli animati con il nome sopra, i token, la tribuna e il **cronista**
  (l'avatar di Stefano) che commenta con il fumetto e con la voce;
- **ogni giocatore** inquadra il QR code con il telefono, scrive il nome ed è dentro: sceglie la pila di
  talloncini, tira il dado e sceglie cavallo, direzione e casella. Sul telefono si possono toccare **solo
  le scelte valide**.

Si gioca qui: **https://tannoiser2.github.io/Febbre-da-Cavallo/** (sulla TV: *Apri l'ippodromo*).
I telefoni aprono `telefono.html` dal QR code, oppure scrivono il codice di 4 lettere.

## Come si gioca

1. **Sala d'attesa** - la TV mostra il QR code e il codice. Da 2 a 8 giocatori. Le regole della casa:
   lunghezza della pista (2, 4 o 6 rettilinei con le 4 curve), posta a testa (15 euro come nel regolamento,
   oppure 3, 1,50 o per gioco), quando scattano i token sulla pista, corsa al dado sì/no.
2. **Le pile** - i 40 talloncini (8 cavalli x quote da 1 a 5) sono mescolati in 8 pile da 5. Ognuno sceglie
   una pila dal telefono e la guarda di nascosto (*Guarda di nascosto* / *Nascondi*). Il montepremi è
   diviso in 15 quote.
3. **La corsa** - a ogni turno **la sorte estrae chi gioca** (non si va in senso orario), ma una sola volta per
   giro: chi ha già giocato aspetta che abbiano giocato tutti, poi si ricomincia. Il giocatore tira il dado dal
   telefono, sceglie un cavallo **Attivo** (testa alta) e, con le facce *+N -N*, se usare +N o -N; poi la casella
   d'arrivo se ce n'è più d'una (le caselle possibili compaiono numerate sulla pista, sulla TV). Il cavallo mosso abbassa la testa (Disattivo); quando tutti
   sono Disattivi si rialzano tutti.
   - nei rettilinei si cambia corsia liberamente, nelle curve no (la corsia interna ha 1 casella per curva,
     quella centrale 2, l'esterna 3, come nei pezzi stampati);
   - non ci si ferma mai su un altro cavallo, ma lo si può scavalcare;
   - il **dado**: +1 col pallino, +1 -1, +2 col pallino, +2, +2 -2, +3 col pallino;
   - con il **pallino verde** si pesca un TOKEN dal sacchetto, oppure si usa quello già presente nella
     **colonna** della casella: un token vale per tutte le caselle affiancate da un bordo all'altro della pista
     (sulla TV la colonna è colorata d'azzurro). Chi lo ha pescato decide cavallo e casella quando serve.
4. **Corsa al dado** - ogni tanto (con almeno 3 giocatori) la TV tira 2 dadi (3 con più di 5 giocatori),
   estrae altrettanti giocatori, anche fra quelli che hanno già giocato nel giro, e sui loro telefoni compaiono i dadi: si fa a gara a
   prenderli, e ogni dado preso scende sotto con il nome di chi l'ha preso. Poi tutti giocano il loro dado, **dal più lento al più
   veloce**: chi l'ha preso per primo gioca per ultimo.
5. **Arrivo e premi** - vince il primo cavallo che oltrepassa l'ultima casella. Si svelano le puntate:
   ognuno incassa tante quote quanti sono i punti dei suoi talloncini del cavallo vincente. Sul telefono di
   chi vince compare *HAI VINTO!* con il premio. La TV tiene il saldo della serata; *Un'altra corsa!*
   riparte con gli stessi giocatori.

### I token (20 nel sacchetto)

| Token | Quanti | Effetto |
|---|---|---|
| +1, +2, +3 | 3, 2, 1 | il cavallo avanza ancora |
| Sorpasso | 2 | supera il cavallo davanti |
| Sveglia | 2 | riattiva un cavallo a scelta (non quello appena mosso, se possibile) |
| Volata a tre | 1 | tre cavalli a scelta avanzano di 2 (anche Disattivi) |
| Pennichella | 2 | disattiva un cavallo a scelta |
| Retromarcia | 2 | il cavallo torna dov'era |
| Salta il turno | 1 | il prossimo giocatore estratto salta il turno |
| Azzoppato | 1 | il cavallo esce dalla pista e rientra al turno dopo, Disattivo |
| Spazzata (!) | 1 | tornano nel sacchetto lei e tutti i token dietro l'ultimo cavallo |
| Nuovo giro (?) | 2 | tutti i cavalli tornano Attivi, si apre un nuovo giro e a fine turno c'è la corsa al dado per tutti i giocatori |

I token restano sulla pista: tornano nel sacchetto solo quelli dietro l'ultimo cavallo quando esce la Spazzata (!),
e la Volata a tre e l'Azzoppato quando un cavallo ci capita sopra.
Nella sala d'attesa, **Sacchetto** sceglie quanti token di ogni tipo ci sono (*Come nel gioco* rimette la tabella
qui sopra) e **Effetto multiplo** attiva la versione cattiva: se un token porta un cavallo (avanti o indietro) su un
altro token, scatta anche quello, e così via; ogni token vale una volta sola per catena, così non si gira all'infinito.
Sulla TV i token stanno sul prato, fuori dal bordo esterno, all'altezza della loro colonna (colorata d'azzurro).
I cavalli Disattivi diventano grigi; il cavallo azzoppato si accascia a lato della pista col muso a terra e
rientra Disattivo al turno successivo. Nella sala d'attesa si sceglie anche la velocità: lenta, normale, veloce.

**Scelte fatte dove il regolamento non lo dice** (si cambiano facilmente in `scripts/dati.gd`):
- le quantità dei token sono quelle della tabella qui sopra;

## Comandi sulla TV

In alto a sinistra: **Schermo intero**, **Voce sì/no**, **Decidi tu** (se qualcuno si è addormentato: la TV
sceglie al suo posto; lo fa comunque da sola dopo 90 secondi, 25 nella corsa al dado). Se la TV si ricarica,
nella sala d'attesa compare **Riprendi la corsa interrotta** accanto a **Nuova corsa!**: si riparte dall'ultimo
turno con la stanza e i telefoni di prima, oppure si ricomincia da capo. Ogni volta che si apre la TV la stanza ha
un **codice nuovo**: i telefoni della volta precedente restano fuori.

## Consigli per la serata

- iPad: Safari, *Condividi*, *Aggiungi alla schermata Home*, poi AirPlay o cavo HDMI sulla TV, volume alto.
  Il tocco su *Apri l'ippodromo* attiva la voce e i suoni.
- Voce del cronista: è quella del dispositivo. Sull'iPad conviene scaricare una voce italiana *Premium* o
  *Avanzata* (Impostazioni, Accessibilità, Contenuti letti ad alta voce, Voci, Italiano).
- Tutti i telefoni devono essere online (Wi-Fi o dati). I soldi sono veri solo alla fine: il saldo della
  serata dice chi deve mettere e chi ritirare.

## Per chi lo sviluppa

- `scripts/` - Godot 4.7 (gl_compatibility): `motore.gd` le regole (senza grafica), `pista.gd` le caselle e i
  collegamenti, `ippodromo.gd` il mondo 3D, `cavallo3d.gd` + `shaders/cavallo.gdshader` il cavallo animato
  (zampe, testa alta o bassa, coda: tutto nel vertex shader, senza scheletro), `interfaccia.gd` l'interfaccia,
  `vista.gd` le animazioni chieste dal motore, `main.gd` la TV, `rete.gd` il ponte con la pagina web.
- `web/` - la pagina della TV (`shell.html`, usata da Godot come modello), il ponte `js/ponte.js`, la pagina
  dei telefoni (`telefono.html`, `js/telefono.js`, `css/telefono.css`), `js/rete.js` (Firebase o rete locale)
  e `js/suoni.js` (suoni sintetizzati e voce).
- `assets/` - il cavallo (dal file `Horse.stl`, alleggerito), le icone dei token ritagliate dalla foto dei
  token, le pose dell'avatar, il titolo, i font Bangers e Barlow Condensed.
- **Firebase**: progetto condiviso della ludoteca, radice `febbre/rooms/<CODICE>`. Le regole sono in
  `firebase/database.rules.json`: il blocco `"febbre"` va aggiunto accanto agli altri giochi nella console
  (Realtime Database, Regole). I talloncini di ogni giocatore stanno in `segreti/<uid>`, leggibili solo da
  lui e dalla TV.
- Prove:
  - `godot --headless --path . -s tests/sim.gd -- 200` - 200 corse automatiche, controlla le regole;
  - `tools/costruisci_web.sh` - esporta in `build/web` (TV + telefoni);
  - `node tests/browser.mjs build/web /tmp/prova 3 600` - TV e 3 telefoni nel browser con la rete locale;
  - parametri della TV: `?bot=3` giocatori finti, `?auto=1` parte e va avanti da sola, `?veloce=4`,
    `?rete=locale` (telefoni nello stesso browser, senza Firebase);
  - `python3 tools/controlla_glifi.py` - nessun carattere fuori dai font.
- **Pubblicazione**: solo su richiesta, con *Actions, Pubblica, Run workflow* oppure con un commit che contiene
  `[pubblica]`. Con i segreti `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID` va anche sulla ludoteca privata.

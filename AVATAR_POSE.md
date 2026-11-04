# Le pose del cronista (da far disegnare a ChatGPT)

Il gioco usa già le pose di Mercante in fiera (`assets/avatar/*.webp`). Queste sono le **pose nuove da ippodromo**:
basta mettere il file `assets/avatar/<nome>.webp` (WebP 768 x 960, sfondo trasparente) e pubblicare; finché un file
manca, il gioco usa le altre pose.

## Indicazioni comuni (da incollare insieme all'immagine dell'avatar, per esempio `assets/avatar/parla.webp`)

> Usa il personaggio dell'immagine allegata (stesso stile da sticker cartoon, stessa faccia, capelli ricci brizzolati,
> barba corta, occhi grandi, stesso vestito: gilet rosso con bottoni dorati, camicia bianca, papillon verde, cappello
> di Babbo Natale). È il **cronista di un ippodromo a Natale**. Inquadratura a mezzo busto, dalla vita in su, corpo di
> tre quarti verso destra. **Sfondo trasparente**, contorno bianco da sticker, nessuna scritta. PNG 1024 x 1280
> verticale, stessa scala e stessa posizione della testa delle altre pose.

| File | Descrizione per ChatGPT |
|---|---|
| `binocolo.png` | Guarda dentro un binocolo da corsa, concentrato, una mano che regola la rotella. |
| `tifa.png` | Urla di gioia a bocca spalancata, tutti e due i pugni in alto. |
| `schedina.png` | Legge un talloncino di scommessa tenuto con due dita, sopracciglio alzato, aria furba. |
| `disperato.png` | Mani nei capelli, bocca aperta, disperato per una scommessa persa. |
| `microfono.png` | Parla in un vecchio microfono da cronista sportivo, espressione concitata. |
| `cappello.png` | Si leva il cappello di Babbo Natale in segno di saluto, inchino leggero, sorriso. |
| `galoppo.png` | Mima il galoppo con le braccia come se tenesse le redini, molto divertito. |
| `orologio.png` | Guarda l'orologio da polso spazientito, piede che batte, labbra strette. |
| `dado.png` | Tiene alto un grosso dado bianco da gioco come se stesse per tirarlo. |
| `applaude.png` | Applaude con entusiasmo, occhi chiusi dalla contentezza. |

Conversione in WebP (come per Mercante in fiera):
`python3 -c "from PIL import Image; Image.open('tifa.png').resize((768, 960)).save('assets/avatar/tifa.webp', quality=88)"`

# Jonio Taskbar per KDE Plasma 6

Plasmoide QML ispirato alla barra di jonioOS Sila. Per impostazione predefinita usa lo spazio libero del pannello: le app fissate rimangono a sinistra del separatore, quelle aperte occupano la parte centrale e gli altri widget del pannello possono restare a destra. La freccia apre una griglia ricercabile di tutte le applicazioni.

## Installazione

```bash
git clone https://github.com/jonioos/jonio-panel.git
cd jonio-panel
kpackagetool6 --type Plasma/Applet --install .
```

Poi aprire la modalità di modifica di Plasma e inserire **Barra delle applicazioni Jonio** nel pannello, prima degli altri widget da tenere a destra. Nelle impostazioni si può disattivare **Estendi in tutto lo spazio libero del pannello** per tornare alla larghezza compatta.

Per aggiornare dopo modifiche:

```bash
kpackagetool6 --type Plasma/Applet --upgrade .
```

## Uso

- Clic sulla freccia piccola: apre la griglia delle applicazioni. La ricerca filtra i nomi; il piccolo pulsante su ogni voce la fissa nello stack corrente, la sposta lì oppure la rimuove se è già in quello stack.
- Rotella sulla sezione a sinistra del separatore: passa con un'animazione allo stack precedente o successivo. Con un solo stack, scorre le icone orizzontalmente. Il numero di app per stack e il numero di stack si regolano nelle impostazioni.
- Trascinamento col tasto sinistro delle app fissate: riordina le icone nello stack attualmente visibile e salva la nuova posizione.
- Clic sinistro su un'icona: avvia o attiva l'app. Se ci sono più finestre, apre la griglia delle anteprime; il clic su un'anteprima attiva la finestra.
- Passaggio del mouse su un'app aperta: apre le anteprime dopo una breve attesa. Passando sopra una miniatura, il backend di Plasma evidenzia sul desktop la finestra corrispondente. Un clic attiva o ripristina la finestra. Le miniature visibili vengono caricate insieme e rilasciate alla chiusura del popup.
- Clic destro su un'icona: nuova finestra, percorsi e azioni rapide disponibili per l'app, riproduzione/pausa quando supportata, fissaggio e chiusura.
- Clic centrale su un'app aperta: chiude la finestra o il gruppo.
- Clic destro sullo spazio vuoto del widget: apre il menu standard di Plasma con **Configura Barra delle applicazioni Jonio**.

Nelle impostazioni si regolano dimensione icone, spazio tra icone, app per stack, numero di stack, forma degli indicatori, colore personalizzato dei pallini e ritardo prima delle anteprime. L'interruttore **Chiudi il menu passando sopra un'icona della barra** è attivo per impostazione predefinita: disattivandolo, il menu resta aperto e l'anteprima attende la sua chiusura. Si regolano inoltre anteprime e ambito di monitor, desktop virtuali e attività. Per avere barre separate sui monitor, aggiungere il widget su ciascun pannello e scegliere **Solo il monitor di questa barra**.

Le icone iniziali sono Dolphin, Impostazioni di sistema e Kate; si possono rimuovere dal menu contestuale. L'ordine delle app fissate viene mantenuto nella configurazione del widget.

# Trova i monumenti partecipanti a Wiki Loves Monuments
[PROGETTO SU PHABRICATOR ED ISSUE TRACKING](https://phabricator.wikimedia.org/tag/wlm-italy-finder/)
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fferdi2005%2Fwikilovesmonuments.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fferdi2005%2Fwikilovesmonuments?ref=badge_shield)


**IMPORTANTE:** tutti gli issue ed i problemi vengono ora tracciati attraverso la piattaforma phabricator Wikimedia, prego inserire là tutto: [PROGETTO SU PHABRICATOR ED ISSUE TRACKING](https://phabricator.wikimedia.org/tag/wlm-italy-finder/)

# Installazione
* Configurazione: solita procedura per l'installazione di applicazioni Rails (compresa la migrazione del database), andare su /import e cliccare "Import" per fare la prima importazione dei monumenti (cosa che avviene comunque ogni 15 minuti).
* Le variabili d'ambiente necessarie sono: `MAPBOX_KEY` (chiave pubblica di accesso a mapbox), `MAPBOX_SECRET` (chiave segreta di accesso a mapbox) e `PASSWORD` per avviare l'import.
# Informazioni utili
* Oltre a mostrare i monumenti, l'applicazione genera anche delle statistiche interessanti su /about riguardanti i monumenti con o senza foto.

* Serve da API per l'app [del concorso italiano](https://github.com/ferdi2005/monumenti).
* È possibile generare dei CSV coi monumenti di una città, esempio: `CITY=Bari rails db:generate_csv`. I file risultanti si trovano nella cartella CSV
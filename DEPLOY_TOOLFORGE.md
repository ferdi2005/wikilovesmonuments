# Guida al deploy su Wikimedia Toolforge

Questa guida documenta la procedura di distribuzione dell'applicazione `wikilovesmonuments` su Wikimedia Toolforge tramite Buildpack (Cloud Native Buildpacks), MariaDB ToolsDB e Redis condiviso.

---

## 1. Prerequisiti e convenzioni

- Un account con accesso a Toolforge e iscritto al progetto Wikimedia Cloud Services.
- Toolforge CLI (`toolforge`) disponibile all'interno dei server bastion (`login.toolforge.org`).
- Repository Git accessibile (es. `https://github.com/ferdi2005/wikilovesmonuments`).
- Nei comandi che seguono, sostituisci `<nome_tool>` con il nome effettivo del tool account (ad esempio `cerca-wlm` o `wikilovesmonuments`).

---

## 2. Accesso e assunzione dell'identità del tool

Accedi via SSH al bastion di Toolforge e passa all'utente del tool:

```bash
ssh login.toolforge.org
become <nome_tool>
```

---

## 3. Configurazione del database MariaDB (ToolsDB)

Su Toolforge ogni tool dispone di accesso a un'istanza MariaDB gestita (ToolsDB).

1. **Recupera le credenziali:**
   Le credenziali per l'accesso a ToolsDB sono memorizzate in `~/replica.my.cnf`. Visualizzale con:
   ```bash
   cat ~/replica.my.cnf
   ```
   Prendi nota dei campi `user` (solitamente `s<id_tool>`) e `password`.

2. **Crea il database:**
   Connettiti al client MySQL locale di Toolforge:
   ```bash
   sql local
   ```
   Nel prompt MariaDB, crea il database (il nome deve iniziare con il prefisso dell'utente, es. `s54321__monuments`):
   ```sql
   CREATE DATABASE s<tool>__monuments CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

3. **Verifica il supporto ai fusi orari:**
   Verifica se il database ha le tabelle dei fusi orari popolate:
   ```sql
   SELECT CONVERT_TZ(NOW(), '+00:00', 'Europe/Rome');
   ```
   - Se restituisce `NULL`: le tabelle dei fusi orari non sono caricate nel database di sistema mysql di ToolsDB e gli utenti non dispongono dei privilegi di root per caricarle. L'applicazione gestisce automaticamente questa condizione: quando `TOOLFORGE=true`, la patch in `config/initializers/groupdate.rb` converte la timezone nel rispettivo offset numerico (es. `+02:00` o `+01:00`), calcolato direttamente da MariaDB senza dipendenze esterne.

   Esci dal client:
   ```sql
   EXIT;
   ```

---

## 4. Configurazione di Redis

### Opzione predefinita: istanza Redis condivisa con namespacing
Toolforge fornisce un'istanza Redis gestita su `redis.svc.tools.eqiad1.wikimedia.cloud:6379`.
L'applicazione, tramite la gemma `redis-namespace`, isola le chiavi di Sidekiq e della cache di Geocoder anteponendo il prefisso `s<tool>_sidekiq:*` e `s<tool>_geocoder:*`.

Con `TOOLFORGE=true`, l'applicazione si connette automaticamente a tale istanza senza richiedere configurazioni manuali.

### Opzione alternativa: container Redis dedicato
Se preferisci eseguire un'istanza Redis isolata nel namespace del tool:
```bash
# 1. Genera una password
toolforge envvars create REDIS_PASSWORD $(openssl rand -hex 16)

# 2. Avvia il container continuo
toolforge jobs run \
  --image tool-containers/redis:latest \
  --command server \
  --continuous \
  --emails none \
  --port 6379 \
  redis
```

---

## 5. Configurazione delle variabili d'ambiente (envvars)

Configura le variabili tramite il comando `toolforge envvars`:

```bash
# Abilita la modalita Toolforge
toolforge envvars create TOOLFORGE true

# Chiave di cifratura delle sessioni Rails
toolforge envvars create SECRET_KEY_BASE $(openssl rand -hex 64)

# Password di ToolsDB recuperata da ~/replica.my.cnf
toolforge envvars create TOOL_TOOLSDB_PASSWORD "LA_PASSWORD_DA_REPLICA_MY_CNF"

# Password amministrativa per l'importazione
toolforge envvars create PASSWORD "LA_TUA_PASSWORD_IMPORT"

# Chiavi Mapbox per mappe e geocoding
toolforge envvars create MAPBOX_KEY "LA_TUA_MAPBOX_KEY"
toolforge envvars create MAPBOX_SECRET "IL_TUO_MAPBOX_SECRET"

# Credenziali OAuth MediaWiki e Wikidata
toolforge envvars create CONSUMER_KEY "IL_TUO_CONSUMER_KEY"
toolforge envvars create CONSUMER_SECRET "IL_TUO_CONSUMER_SECRET"

# Opzionale: concorrenza chiamate Commons in LookupJob (predefinito: 10)
toolforge envvars create WIKIMEDIA_CONCURRENCY 10

# Opzionale: monitoraggio errori Sentry
# toolforge envvars create DSN "https://..."
```

Verifica le variabili impostate:
```bash
toolforge envvars list
```

---

## 6. Compilazione dell'applicazione (Build Service)

Avvia la compilazione dell'immagine dal repository Git:

```bash
toolforge build start https://github.com/ferdi2005/wikilovesmonuments
```

Segui l'avanzamento della compilazione:
```bash
toolforge build show
toolforge build logs
```

Attendi che lo stato risulti `SUCCEEDED`.

---

## 7. Esecuzione delle migrazioni database

Esegui il job di migrazione:

```bash
toolforge jobs run migrate-job \
  --image tool-<nome_tool>/tool-<nome_tool>:latest \
  --command "migrate" \
  --mount all \
  --wait
```

Visualizza l'esito della migrazione ed elimina il job completato:
```bash
toolforge jobs logs migrate-job
toolforge jobs delete migrate-job
```

---

## 8. Avvio del webservice (Puma)

Avvia il servizio web specificando `--mount all` per rendere disponibile lo storage NFS:

```bash
toolforge webservice buildservice start --mount all --cpu 2 --mem 2Gi
```

Controlla lo stato del webservice:
```bash
toolforge webservice status
```

L'applicazione sara raggiungibile all'URL:
`https://<nome_tool>.toolforge.org/`

---

## 9. Avvio del worker Sidekiq in background

Avvia il worker per l'esecuzione dei job pianificati in `config/schedule.yml` (`ImportJob`, `LookupJob`, `CheckDuplicatesJob`, `ImportTownsJob`):

```bash
toolforge jobs run worker-job \
  --image tool-<nome_tool>/tool-<nome_tool>:latest \
  --command "worker" \
  --continuous \
  --cpu 1 \
  --mem 1Gi \
  --emails none \
  --mount all
```

Verifica lo stato del worker:
```bash
toolforge jobs list
toolforge jobs logs -f worker-job
```

---

## 10. Migrazione dei dati storici dalla vecchia istanza

Poiché la vecchia installazione su `c.ferdi.cc` utilizza PostgreSQL e Toolforge impiega MariaDB, il trasferimento avviene tramite dump agnostico in JSON compresso con Gzip (`.json.gz`).

Questo passaggio trasferisce le tabelle `towns`, `nophotos` (serie storiche non rigenerabili) e `monuments` (dataset precalcolato).

### Procedura automatizzata:
Dal computer locale, esegui lo script:
```bash
./bin/transfer_to_toolforge.sh <nome_tool>
```
Lo script:
1. Si collega via SSH a `deploy@c.ferdi.cc` ed esegue `rake db:export_data`.
2. Scarica il dump compresso in locale.
3. Lo carica sul bastion di Toolforge nel percorso `/data/project/<nome_tool>/`.

### Esecuzione dell'importazione su Toolforge:
Dal bastion (`become <nome_tool>`):
```bash
# Esegui il job di importazione
toolforge jobs run import-data-job \
  --image tool-<nome_tool>/tool-<nome_tool>:latest \
  --command "bundle exec rake 'db:import_data[/data/project/<nome_tool>/wlm_data_NOMEFILE.json.gz]'" \
  --mount all \
  --wait

# Controlla i log dell'importazione
toolforge jobs logs import-data-job

# Al termine, elimina il job e il dump per liberare spazio
toolforge jobs delete import-data-job
rm -f /data/project/<nome_tool>/wlm_data_*.json.gz
```

---

## 11. Manutenzione ordinaria e aggiornamenti

- **Log del webservice:**
  ```bash
  toolforge webservice logs -f
  ```

- **Log del worker:**
  ```bash
  toolforge jobs logs -f worker-job
  ```

- **Riavvio del webservice:**
  ```bash
  toolforge webservice restart
  ```

- **Riavvio del worker:**
  ```bash
  toolforge jobs restart worker-job
  ```

- **Accesso alla console Rails:**
  ```bash
  toolforge webservice buildservice shell
  # Una volta all'interno del container:
  launcher console
  # Digita exit per uscire dalla console e nuovamente exit per chiudere la sessione
  ```

- **Deploy di una nuova versione (dopo push su Git):**
  ```bash
  # 1. Ricompila l'immagine
  toolforge build start https://github.com/ferdi2005/wikilovesmonuments

  # 2. Esegui eventuali migrazioni
  toolforge jobs run migrate-job --image tool-<nome_tool>/tool-<nome_tool>:latest --command "migrate" --wait
  toolforge jobs delete migrate-job

  # 3. Riavvia webservice e worker
  toolforge webservice restart
  toolforge jobs restart worker-job
  ```

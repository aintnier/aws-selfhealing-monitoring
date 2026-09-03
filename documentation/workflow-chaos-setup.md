# AWS Self-Healing Monitoring - Workflow & Chaos Setup

Questo documento riepiloga le operazioni di orchestrazione dei workflow n8n, la configurazione finale della UI di Grafana e l'implementazione del framework per il Chaos Testing, completando la pipeline di Self-Healing end-to-end.

## 1. Topologia e Recovery dell'Infrastruttura (AWS EC2)

A seguito di un aggiornamento del blocco `user_data` in Terraform, l'infrastruttura è stata completamente rigenerata. I parametri attuali sono:
- **Control Node**:
  - **EIP:** `16.22.20.11`
  - **Servizi:** n8n (Porta `5678`), Grafana (Porta `3000`) tramite Docker Compose.
- **Worker Node (Patient Node)**:
  - **Private IP:** `172.31.30.184`
  - **Servizi:** Nginx, Redis, CloudWatch Agent, Script di Chaos Testing.

Tutte le interazioni API e i Webhook sono stati mappati sui nuovi indirizzi IP per garantire continuità.

## 2. Orchestrazione n8n (Logica Multi-Workflow)

Per garantire scalabilità, la logica di self-healing è stata suddivisa in **5 workflow modulari** (1 Router + 4 Remediation Worker).

- **Gestione Credenziali:**
  - `Worker Node SSH`: La chiave privata `.ssh/selfhealing-key` è stata iniettata in n8n per abilitare l'esecuzione di comandi SSH direttamente sul Worker Node, saltando i bastion host. Le credenziali sono state assegnate singolarmente a tutti i nodi `execute command`.
  - `Grafana Header Auth`: Token di tipo Bearer per autenticare n8n presso le API di Grafana per il post delle Annotations.
- **Aggiornamento di Compatibilità n8n:**
  Per allineare i vecchi workflow JSON ai vincoli di validazione delle nuove versioni di n8n, è stato iniettato manualmente un campo formale fittizio (`payload: String`) all'interno di tutti i nodi `Execute Workflow Trigger`. Questa mitigazione permette ai sotto-workflow di essere Pubblicati correttamente aggirando l'errore "At least 1 field is required".
- **Dynamic Routing:**
  Il `Self-Healing Router` espone l'endpoint Webhook che sottoscrive le notifiche SNS. Parsando il parametro `AlarmName`, il Router intercetta in modo dinamico se il problema riguarda CPU, Memoria o Disco, innescando (via Sub-Workflow) la corretta procedura di ripristino senza duplicazione di codice.

## 3. Telemetria e Dashboard Grafana

- **CloudWatch Agent:** Il demone installato via `user_data` sul Worker Node inietta all'interno di CloudWatch metriche di sistema profonde (utilizzo reale RAM e filesystem root), sopperendo alle limitazioni delle metriche standard EC2.
- **Datasource Binding:** A causa della rigenerazione EC2, il plugin CloudWatch è stato riautenticato tramite `AWS SDK Default`. Il matching tra il nuovo UID interno del Datasource e il JSON della Dashboard originale è stato sanato modificando la query della variabile `$InstanceId` e i rispettivi filtri di ogni Panel.

## 4. Framework di Chaos Testing (Simulazione Guasti)

Al fine di validare l'intero stack, sono stati scritti e posizionati 4 script Bash (`/opt/chaos/`) sul Worker Node. Essi generano degradi artificiali controllati:

1. **Crash Container Nginx (`chaos-container-crash.sh`):** Ferma il webserver per innescare fallimenti di Status Check.
2. **CPU Overload (`chaos-cpu.sh`):** Genera fork intensivi tramite `stress-ng`.
3. **Memory Leak (`chaos-memory.sh`):** Alloca aggressivamente RAM senza rilasciarla (`stress-ng --vm`).
4. **Disk Full (`chaos-disk.sh`):** Genera blocchi `dd` nulli fino a riempire il 90% dello storage disponibile.

---

**Next Steps**: Procedere all'esecuzione sequenziale degli script di Chaos per validare che l'intercettazione CloudWatch-SNS, il routing di n8n e le annotazioni Grafana chiudano correttamente il ciclo di remediation automatica.

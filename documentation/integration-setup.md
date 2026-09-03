# Integrazione e Ottimizzazione - Self-Healing Monitoring

Questo documento traccia l'evoluzione architetturale e il setup dell'integrazione tra i servizi (n8n, Grafana, CloudWatch, SNS), successivi al provisioning base dell'infrastruttura.

## 1. Rifattorizzazione Architetturale (Cost Optimization)

Per garantire la sostenibilità economica del progetto (zero costi fissi nei periodi di inattività), l'architettura iniziale è stata snellita:
- **Rimozione Database RDS**: L'istanza MySQL managed, inizialmente pensata per lo storico eventi, è stata eliminata tramite Terraform (`terraform destroy` mirato).
- **Nuovo paradigma di logging**: Lo storico degli eventi di self-healing è stato migrato dalle tabelle relazionali alle **Annotations di Grafana**. Questo centralizza l'osservabilità e riduce la superficie di attacco e i costi.

## 2. Configurazione Permessi IAM

Per permettere a Grafana di interrogare nativamente CloudWatch senza l'uso di chiavi statiche (Access/Secret Key), è stata aggiornata la configurazione Terraform (`iam.tf`).
Al Ruolo IAM assegnato all'istanza EC2 (`selfhealing-monitoring-ec2-role`) è stata aggiunta la policy gestita:
- `CloudWatchReadOnlyAccess`: Permette al plugin CloudWatch di Grafana di eseguire chiamate come `cloudwatch:ListMetrics` e `cloudwatch:GetMetricData`.

## 3. Setup Grafana (CloudWatch & Annotations)

La configurazione del Control Node è stata automatizzata via API (script `setup_grafana.sh`):
1. **Provisioning Datasource**: È stato aggiunto CloudWatch come Data Source predefinito, impostando `authType: default` per sfruttare automaticamente il ruolo IAM della EC2.
2. **Service Account per n8n**: È stato creato un Service Account interno a Grafana (`n8n-integrator` con ruolo Editor) ed è stato generato un Token API. Questo token è necessario per permettere all'orchestratore di scrivere sui grafici.

## 4. Integrazione n8n e AWS SNS

L'orchestrazione degli eventi (Trigger AWS -> Azione di Self-Healing -> Notifica Grafana) è gestita tramite n8n.
- **Workflow As Code**: È stato sviluppato e versionato il file `workflows/self-healing-demo.json`.
- **Autoconferma SNS**: Il workflow n8n include una logica condizionale (nodo `IF`) che intercetta i messaggi con header `x-amz-sns-message-type: SubscriptionConfirmation`. n8n estrae l'URL fornito da AWS ed esegue una chiamata GET per confermare automaticamente la propria iscrizione (Webhook) al Topic SNS.
- **Aggancio AWS**: L'integrazione è stata finalizzata registrando l'endpoint di produzione di n8n (`/webhook/cloudwatch-alerts`) come subscriber del Topic SNS (`selfhealing-monitoring-alerts`) tramite AWS CLI. L'aggancio è andato a buon fine, abilitando il trigger degli allarmi CloudWatch direttamente nei workflow n8n.

---
**Stato Attuale**: L'infrastruttura è completamente integrata. Eventuali allarmi CloudWatch vengono propagati tramite SNS, elaborati da n8n e infine visualizzati come marker temporali direttamente sulle dashboard di Grafana.

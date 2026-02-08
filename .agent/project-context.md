# Progetto Self-Healing Monitoring - ITS Cloud Administrator

## Overview

Piattaforma di **monitoring e self-healing per infrastruttura cloud AWS**, progetto d'esame ITS Cloud Administrator.

**Competenze dimostrate**: AWS, Infrastructure as Code (Terraform), automazione (n8n), monitoring (CloudWatch + Grafana), pratiche SRE/DevOps.

---

## Architettura

### Stack Tecnologico

| Componente | Tecnologia | Descrizione |
|------------|------------|-------------|
| IaC | Terraform | Provisioning infrastruttura AWS |
| Compute | EC2 t3.micro | Amazon Linux 2023, eu-south-1 |
| Container | Docker + Compose | Runtime servizi applicativi |
| Automazione | n8n | Workflow self-healing |
| Monitoring | CloudWatch + Grafana | Metriche, allarmi, dashboard |
| State | S3 | Backend remoto Terraform |

### Servizi sull'EC2 (Docker Compose)

| Servizio | Porta | Funzione |
|----------|-------|----------|
| nginx | 80 | App demo (target test) |
| Grafana OSS | 3000 | Dashboard osservabilità |
| n8n | 5678 | Orchestratore workflow self-healing |

### Security Group

- **Ingress**: 22 (SSH), 80 (HTTP), 3000 (Grafana), 5678 (n8n)
- **Egress**: tutto consentito

---

## Flusso Self-Healing

```
CloudWatch Metrics → CloudWatch Alarm → SNS Topic → Webhook n8n → Remediation → Notifica
```

1. **Monitoring**: CloudWatch raccoglie metriche EC2 (CPU, disk, status check)
2. **Alerting**: Alarm supera soglia → notifica a SNS
3. **Automazione**: SNS chiama webhook n8n
4. **Remediation**: n8n esegue azioni correttive
5. **Notifica**: Report all'operatore

---

## Workflow n8n Previsti

| Workflow | Trigger | Azioni |
|----------|---------|--------|
| Alert Router | Webhook SNS | Parsing allarme, routing a workflow specifico |
| EC2 Health & Restart | Status check failed | Verifica stato, restart servizi/reboot EC2 |
| Container Recovery | App down/HTTP 5xx | Health check, restart container, verifica |
| Disk Cleanup | Disk usage alto | Prune Docker, cleanup log, upload S3 |
| Cost Alert (opz.) | Budget superato | Report costi, notifica |

---

## Chaos Testing

Script per simulare failure e testare self-healing:
- `docker kill app` → crash applicativo
- `stress` → overload CPU
- File temporanei → riempimento disco
- Stop Docker → problemi servizi

---

## Struttura Repository

```
project/
├── terraform/
│   └── environments/
│       └── dev/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── backend.tf
├── n8n/
│   └── workflows/          # Export JSON workflow
├── grafana/
│   └── dashboards/         # Dashboard JSON
├── scripts/
│   └── chaos/              # Script di test
└── documentation/
    ├── terraform-setup.md
    ├── architecture.md
    └── runbook.md
```

---

## Risorse AWS Create

| Risorsa | Nome/ID | Note |
|---------|---------|------|
| S3 Bucket | terraform-state-selfhealing-1770562384 | State Terraform |
| Security Group | selfhealing-monitoring-sg | Regole firewall |
| EC2 Instance | selfhealing-monitoring-ec2 | Host principale |
| SNS Topic | (da creare) | Target allarmi |
| CloudWatch Alarms | (da creare) | Soglie metriche |

---

## Deliverable Esame

1. **Repository Git**: Terraform, workflow n8n, dashboard Grafana, script chaos, docs
2. **Live Demo AWS**: Dimostrazione self-healing in azione
3. **Documento Progetto**: Architettura, scelte tecniche, mappatura competenze ITS, scenari incidente

---

## Endpoint Attuali

| Servizio | URL |
|----------|-----|
| App (nginx) | http://15.161.49.65:80 |
| Grafana | http://15.161.49.65:3000 |
| n8n | http://15.161.49.65:5678 |

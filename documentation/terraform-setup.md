# Setup Terraform - Infrastruttura Self-Healing Monitoring

## Contesto Progetto

Questo documento descrive il setup dell'infrastruttura AWS per la **piattaforma di monitoring e self-healing**, progetto d'esame ITS Cloud Administrator.

### Obiettivo

Provisioning automatizzato tramite Terraform di un'istanza EC2 nella regione `eu-south-1` (Milano) con Elastic IP statico, che ospita lo stack applicativo via Docker:

| Servizio | Porta | Funzione |
|----------|-------|----------|
| **n8n** | 5678 | Orchestratore workflow self-healing |
| **Grafana** | 3000 | Dashboard di osservabilità |
| **nginx** | 80 | App demo (target per test failure) |

### Architettura

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS eu-south-1                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                       VPC Default                         │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │           EC2 t3.micro (Amazon Linux 2023)          │  │  │
│  │  │               Elastic IP: 51.118.61.93              │  │  │
│  │  │         ┌─────────┐  ┌─────────┐  ┌─────────┐       │  │  │
│  │  │         │  nginx  │  │ Grafana │  │   n8n   │       │  │  │
│  │  │         │  :80    │  │  :3000  │  │  :5678  │       │  │  │
│  │  │         └─────────┘  └─────────┘  └─────────┘       │  │  │
│  │  │                   Docker Compose                    │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────┐                                           │
│  │   S3 Bucket      │  ← Terraform State                        │
│  └──────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

Lo state di Terraform viene salvato remotamente su S3 per persistenza e collaborazione.

---

## Prerequisiti

### Installazione AWS CLI

Installata AWS CLI versione **2.33.17** per l'interazione con i servizi AWS da terminale.

---

## Configurazione

### 1. Creazione utenza IAM per Terraform

Creata utenza `terraform-selfhealing` dal portale AWS con:
- **Tipo di accesso**: CLI (Access Key + Secret Key)
- **Policy**: `AdministratorAccess`

Configurazione locale:

```bash
aws configure
```

| Parametro | Valore |
|-----------|--------|
| AWS Access Key ID | `<access_key>` |
| AWS Secret Access Key | `<secret_key>` |
| Default region | `eu-south-1` |
| Default output format | `json` |

---

### 2. Creazione bucket S3 per lo state remoto

Il bucket S3 salva il file `terraform.tfstate` in modo centralizzato, evitando conflitti e garantendo persistenza.

```bash
aws s3api create-bucket \
  --bucket terraform-state-selfhealing-$(date +%s) \
  --region eu-south-1 \
  --create-bucket-configuration LocationConstraint=eu-south-1
```

**Output:**
```json
{
    "Location": "http://terraform-state-selfhealing-1770562384.s3.amazonaws.com/"
}
```

**Bucket creato**: `terraform-state-selfhealing-1770562384`

---

### 3. Inizializzazione repository Git

```bash
git init
```

---

### 4. Creazione struttura Terraform

```bash
mkdir -p terraform/environments/dev
cd terraform/environments/dev
```

I file Terraform sono organizzati **per servizio AWS**: ogni risorsa è isolata in un file dedicato, semplificando la manutenzione. Terraform carica automaticamente tutti i file `.tf` presenti nella stessa directory.

Struttura risultante:
```
terraform/
└── environments/
    └── dev/
        ├── backend.tf       # Backend S3 per state
        ├── main.tf          # Provider AWS + data sources (AMI, VPC)
        ├── ec2.tf           # Security Group, Key Pair, EC2, Elastic IP
        ├── cloudwatch.tf    # CloudWatch Alarms (CPU, StatusCheck)
        ├── variables.tf     # Variabili configurabili
        └── outputs.tf       # Output post-deploy
```

---

## File Terraform

### `backend.tf` - Backend remoto S3

Configura dove Terraform salva lo state, abilitando collaborazione e persistenza.

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-selfhealing-1770562384"
    key    = "env/dev/terraform.tfstate"
    region = "eu-south-1"
  }
}
```

---

### `variables.tf` - Variabili di configurazione

Centralizza i parametri, rendendo il codice modulare e riutilizzabile per altri ambienti.

```hcl
variable "aws_region" {
  type    = string
  default = "eu-south-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "project_name" {
  type    = string
  default = "selfhealing-monitoring"
}
```

---

### `outputs.tf` - Output dell'infrastruttura

Espone valori utili post-deploy, consultabili con `terraform output`.

```hcl
output "elastic_ip" {
  description = "Elastic IP associato all'istanza EC2"
  value       = aws_eip.monitoring_eip.public_ip
}

output "ec2_public_dns" {
  description = "DNS pubblico dell'istanza EC2"
  value       = aws_instance.monitoring_ec2.public_dns
}
```

---

### `main.tf` - Provider e Data Sources

Contiene il provider AWS e i data source condivisi da tutte le risorse.

#### Provider AWS
```hcl
provider "aws" {
  region = var.aws_region
}
```

#### Data Source - AMI Amazon Linux 2023
Recupera dinamicamente l'AMI più recente:
```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["amazon"]
}
```

---

### `ec2.tf` - Istanza EC2, Security Group, Key Pair, Elastic IP

Contiene tutte le risorse legate all'istanza EC2.

#### Security Group
Regole firewall per i servizi esposti:

| Porta | Protocollo | Descrizione |
|-------|------------|-------------|
| 22 | TCP | SSH |
| 80 | TCP | nginx (app demo) |
| 3000 | TCP | Grafana |
| 5678 | TCP | n8n |
| * | * | Egress illimitato |

#### Key Pair SSH
Per l'accesso SSH all'istanza viene creato un key pair gestito da Terraform:

```hcl
resource "aws_key_pair" "selfhealing_key" {
  key_name   = "selfhealing-key"
  public_key = file("${path.module}/../../../.ssh/selfhealing-key.pub")
}
```

La chiave pubblica viene letta dal file `.ssh/selfhealing-key.pub` nella root del progetto.

#### Istanza EC2 con User Data
L'istanza viene configurata automaticamente al boot tramite `user_data`:
1. Aggiorna il sistema operativo
2. Installa Docker e Docker Compose (ultima versione stabile)
3. Crea `/opt/stack/docker-compose.yml` con lo stack applicativo
4. Avvia i container (n8n, Grafana, nginx)

**Configurazione n8n:**
- `N8N_SECURE_COOKIE=false` - Necessario per funzionamento su HTTP senza HTTPS

#### Elastic IP
Assegnato un Elastic IP all'istanza EC2 per garantire un indirizzo IP pubblico **statico e persistente**, che non cambia in caso di stop/start dell'istanza.

```hcl
resource "aws_eip" "monitoring_eip" {
  instance = aws_instance.monitoring_ec2.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}
```

**Elastic IP assegnato**: `51.118.61.93`

---

### `cloudwatch.tf` - CloudWatch Alarms

Contiene gli allarmi CloudWatch per il monitoring dell'istanza EC2.

#### Alarm CPU High
Scatta quando la CPU supera l'80% per **2 periodi consecutivi** da 5 minuti.

```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.monitoring_ec2.id
  }
}
```

#### Alarm Status Check Failed
Scatta immediatamente quando un health check EC2 fallisce (periodo 60s, 1 evaluation).

```hcl
resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = "${var.project_name}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.monitoring_ec2.id
  }
}
```

| Alarm | Metrica | Soglia | Periodi | Intervallo |
|-------|---------|--------|---------|------------|
| `cpu-high` | CPUUtilization | > 80% | 2 | 300s (5 min) |
| `status-check-failed` | StatusCheckFailed | > 0 | 1 | 60s |

---

## Esecuzione Terraform

### 5. Inizializzazione

```bash
terraform init -reconfigure
```

**Output:**
```
Initializing the backend...
Successfully configured the backend "s3"!

Initializing provider plugins...
- Installing hashicorp/aws v6.31.0...
- Installed hashicorp/aws v6.31.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

---

### 6. Pianificazione e Applicazione

```bash
terraform plan
terraform apply
```

**Output (sintesi):**
```
data.aws_vpc.default: Read complete [id=vpc-0f24f6e364cf25566]
data.aws_ami.amazon_linux_2023: Read complete [id=ami-0a157b987d7c5cb3e]

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ec2_public_dns = (known after apply)
  + ec2_public_ip  = (known after apply)
```

Risorse pianificate:
- `aws_security_group.ec2_sg`
- `aws_instance.monitoring_ec2`

Deploy completato con successo. Tutte le risorse create e operazionali.

---

## Risorse Create

| Risorsa | Nome/ID | Dettagli |
|---------|---------|----------|
| S3 Bucket | `terraform-state-selfhealing-1770562384` | State Terraform |
| Key Pair | `selfhealing-key` | Chiave SSH per accesso EC2 |
| Security Group | `selfhealing-monitoring-sg` | Porte: 22, 80, 3000, 5678 |
| EC2 Instance | `selfhealing-monitoring-ec2` | t3.micro, Amazon Linux 2023 |
| Elastic IP | `selfhealing-monitoring-eip` | `51.118.61.93` |
| CW Alarm | `selfhealing-monitoring-cpu-high` | CPU > 80% (2×5min) |
| CW Alarm | `selfhealing-monitoring-status-check-failed` | StatusCheckFailed |

---

## Endpoint Applicativi

| Servizio | URL | Stato |
|----------|-----|-------|
| nginx (App demo) | http://51.118.61.93 | ✅ Attivo |
| Grafana | http://51.118.61.93:3000 | ✅ Attivo |
| n8n | http://51.118.61.93:5678 | ✅ Attivo |

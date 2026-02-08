# Setup Terraform - Infrastruttura Self-Healing Monitoring

## Contesto Progetto

Questo documento descrive il setup dell'infrastruttura AWS per la **piattaforma di monitoring e self-healing**, progetto d'esame ITS Cloud Administrator.

### Obiettivo

Provisioning automatizzato tramite Terraform di un'istanza EC2 nella regione `eu-south-1` (Milano) che ospita lo stack applicativo via Docker:

| Servizio | Porta | Funzione |
|----------|-------|----------|
| **n8n** | 5678 | Orchestratore workflow self-healing |
| **Grafana** | 3000 | Dashboard di osservabilità |
| **nginx** | 80 | App demo (target per test failure) |

### Architettura Target

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS eu-south-1                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    VPC Default                            │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │              EC2 t3.micro (Amazon Linux 2023)       │  │  │
│  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐              │  │  │
│  │  │  │  nginx  │  │ Grafana │  │   n8n   │              │  │  │
│  │  │  │  :80    │  │  :3000  │  │  :5678  │              │  │  │
│  │  │  └─────────┘  └─────────┘  └─────────┘              │  │  │
│  │  │              Docker Compose                         │  │  │
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

### 0. Installazione AWS CLI

Installata AWS CLI versione **2.33.17** per l'interazione con i servizi AWS da terminale.

---

## Step di Configurazione

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
touch main.tf variables.tf outputs.tf backend.tf
```

Struttura risultante:
```
terraform/
└── environments/
    └── dev/
        ├── backend.tf    # Backend S3 per state
        ├── main.tf       # Risorse AWS
        ├── outputs.tf    # Output post-deploy
        └── variables.tf  # Variabili configurabili
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
output "ec2_public_ip" {
  value = aws_instance.monitoring_ec2.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.monitoring_ec2.public_dns
}
```

---

### `main.tf` - Risorse AWS

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

#### Security Group
Regole firewall per i servizi esposti:

| Porta | Protocollo | Descrizione |
|-------|------------|-------------|
| 22 | TCP | SSH |
| 80 | TCP | nginx (app demo) |
| 3000 | TCP | Grafana |
| 5678 | TCP | n8n |
| * | * | Egress illimitato |

#### Istanza EC2 con User Data
L'istanza viene configurata automaticamente al boot tramite `user_data`:
1. Aggiorna il sistema operativo
2. Installa Docker e Docker Compose
3. Crea `/opt/stack/docker-compose.yml` con lo stack applicativo
4. Avvia i container (n8n, Grafana, nginx)

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

### 6. Pianificazione (dry-run)

```bash
terraform plan
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

---

### 7. Applicazione

```bash
terraform apply
```

Dopo conferma con `yes`:

**Output:**
```
aws_security_group.ec2_sg: Creating...
aws_security_group.ec2_sg: Creation complete after 3s [id=sg-08dec74fce841757f]
aws_instance.monitoring_ec2: Creating...
aws_instance.monitoring_ec2: Creation complete after 33s [id=i-0c80ef1da5ac8a3f4]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

ec2_public_dns = "ec2-15-161-49-65.eu-south-1.compute.amazonaws.com"
ec2_public_ip = "15.161.49.65"
```

---

### 8. Verifica output

```bash
terraform output
```

```
ec2_public_dns = "ec2-15-161-49-65.eu-south-1.compute.amazonaws.com"
ec2_public_ip = "15.161.49.65"
```

---

## Risorse Create

| Risorsa | ID | Dettagli |
|---------|-----|----------|
| Security Group | `sg-08dec74fce841757f` | `selfhealing-monitoring-sg` |
| EC2 Instance | `i-0c80ef1da5ac8a3f4` | `t3.micro`, Amazon Linux 2023 |

---

## Endpoint Applicativi

| Servizio | URL | Stato |
|----------|-----|-------|
| nginx (App demo) | http://15.161.49.65 | ✅ Attivo |
| Grafana | http://15.161.49.65:3000 | ✅ Attivo |
| n8n | http://15.161.49.65:5678 | ✅ Attivo |

---

## Prossimi Step

Con l'infrastruttura base pronta, i prossimi step del progetto prevedono:

1. **CloudWatch Alarms** - Definizione allarmi su CPU, disk, status check
2. **SNS Topic** - Target per gli allarmi, subscriber webhook n8n
3. **IAM Role per EC2** - Permessi per SSM Run Command e CloudWatch
4. **Workflow n8n** - Implementazione logica self-healing
5. **Dashboard Grafana** - Configurazione datasource CloudWatch

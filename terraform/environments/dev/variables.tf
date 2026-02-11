variable "aws_region" {
  type    = string
  default = "eu-south-1"
}

variable "control_node_instance_type" {
  description = "Instance type for the Control Node (Doctor)"
  default     = "t3.small"
}

variable "worker_node_instance_type" {
  description = "Instance type for the Worker Node (Patient)"
  default     = "t3.small"
}

variable "project_name" {
  type    = string
  default = "selfhealing-monitoring"
}

# ── RDS ──
variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.small"
}

variable "db_name" {
  description = "Application database name"
  default     = "app_db"
}

variable "db_username" {
  description = "Database admin username"
  default     = "admin"
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  default     = "SelfHealing2024!"
  sensitive   = true
}

# ── SNS ──
variable "alert_email" {
  description = "Email for SNS alert notifications"
  default     = "ernesto.cervadoro@gmail.com"
}

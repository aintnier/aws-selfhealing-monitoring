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


# ── SNS ──
variable "alert_email" {
  description = "Email for SNS alert notifications"
  default     = "ernesto.cervadoro@gmail.com"
}

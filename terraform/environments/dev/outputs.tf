# ─────────────
# Outputs
# ─────────────

output "control_node_elastic_ip" {
  description = "Elastic IP del Control Node (Dottore)"
  value       = aws_eip.monitoring_eip.public_ip
}

output "control_node_dns" {
  description = "DNS pubblico del Control Node"
  value       = aws_instance.monitoring_ec2.public_dns
}

output "worker_node_public_ip" {
  description = "IP Pubblico del Worker Node (Paziente)"
  value       = aws_instance.worker_node.public_ip
}

output "worker_node_private_ip" {
  description = "IP Privato del Worker Node"
  value       = aws_instance.worker_node.private_ip
}

output "rds_endpoint" {
  description = "Endpoint RDS MySQL"
  value       = aws_db_instance.app_db.endpoint
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic per gli allarmi"
  value       = aws_sns_topic.n8n_alerts.arn
}

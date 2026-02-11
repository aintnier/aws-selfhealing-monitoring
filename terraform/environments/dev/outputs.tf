output "elastic_ip" {
  description = "Elastic IP associato all'istanza EC2"
  value       = aws_eip.monitoring_eip.public_ip
}

output "ec2_public_dns" {
  description = "DNS pubblico dell'istanza EC2"
  value       = aws_instance.monitoring_ec2.public_dns
}

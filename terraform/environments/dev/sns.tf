# ─────────────────────────────
# SNS Topic (Alert Routing)
# ─────────────────────────────

resource "aws_sns_topic" "n8n_alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

# Email subscription for testing/backup notifications
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.n8n_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# NOTE: n8n HTTPS webhook subscription will be added
# after n8n is deployed and the webhook URL is known.
# Example:
# resource "aws_sns_topic_subscription" "n8n_webhook" {
#   topic_arn            = aws_sns_topic.n8n_alerts.arn
#   protocol             = "https"
#   endpoint             = "http://<CONTROL_NODE_EIP>:5678/webhook/sns-alert"
#   endpoint_auto_confirms = true
# }

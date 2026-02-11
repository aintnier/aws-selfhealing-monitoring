# ─────────────────────────────────────
# CloudWatch Alarms — Worker Node
# ─────────────────────────────────────

# Scenario 2: CPU Overload
resource "aws_cloudwatch_metric_alarm" "worker_cpu_high" {
  alarm_name          = "${var.project_name}-worker-cpu-high"
  alarm_description   = "Worker Node CPU > 80% per 2 periodi"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.worker_node.id
  }

  alarm_actions = [aws_sns_topic.n8n_alerts.arn]
  ok_actions    = [aws_sns_topic.n8n_alerts.arn]

  tags = {
    Name = "${var.project_name}-worker-cpu-high"
  }
}

# Scenario 3: Memory Leak (requires CW Agent)
resource "aws_cloudwatch_metric_alarm" "worker_memory_high" {
  alarm_name          = "${var.project_name}-worker-memory-high"
  alarm_description   = "Worker Node Memory > 85% per 3 periodi"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.worker_node.id
  }

  alarm_actions = [aws_sns_topic.n8n_alerts.arn]
  ok_actions    = [aws_sns_topic.n8n_alerts.arn]

  tags = {
    Name = "${var.project_name}-worker-memory-high"
  }
}

# Scenario 4: Disk Full (requires CW Agent)
resource "aws_cloudwatch_metric_alarm" "worker_disk_high" {
  alarm_name          = "${var.project_name}-worker-disk-high"
  alarm_description   = "Worker Node Disk > 85% per 2 periodi"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.worker_node.id
    path       = "/"
    device     = "xvda1"
    fstype     = "xfs"
  }

  alarm_actions = [aws_sns_topic.n8n_alerts.arn]
  ok_actions    = [aws_sns_topic.n8n_alerts.arn]

  tags = {
    Name = "${var.project_name}-worker-disk-high"
  }
}

# Baseline: Status Check Failed
resource "aws_cloudwatch_metric_alarm" "worker_status_check" {
  alarm_name          = "${var.project_name}-worker-status-check-failed"
  alarm_description   = "Worker Node status check fallito"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.worker_node.id
  }

  alarm_actions = [aws_sns_topic.n8n_alerts.arn]

  tags = {
    Name = "${var.project_name}-worker-status-check"
  }
}

# Self-healing for the single host (CloudWatch alarms are within the Free Tier's 10 alarms).
# Underlying AWS hardware fails -> recover onto healthy hardware (same instance ID, EIP, EBS).
resource "aws_cloudwatch_metric_alarm" "ec2_system_recover" {
  alarm_name          = "resume-analyzer-system-check-recover"
  alarm_description   = "Recover the instance when the AWS system status check fails"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { InstanceId = aws_instance.app_server.id }
  alarm_actions       = ["arn:aws:automate:${var.aws_region}:ec2:recover"]
}

# OS hangs (e.g. out of memory on the 1 GB t3.micro) -> reboot; Docker restarts the stack on boot.
resource "aws_cloudwatch_metric_alarm" "ec2_instance_reboot" {
  alarm_name          = "resume-analyzer-instance-check-reboot"
  alarm_description   = "Reboot the instance when the OS-level status check fails"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_Instance"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { InstanceId = aws_instance.app_server.id }
  alarm_actions       = ["arn:aws:automate:${var.aws_region}:ec2:reboot"]
}

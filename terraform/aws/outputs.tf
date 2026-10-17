output "app_url" {
  description = "Application URL (nginx on port 80)"
  value       = "http://${aws_eip.app_eip.public_ip}"
}

output "instance_id" {
  description = "Set as GitHub repo variable EC2_INSTANCE_ID"
  value       = aws_instance.app_server.id
}

output "github_ci_role_arn" {
  description = "Set as GitHub repo variable AWS_ROLE_ARN"
  value       = aws_iam_role.github_ci.arn
}

output "github_terraform_plan_role_arn" {
  description = "Set as GitHub repo variable TF_PLAN_ROLE_ARN"
  value       = aws_iam_role.github_terraform_plan.arn
}

output "github_terraform_apply_role_arn" {
  description = "Set as GitHub repo variable TF_APPLY_ROLE_ARN"
  value       = aws_iam_role.github_terraform_apply.arn
}

output "ecr_registry" {
  value = local.ecr_registry
}

output "resume_bucket" {
  value = aws_s3_bucket.resumes.bucket
}

output "shell_access" {
  description = "Shell on the server without SSH"
  value       = "aws ssm start-session --target ${aws_instance.app_server.id}"
}

output "grafana_tunnel" {
  description = "Grafana listens on localhost only; tunnel to it (enable with: docker compose --profile monitoring up -d)"
  value       = "aws ssm start-session --target ${aws_instance.app_server.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=3001,localPortNumber=3001"
}

# Free alternative to Secrets Manager. Set the real Groq key after apply:
#   aws ssm put-parameter --name /resume-analyzer/groq_api_key --type SecureString --value "gsk_..." --overwrite
resource "aws_ssm_parameter" "groq_api_key" {
  name  = "/resume-analyzer/groq_api_key"
  type  = "SecureString"
  value = "REPLACE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "random_password" "db" {
  length  = 32
  special = false # keeps the value safe inside a database URL
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/resume-analyzer/db_password"
  type  = "SecureString"
  value = random_password.db.result
}

resource "random_password" "grafana" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  name  = "/resume-analyzer/grafana_admin_password"
  type  = "SecureString"
  value = random_password.grafana.result
}

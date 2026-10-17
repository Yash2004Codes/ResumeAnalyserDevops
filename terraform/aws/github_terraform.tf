# Roles for the Terraform workflow (.github/workflows/terraform.yml), split so that
# pull requests can only read, and only the approval-gated `production` environment can apply.

locals {
  # Plain-name subject, plus the immutable (ID-based) subject newer repos send
  github_sub_prefixes = concat(
    ["repo:${var.github_repo}"],
    var.github_repo_immutable_subject == "" ? [] : [var.github_repo_immutable_subject],
  )
  tfstate_bucket = "resume-analyzer-tfstate-${data.aws_caller_identity.current.account_id}"
}

# --- plan: PRs and master, read-only ---------------------------------------

resource "aws_iam_role" "github_terraform_plan" {
  name = "resume-analyzer-github-terraform-plan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.github_oidc_arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = flatten([
            for p in local.github_sub_prefixes : ["${p}:pull_request", "${p}:ref:refs/heads/${var.repo_branch}"]
          ])
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_terraform_plan_readonly" {
  role       = aws_iam_role.github_terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_terraform_plan" {
  name = "state-lock-and-ssm-decrypt"
  role = aws_iam_role.github_terraform_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3-native lock file (use_lockfile = true)
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${local.tfstate_bucket}/aws/terraform.tfstate.tflock"
      },
      {
        # Refreshing SecureString parameters reads them decrypted
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com" }
        }
      }
    ]
  })
}

# --- apply: only the `production` environment (required reviewers) ---------

resource "aws_iam_role" "github_terraform_apply" {
  name = "resume-analyzer-github-terraform-apply"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.github_oidc_arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [for p in local.github_sub_prefixes : "${p}:environment:production"]
        }
      }
    }]
  })
}

# This stack manages IAM roles and policies, so anything able to apply it can already grant itself
# any permission; a narrower policy would not be a real boundary. The guard is the trust policy above.
resource "aws_iam_role_policy_attachment" "github_terraform_apply_admin" {
  role       = aws_iam_role.github_terraform_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

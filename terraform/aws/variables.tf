variable "aws_region" {
  description = "AWS region for provisioning resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 size. t3.micro is covered by the Free Tier (750 h/month)."
  type        = string
  default     = "t3.micro"
}

variable "repo_url" {
  description = "Git repository URL to clone on the instance (must be public)"
  type        = string
  default     = "https://github.com/Yash2004Codes/ResumeAnalyserDevops.git"
}

variable "repo_branch" {
  description = "Git branch to check out"
  type        = string
  default     = "master"
}

variable "github_repo" {
  description = "GitHub repo (owner/name) allowed to assume the CI role through OIDC"
  type        = string
  default     = "Yash2004Codes/ResumeAnalyserDevops"
}

variable "create_github_oidc_provider" {
  description = "Set false if the account already has the token.actions.githubusercontent.com OIDC provider"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email that receives AWS Budgets alerts"
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly budget; alerts fire when spend exceeds it"
  type        = string
  default     = "0.01"
}

variable "github_repo_immutable_subject" {
  description = "Optional ID-based OIDC subject prefix, e.g. repo:Owner@123/Repo@456 (GitHub repo OIDC sub-claim setting)"
  type        = string
  default     = ""
}

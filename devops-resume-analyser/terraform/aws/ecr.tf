locals {
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  ecr_repos    = toset(["resume-backend", "resume-frontend"])
}

resource "aws_ecr_repository" "app" {
  for_each             = local.ecr_repos
  name                 = each.key
  image_tag_mutability = "IMMUTABLE" # a git SHA tag always points at the same image
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# The Free Tier gives 500 MB of ECR storage, so keep only the last few images
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 3 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}

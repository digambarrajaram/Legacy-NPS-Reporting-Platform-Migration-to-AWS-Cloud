locals {
  # recommended tagging policy
  default_tags = merge({
    "Project" = "nps-reporting",
    "Environment" = terraform.workspace,
    "ManagedBy" = "terraform"
  }, var.tags)
}


# Create a KMS key if alias not provided
resource "aws_kms_key" "ecr_key" {
  count = var.kms_key_alias == "" ? 1 : 0
  description = "KMS key for ECR repository ${var.name} (created by Terraform)"
  deletion_window_in_days = 30
  enable_key_rotation = true
  tags = local.default_tags
}


resource "aws_kms_alias" "ecr_key_alias" {
  count = var.kms_key_alias == "" ? 1 : 0
  name = "alias/ecr/${var.name}"
  target_key_id = aws_kms_key.ecr_key[0].key_id
}


# Determine the key ARN to use (either provided alias or created)
data "aws_kms_key" "selected" {
  count = var.kms_key_alias != "" ? 1 : 0
  key_id = var.kms_key_alias
}


locals {
  kms_key_id = var.kms_key_alias != "" ? data.aws_kms_key.selected[0].key_id : (length(aws_kms_key.ecr_key) > 0 ? aws_kms_key.ecr_key[0].key_id : null)
}


resource "aws_ecr_repository" "this" {
  name = var.name
  image_tag_mutability = "IMMUTABLE"


  image_scanning_configuration {
    scan_on_push = true
  }


  encryption_configuration {
    encryption_type = "KMS"
    kms_key = local.kms_key_id
  }


  tags = local.default_tags
}


# lifecycle policy (retention) - uses JSON policy file in module
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = file("${path.module}/lifecycle-policy.json")
}


# repository policy - restrict to the account and optionally CI role
resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = templatefile("${path.module}/repo-policy.json", {
    account_id = data.aws_caller_identity.current.account_id,
    ci_role_arn = var.ci_role_arn != null ? var.ci_role_arn : ""
  })
  lifecycle {
    # avoid Terraform attempting to recreate on update unless changed explicitly
  }
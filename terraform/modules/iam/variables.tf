# terraform/modules/iam/variables.tf

variable "environment" { type = string }
variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "oidc_id" { type = string }
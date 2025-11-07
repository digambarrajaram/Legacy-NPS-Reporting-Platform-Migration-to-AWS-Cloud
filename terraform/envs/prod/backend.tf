# terraform/envs/prod/backend.tf
# Configuration for the remote state for the PROD environment

terraform {
  backend "s3" {
    bucket         = "protean-terraform-state-prod" # REPLACE
    key            = "nps-reporting/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "nps-terraform-locks" # Must exist before terraform init
    encrypt        = true
  }
}
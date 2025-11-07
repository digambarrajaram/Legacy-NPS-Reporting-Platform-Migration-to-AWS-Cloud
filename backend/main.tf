
provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket        = "protean-terraform-state-prod"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "version" {
  bucket = "protean-terraform-state-prod"
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name     = "nps-terraform-locks"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  billing_mode = "PAY_PER_REQUEST"
}

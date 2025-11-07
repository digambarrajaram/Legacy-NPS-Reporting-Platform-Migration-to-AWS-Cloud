resource "aws_s3_bucket" "reporting_storage" {
  bucket        = "protean-nps-reports-${var.environment}"
  force_destroy = var.force_destroy
  tags          = { Name = "NPS Reporting Storage - ${var.environment}" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reporting_enc" {
  bucket = aws_s3_bucket.reporting_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "reporting_lifecycle" {
  bucket = aws_s3_bucket.reporting_storage.id

  rule {
    id     = "archive_old_reports"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 3650
    }
  }
}
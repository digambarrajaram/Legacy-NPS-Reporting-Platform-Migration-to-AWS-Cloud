variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "rds_instance_type" {
  type    = string
  default = "db.t3.small"
}

variable "db_master_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "account_id" {
  type    = string
  default = "605134452604"
}

variable "eks_ssh_key_name" {
  type    = string
  default = "nps-report-key"
}

# Destroy-safety toggles (set to false in prod if required)
variable "rds_skip_final_snapshot" {
  description = "If true, skip final snapshot on RDS destroy"
  type        = bool
  default     = true
}

variable "s3_force_destroy" {
  description = "If true, empty & delete S3 buckets on destroy"
  type        = bool
  default     = true
}

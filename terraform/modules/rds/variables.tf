variable "environment"           { type = string }
variable "vpc_id"                { type = string }
variable "private_subnet_ids"    { type = list(string) }
variable "instance_type"         { type = string }
variable "vpc_security_group_id" { type = string }

variable "db_master_password" {
  type      = string
  sensitive = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (true for non-prod)"
  type        = bool
  default     = true
}

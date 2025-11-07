variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "reporting_irsa_role_arn" { type = string }
variable "eks_master_arn"          { type = string }
variable "eks_node_group_arn"      { type = string }

variable "eks_ssh_key_name" { type = string }
variable "aws_region"       { type = string }

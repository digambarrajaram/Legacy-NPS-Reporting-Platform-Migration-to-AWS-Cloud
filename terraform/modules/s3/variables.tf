variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "force_destroy" {
  type    = bool
  default = true
}

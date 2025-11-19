variable "name" {
  type = string
  description = "Repository name"
}


variable "tags" {
  type = map(string)
  default = {}
}


variable "aws_region" {
  type = string
  default = "ap-south-1"
}


variable "kms_key_alias" {
  type = string
  description = "KMS key alias to use for encryption. If blank, a new key will be created."
  default = ""
}


variable "image_retention_days" {
  type = number
  default = 90
}
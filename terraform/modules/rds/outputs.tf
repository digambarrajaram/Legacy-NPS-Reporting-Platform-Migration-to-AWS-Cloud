# terraform/modules/rds/outputs.tf

output "rds_endpoint" {
  value = aws_db_instance.nps_reporting.address
}
resource "aws_db_subnet_group" "nps_reporting" {
  name       = "${var.environment}-nps-reporting-sng"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.environment}-nps-reporting-sng" }
}

resource "aws_db_instance" "nps_reporting" {
  allocated_storage       = 200
  storage_type            = "gp3"
  engine                  = "postgres"
  engine_version          = "17"
  instance_class          = var.instance_type
  identifier              = "${var.environment}-nps-reporting-db"
  username                = "protean_nps_admin"
  password                = var.db_master_password
  db_subnet_group_name    = aws_db_subnet_group.nps_reporting.name
  vpc_security_group_ids  = [var.vpc_security_group_id]
  multi_az                = true
  backup_retention_period = 7
  publicly_accessible     = false

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.environment}-nps-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  tags = { Name = "${var.environment}-NPS-Reporting-DB" }
}

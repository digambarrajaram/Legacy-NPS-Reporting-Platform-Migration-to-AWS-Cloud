output "vpc_id"          { value = aws_vpc.nps_vpc.id }
output "private_subnets" { value = [for s in aws_subnet.private : s.id] }
output "rds_sg_id"       { value = aws_security_group.rds_sg.id }

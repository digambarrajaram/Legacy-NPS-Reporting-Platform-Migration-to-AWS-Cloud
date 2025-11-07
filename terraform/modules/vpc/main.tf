data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "nps_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.environment}-nps-vpc" }
}

# Private subnets (3 AZs)
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.nps_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.environment}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.environment}-nps-eks" = "owned"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nps_vpc.id
  tags   = { Name = "${var.environment}-igw" }
}

# Public subnet (for NAT)
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.nps_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 200) # e.g., 10.10.200.0/24
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.environment}-public-1a"
    "kubernetes.io/role/elb" = "1"
  }
}

# Public route table → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.nps_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

# NAT (in public subnet)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "${var.environment}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public_1a.id
  allocation_id = aws_eip.nat.id
  tags = { Name = "${var.environment}-nat" }

  timeouts { delete = "30m" }
}

# Private route table → NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.nps_vpc.id
  tags   = { Name = "${var.environment}-private-rt" }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Associate ALL private subnets to the private RT
resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# RDS SG (no inline cross-SG refs)
resource "aws_security_group" "rds_sg" {
  name   = "${var.environment}-rds-access-sg"
  vpc_id = aws_vpc.nps_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-rds-access-sg" }
}

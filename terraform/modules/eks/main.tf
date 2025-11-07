#############################################
# EKS Security Group - Control Plane
#############################################
resource "aws_security_group" "eks_cluster_sg" {
  name   = "${var.environment}-eks-cluster-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Self-referencing for EKS Control Plane"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  tags = {
    Name = "${var.environment}-eks-cluster-sg"
  }
}

#############################################
# EKS Cluster
#############################################
resource "aws_eks_cluster" "nps_cluster" {
  name     = "${var.environment}-nps-eks"
  role_arn = var.eks_master_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
  }

  timeouts {
    delete = "60m"
  }
}

#############################################
# EKS Security Group - Worker Nodes
#############################################
resource "aws_security_group" "eks_worker_sg" {
  name        = "${var.environment}-eks-worker-sg"
  vpc_id      = var.vpc_id
  description = "Security group for EKS worker nodes (EC2 instances)"

  # Allow from control plane SG
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  # Allow all egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-eks-worker-sg"
  }
}

#############################################
# EKS Managed Node Group
#############################################
resource "aws_eks_node_group" "nps_workers" {
  cluster_name    = aws_eks_cluster.nps_cluster.name
  node_group_name = "${var.environment}-nps-workers"
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.small"]
  disk_size       = 80
  node_role_arn   = var.eks_node_group_arn

  scaling_config {
    desired_size = 3
    max_size     = 15
    min_size     = 3
  }

  remote_access {
    ec2_ssh_key               = var.eks_ssh_key_name
    source_security_group_ids = [aws_security_group.eks_worker_sg.id]
  }

  timeouts {
    delete = "60m"
  }
}

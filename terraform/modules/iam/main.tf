resource "aws_iam_role" "eks_master" {
  name_prefix = "${var.environment}-eks-master-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_master_policy_attachment" {
  role       = aws_iam_role.eks_master.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node_group" {
  name_prefix = "${var.environment}-eks-worker-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "node_group_policy_worker" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
# Cluster role needs VPC resource controller (manages SGs/ENIs for EKS)
resource "aws_iam_role_policy_attachment" "eks_master_vpc_controller" {
  role       = aws_iam_role.eks_master.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# Node role needs CNI & ECR read to bootstrap pods
resource "aws_iam_role_policy_attachment" "node_group_policy_cni" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_group_policy_ecr" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}



# -- outputs (ensure these exist) --
output "reporting_service_irsa_arn" { value = aws_iam_role.reporting_service_irsa.arn }
output "eks_master_arn"             { value = aws_iam_role.eks_master.arn }
output "eks_node_group_arn"         { value = aws_iam_role.eks_node_group.arn }

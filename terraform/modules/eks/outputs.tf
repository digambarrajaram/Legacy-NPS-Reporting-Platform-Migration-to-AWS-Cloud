output "cluster_name"     { value = aws_eks_cluster.nps_cluster.name }
output "nodegroup_name"   { value = aws_eks_node_group.nps_workers.node_group_name }
output "eks_worker_sg_id" { value = aws_security_group.eks_worker_sg.id }
output "vpc_id"           { value = var.vpc_id }

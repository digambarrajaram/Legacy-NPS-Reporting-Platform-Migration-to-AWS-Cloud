# Ensure you're in the correct workspace
terraform workspace select default

# List of all tracked resources in dependency-safe order
$targets = @(
  # EKS security groups
  "module.eks.aws_security_group.eks_worker_sg",
  "module.eks.aws_security_group.eks_cluster_sg",

  # IAM roles and attachments
  "module.iam.aws_iam_role_policy_attachment.node_group_policy_worker",
  "module.iam.aws_iam_role_policy_attachment.s3_access_attachment",
  "module.iam.aws_iam_role.reporting_service_irsa",

  # VPC subnets
  "module.vpc.aws_subnet.private[0]",
  "module.vpc.aws_subnet.private[1]",
  "module.vpc.aws_subnet.private[2]",

  # VPC itself
  "module.vpc.aws_vpc.nps_vpc"
)

# Loop through each target and destroy it
foreach ($target in $targets) {
  Write-Host "🔄 Destroying $target..."
  terraform destroy --target=$target --auto-approve
}

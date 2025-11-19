#############################################
# Provider
#############################################
data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Stack       = "nps-reporting"
    }
  }
}

#############################################
# 1) IAM
#############################################
module "iam" {
  source      = "../../modules/iam"
  environment = var.environment
  aws_region  = var.aws_region
  account_id  = var.account_id
  oidc_id     = "DUMMY_OIDC_ID"
}

#############################################
# 2) VPC (no dependency on EKS)
#############################################
module "vpc" {
  source             = "../../modules/vpc"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  aws_region         = var.aws_region
}

#############################################
# 3) EKS (depends on VPC + IAM)
#############################################
module "eks" {
  source                  = "../../modules/eks"
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnets
  reporting_irsa_role_arn = module.iam.reporting_service_irsa_arn
  eks_master_arn          = module.iam.eks_master_arn
  eks_node_group_arn      = module.iam.eks_node_group_arn
  eks_ssh_key_name        = var.eks_ssh_key_name
  aws_region              = var.aws_region

  depends_on = [module.iam, module.vpc]
}

#############################################
# 4) RDS
#############################################
module "rds" {
  source                = "../../modules/rds"
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnets
  instance_type         = var.rds_instance_type
  db_master_password    = var.db_master_password
  vpc_security_group_id = module.vpc.rds_sg_id
  skip_final_snapshot   = var.rds_skip_final_snapshot
}

#############################################
# 5) S3
#############################################
module "s3" {
  source        = "../../modules/s3"
  environment   = var.environment
  aws_region    = var.aws_region
  force_destroy = var.s3_force_destroy
}

#############################################
# 6) Connect EKS → RDS (breaks SG cycles)
#############################################
resource "aws_security_group_rule" "allow_eks_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.vpc.rds_sg_id
  source_security_group_id = module.eks.eks_worker_sg_id

  lifecycle {
    precondition {
      condition     = module.vpc.vpc_id != null && module.eks.vpc_id != null && module.vpc.vpc_id == module.eks.vpc_id
      error_message = "EKS and RDS must be in the same VPC."
    }
  }
}
module "ecr" {
  source = "../../modules/ecr"
  name = var.name
  tags = var.tags
  kms_key_alias = var.kms_key_alias
  image_retention_days = var.image_retention_days
}

resource "local_file" "jenkins_ecr_output" {
  filename = "${path.module}/jenkins-outputs.json"
  content  = templatefile("${path.module}/jenkins-outputs.tpl", {
    account_id            = data.aws_caller_identity.current.account_id,
    region                = var.aws_region,
    repository_url        = module.ecr.repository_url,
    repository_name       = module.ecr.repository_name,
    repository_arn        = module.ecr.repository_arn,
    eks_cluster_name      = module.eks.cluster_name,
    eks_cluster_endpoint  = module.eks.cluster_endpoint,
    eks_cluster_ca        = module.eks.cluster_ca_data,
    irsa_role_arn         = module.iam.irsa_role_arn,
    k8s_namespace         = var.k8s_namespace,
    helm_release_name     = var.helm_release_name,
    reporting_s3_bucket   = module.s3.reporting_bucket_name,
    rds_endpoint          = module.rds.endpoint,
    rds_port              = module.rds.port,
    secrets_manager_prefix = var.secrets_manager_prefix
  })
  file_permission = "0640"
}
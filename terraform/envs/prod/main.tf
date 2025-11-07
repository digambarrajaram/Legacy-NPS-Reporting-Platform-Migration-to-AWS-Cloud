#############################################
# Provider
#############################################
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

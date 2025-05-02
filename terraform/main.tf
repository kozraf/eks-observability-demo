###############################################################################
# main.tf – full file
# * Creates a VPC
# * Creates an “eks‑admin” IAM role (AdministratorAccess)
# * Deploys the EKS cluster + managed node group
# * Maps the eks‑admin role into the aws‑auth ConfigMap
###############################################################################

terraform {
  required_version = ">= 1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79"
    }
  }
}

####################
# Provider
####################
provider "aws" {
  region = var.region
}

####################
# VPC
####################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

####################
# IAM role for cluster admins
####################
resource "aws_iam_role" "eks_admin" {
  name = "eks-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_admin_attach" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

####################
# EKS cluster + node group
####################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
    }
  }

  tags = {
    Environment = "demo"
  }
}

####################
# aws‑auth ConfigMap (new sub‑module API in v20.x)
####################
###############################################################################
# aws‑auth ConfigMap
###############################################################################
module "aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "20.36.0"

  depends_on = [module.eks]

  # create the ConfigMap
  create_aws_auth_configmap = true

  # v20.x expects the cluster *ID* (ARN), not the name
  eks_cluster_id = module.eks.cluster_id

  # role mappings
  iam_role_mappings = [
    {
      rolearn  = aws_iam_role.eks_admin.arn
      username = "eks-admin"
      groups   = ["system:masters"]
    }
  ]
}


###############################################################################
# Terraform requirements & AWS provider
###############################################################################
terraform {
  required_version = ">= 1.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

###############################################################################
# Common data & tags
###############################################################################
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

locals {
  tags = {
    Project   = "eks‑observability‑demo"
    Terraform = "true"
  }

  # Principal that should get full admin access in the EKS console / kubectl
  admin_principal_arn = (
    var.admin_principal_arn != ""
      ? var.admin_principal_arn
      : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cloud_user"
  )
}

###############################################################################
# Network – simple three‑AZ VPC
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

###############################################################################
# EKS – managed node group + access entries
###############################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Networking
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Default node‑group settings
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    disk_size      = 20
    instance_types = ["t3.medium"]
  }

  # One managed node‑group
  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
  }

  # Access entries
  # ‑ The CodeBuild role is added automatically by the module as “cluster_creator”.
  # ‑ We add cloud_user (or a supplied principal) as an additional admin.
  access_entries = {
    cloud_admin = {
      principal_arn = local.admin_principal_arn
      policy        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      type          = "STANDARD"
    }
  }

  tags = local.tags
}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = local.admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_cluster" {
  cluster_name  = module.eks.cluster_name
  principal_arn = local.admin_principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope { type = "cluster" }

  depends_on = [aws_eks_access_entry.admin]
}
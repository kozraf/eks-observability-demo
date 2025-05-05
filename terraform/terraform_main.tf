###############################################################################
# Terraform requirements & provider
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
# Data sources  (only ONE aws_caller_identity!)
###############################################################################
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# Locals
###############################################################################
locals {
  tags = {
    Project   = "eks-observability-demo"
    Terraform = "true"
  }

  admin_principal_arn = (
    var.admin_principal_arn != ""
      ? var.admin_principal_arn
      : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cloud_user"
  )
}

###############################################################################
# Network – three‑AZ VPC
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

  enable_nat_gateway  = true
  single_nat_gateway  = true

  tags = local.tags
}

###############################################################################
# EKS cluster
###############################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  


  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    disk_size      = 20
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
  }

  access_entries = {
    cloud_admin = {
      principal_arn = local.admin_principal_arn
      type          = "STANDARD"
      policy_associations = [
        {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          # an empty map ⇒ cluster‑wide scope
          access_scope = {          # required keys
           type = "cluster"        # cluster‑wide
          }
        }
      ]
    }
  }

  tags = local.tags
}
provider "aws" {
  region = var.region
}

# ────────── Default VPC & subnets (unchanged) ──────────
data "aws_vpc" "default" { default = true }

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "valid" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = [
      for az in data.aws_availability_zones.available.names :
      az if az != "us-east-1e"
    ]
  }
}

# ────────── EKS module ──────────
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.valid.ids
  enable_irsa = true

  # ★ NEW: make the control plane public so CodeBuild can reach it
  cluster_endpoint_public_access = true
  public_access_cidrs            = ["0.0.0.0/0"]

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.small"]
    }
  }

  tags = {
    env = "demo"
  }
}

output "cluster_name" {
  value = module.eks.cluster_name
}

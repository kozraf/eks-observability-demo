provider "aws" {
  region = var.region
}

# Automatically find default VPC
data "aws_vpc" "default" {
  default = true
}

# Automatically get public subnets in that VPC
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


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.28"
  vpc_id          = data.aws_vpc.default.id
  subnet_ids      = data.aws_subnets.default.ids
  enable_irsa     = true

  eks_managed_node_groups = {
    default = {
      desired_size    = 2
      max_size        = 3
      min_size        = 1
      instance_types  = ["t3.small"]
    }
  }
}

###############################################################################
#  bootstrap_codebuild.tf  – COMPLETE, FIXED FILE
###############################################################################
terraform {
  required_version = ">= 1.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

provider "aws" { region = var.region }

############################
# Random suffix
############################
resource "random_pet" "suffix" {}

############################
# Remote‑state S3 bucket
############################
resource "aws_s3_bucket" "state" {
  bucket        = "tf-state-${random_pet.suffix.id}"
  force_destroy = true

  versioning { enabled = true }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = { Purpose = "terraform-state" }
}

############################
# DynamoDB lock table
############################
resource "aws_dynamodb_table" "lock" {
  name         = "tf-lock-${random_pet.suffix.id}"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
  tags = { Purpose = "terraform-lock" }
}

############################
# CodeBuild service role
############################
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-eks-observability-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################
# CodeBuild project
############################
resource "aws_codebuild_project" "eks_pipeline" {
  name         = "eks-observability-demo"
  description  = "Builds VPC + EKS + monitoring stack"
  service_role = aws_iam_role.codebuild_role.arn
  build_timeout = 60

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "terraform/buildspec.yml"
    report_build_status = true
  }

  environment {
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    privileged_mode = true

    environment_variable { name = "AWS_REGION"      value = var.region }
    environment_variable { name = "TF_STATE_BUCKET" value = aws_s3_bucket.state.bucket }
    environment_variable { name = "TF_LOCK_TABLE"   value = aws_dynamodb_table.lock.name }
  }

  artifacts { type = "NO_ARTIFACTS" }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/eks-observability-demo"
      stream_name = "build-log"
    }
  }
}

############################
# Outputs (optional)
############################
output "state_bucket" { value = aws_s3_bucket.state.bucket }
output "lock_table"   { value = aws_dynamodb_table.lock.name }

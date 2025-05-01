variable "github_repo_url" {}
variable "region" {
  default = "us-east-1"
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-eks-observability-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_admin" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_codebuild_project" "eks_monitoring" {
  name          = "eks-observability-demo"
  service_role  = aws_iam_role.codebuild_role.arn
  description   = "Bootstrap EKS & observability stack"
  build_timeout = 20

  source {
    type      = "GITHUB"
    location  = var.github_repo_url
    buildspec = "terraform/buildspec.yml"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = false
    }
  }

  triggers {
    webhook = true
    filter_groups = [
      [
        {
          type    = "EVENT"
          pattern = "PUSH"
        }
      ]
    ]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }
}

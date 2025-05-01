resource "aws_codebuild_project" "eks_monitoring" {
  name          = "eks-observability-demo"
  service_role  = aws_iam_role.codebuild_role.arn
  description   = "Bootstrap EKS & observability stack"
  build_timeout = 20

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    buildspec       = "terraform/buildspec.yml"
    git_clone_depth = 1
    git_submodules_config {
      fetch_submodules = false
    }
    git_config {
      fetch_submodules = false
    }
    report_build_status = true
    webhook             = true
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

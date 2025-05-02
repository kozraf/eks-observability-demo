############################################
#  Bootstrap: IAM + CodeBuild (GitHub PAT) #
############################################

# —— Look up current AWS account ID ——
data "aws_caller_identity" "current" {}

# —— Secret lookup by NAME ——
data "aws_secretsmanager_secret" "github_pat" {
  name = var.github_pat_secret_name
}

data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = data.aws_secretsmanager_secret.github_pat.id
}

# —— Source Credential: GitHub PAT ——
resource "aws_codebuild_source_credential" "github_pat" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = data.aws_secretsmanager_secret_version.github_pat.secret_string
}

# —— CodeBuild service role ——
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-eks-observability-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# —— Permit the role to read only the PAT secret ——
resource "aws_iam_role_policy" "read_pat_secret" {
  name = "read-github-pat"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.github_pat_secret_name}*"
    }]
  })
}

# —— CodeBuild project ——
resource "aws_codebuild_project" "eks_monitoring" {
  name          = "eks-observability-demo"
  description   = "Builds EKS + monitoring stack"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30

  source {
    type     = "GITHUB"
    location = var.github_repo_url

    # <- Fix: tell CodeBuild to use whatever PAT is registered
    auth {
      type = "CODEBUILD"
    }

    buildspec           = "terraform/buildspec.yml"
    git_clone_depth     = 1
    report_build_status = true
  }

  environment {
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    privileged_mode = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/eks-observability-demo"
      stream_name = "build-log"
    }
  }
}

# —— Webhook: trigger on any push ——
resource "aws_codebuild_webhook" "eks_webhook" {
  project_name = aws_codebuild_project.eks_monitoring.name

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
  }
}

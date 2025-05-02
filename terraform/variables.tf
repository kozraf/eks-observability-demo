variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "my-eks-cluster"
}

variable "codebuild_role_arn" {
  description = "IAM role ARN used by CodeBuild"
  type        = string
}
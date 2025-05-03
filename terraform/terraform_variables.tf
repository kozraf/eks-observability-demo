variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "my-eks-cluster"
}

variable "admin_principal_arn" {
  description = "IAM ARN that should get cluster‑admin access in the EKS Console"
  type        = string
  default     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cloud_user"
}

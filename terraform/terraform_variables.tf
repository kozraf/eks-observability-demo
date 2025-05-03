###############################################################################
# Standard inputs you already had
###############################################################################
variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the control plane"
  type        = string
  default     = "1.30"
}

###############################################################################
# NEW – optional admin principal
###############################################################################
variable "admin_principal_arn" {
  description = <<EOT
IAM ARN that should receive AmazonEKSClusterAdminPolicy through an access‑entry.
Leave blank to fall back to user/cloud_user in the current AWS account.
EOT
  type    = string
  default = ""        # <‑‑ keep empty so we can compute a fallback in locals
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "my-eks-cluster"
}

variable "admin_principal_arn" {
  description = "IAM ARN that should have admin access in the EKS Console.
                 Leave blank to default to user/cloud_user in the current account."
  type        = string
  default     = ""          # <‑‑ static; no interpolation allowed
}

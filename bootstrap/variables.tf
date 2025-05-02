############################################
#  Variables for the bootstrap Terraform  #
############################################

variable "region" {
  description = "AWS region for bootstrap resources"
  default     = "us-east-1"
}

variable "github_repo_url" {
  description = "HTTPS URL of the GitHub repository CodeBuild will clone"
}

# PAT secret is always stored under this name in Secrets Manager;
# the account‑specific ARN is derived automatically.
variable "github_pat_secret_name" {
  description = "Secrets Manager secret name that stores the GitHub PAT"
  default     = "github/pat/eks-observability-demo"
}



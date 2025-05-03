output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base‑64‑encoded cert data"
  value       = module.eks.cluster_certificate_authority_data
}
output "cluster_name" {
  description = "k3d cluster name"
  value       = var.cluster_name
}

output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = var.enable_certmanager
}

output "cnpg_enabled" {
  description = "Whether CloudNativePG is enabled"
  value       = var.enable_cnpg
}

output "minio_enabled" {
  description = "Whether MinIO is enabled"
  value       = var.enable_minio
}

output "keycloak_operator_enabled" {
  description = "Whether Keycloak Operator is enabled"
  value       = var.enable_keycloak_operator
}

output "keycloak_enabled" {
  description = "Whether Keycloak is enabled"
  value       = var.enable_keycloak
}

output "librechat_enabled" {
  description = "Whether LibreChat is enabled"
  value       = var.enable_librechat
}

output "keycloak_url" {
  description = "Keycloak URL when enabled"
  value       = var.enable_keycloak ? "http://keycloak.keycloak.svc:8080" : null
}

output "keycloak_admin_password" {
  description = "Keycloak admin password"
  value       = var.enable_keycloak ? var.keycloak_admin_password : null
  sensitive   = true
}

output "minio_url" {
  description = "MinIO URL when enabled"
  value       = var.enable_minio ? "http://minio.minio.svc:9000" : null
}
variable "cluster_name" {
  description = "k3d cluster name"
  type        = string
  default     = "dev"
}

variable "enable_certmanager" {
  description = "Enable cert-manager"
  type        = bool
  default     = true
}

variable "enable_cnpg" {
  description = "Enable CloudNativePG"
  type        = bool
  default     = false
}

variable "enable_minio" {
  description = "Enable MinIO"
  type        = bool
  default     = false
}

variable "enable_keycloak_operator" {
  description = "Enable Keycloak Operator"
  type        = bool
  default     = false
}

variable "enable_keycloak" {
  description = "Enable Keycloak instance"
  type        = bool
  default     = false
}

variable "enable_librechat" {
  description = "Enable LibreChat"
  type        = bool
  default     = false
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  default     = ""
  sensitive  = true
}

variable "keycloak_db_password" {
  description = "Keycloak database password"
  type        = string
  default     = ""
  sensitive  = true
}

variable "minio_root_user" {
  description = "MinIO root user"
  type        = string
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  default     = "minioadmin"
  sensitive   = true
}

variable "librechat_admin_email" {
  description = "LibreChat admin email"
  type        = string
  default     = "admin@example.com"
}

variable "librechatAdminPassword" {
  description = "LibreChat admin password"
  type        = string
  default     = ""
  sensitive   = true
}
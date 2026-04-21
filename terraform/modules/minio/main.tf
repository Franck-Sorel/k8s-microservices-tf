variable "root_user" {
  description = "MinIO root user"
  type        = string
  default     = "minioadmin"
}

variable "root_password" {
  description = "MinIO root password"
  type        = string
  default     = "minioadmin"
  sensitive   = true
}

resource "helm_release" "minio" {
  name             = "minio"
  repository       = "https://charts.min.io"
  chart            = "minio"
  version         = "5.0.14"
  namespace        = "minio"
  create_namespace = true

  set {
    name  = "mode"
    value = "standalone"
  }

  set {
    name  = "rootUser"
    value = var.root_user
  }

  set {
    name  = "rootPassword"
    value = var.root_password
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }
}

output "service_name" {
  value = "minio"
}

output "service_namespace" {
  value = "minio"
}
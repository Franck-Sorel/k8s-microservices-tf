variable "admin_email" {
  description = "LibreChat admin email"
  type        = string
  default     = "admin@example.com"
}

variable "admin_password" {
  description = "LibreChat admin password"
  type        = string
  default     = ""
  sensitive   = true
}

resource "random_password" "admin_password" {
  length  = 16
  special = true
}

locals {
  admin_pass = var.admin_password != "" ? var.admin_password : random_password.admin_password.result
}

resource "kubernetes_namespace" "librechat" {
  metadata {
    name = "librechat"
  }
}

resource "kubernetes_secret" "librechat_credentials" {
  metadata {
    name      = "librechat-creds"
    namespace = kubernetes_namespace.librechat.metadata.0.name
  }

  data = {
    username = "admin"
    password = local.admin_pass
    email    = var.admin_email
  }

  type = "Opaque"
}

resource "helm_release" "librechat" {
  name             = "librechat"
  repository       = "https://danny-avila.github.io/librechat-chart"
  chart            = "librechat"
  version         = "0.1.0"
  namespace        = kubernetes_namespace.librechat.metadata.0.name
  create_namespace = false

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "ingress.enabled"
    value = "false"
  }

  set {
    name  = "mongodb.enabled"
    value = "true"
  }

  depends_on = [kubernetes_secret.librechat_credentials]
}

output "namespace" {
  value = "librechat"
}

output "admin_password" {
  value     = local.admin_pass
  sensitive = true
}
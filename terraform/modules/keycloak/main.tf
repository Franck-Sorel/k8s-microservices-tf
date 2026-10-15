variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  default     = "keycloak123"
  sensitive   = true
}

variable "db_password" {
  description = "Keycloak database password"
  type        = string
  default     = "keycloak123"
  sensitive   = true
}

variable "db_host" {
  description = "PostgreSQL host"
  type        = string
  default     = "keycloak-db-postgresql.keycloak-db.svc.cluster.local"
}

resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = "keycloak"
  }
}

resource "helm_release" "keycloak_db" {
  name             = "keycloak-db"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "postgresql"
  version          = "18.5.24"
  namespace        = "keycloak-db"
  create_namespace = true

  set {
    name  = "auth.username"
    value = "keycloak"
  }

  set {
    name  = "auth.password"
    value = var.db_password
  }

  set {
    name  = "auth.database"
    value = "keycloak"
  }

  set {
    name  = "primary.persistence.size"
    value = "5Gi"
  }
}

resource "helm_release" "keycloak" {
  name             = "keycloak"
  repository       = "https://codecentric.github.io/helm-charts"
  chart            = "keycloak"
  version          = "32.0.0"
  namespace        = kubernetes_namespace.keycloak.metadata.0.name
  create_namespace = false

  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "extraEnvVars[0].name"
    value = "KC_DB_URL"
  }

  set {
    name  = "extraEnvVars[0].value"
    value = "jdbc:postgresql://${var.db_host}:5432/keycloak"
  }

  set {
    name  = "extraEnvVars[1].name"
    value = "KC_DB_USERNAME"
  }

  set {
    name  = "extraEnvVars[1].value"
    value = "keycloak"
  }

  set {
    name  = "extraEnvVars[2].name"
    value = "KC_DB_PASSWORD"
  }

  set {
    name  = "extraEnvVars[2].value"
    value = var.db_password
  }

  depends_on = [helm_release.keycloak_db]
}

output "namespace" {
  value = "keycloak"
}

output "admin_password" {
  value     = var.admin_password
  sensitive = true
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}
resource "helm_release" "keycloak_operator" {
  name       = "keycloak-operator"
  chart     = "keycloak-operator"
  version   = "0.0.4"
  namespace = "keycloak-operator"
  create_namespace = true

  repository = "https://kbumsik.io/keycloak-kubernetes/"
}
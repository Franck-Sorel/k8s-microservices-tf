resource "helm_release" "cnpg" {
  name             = "cloudnative-pg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "1.22.1"
  namespace        = "cnpg-system"
  create_namespace = true

  set {
    name  = "crds.create"
    value = "true"
  }
}
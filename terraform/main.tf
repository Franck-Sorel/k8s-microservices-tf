module "cert_manager" {
  source = "./modules/cert-manager"

  count = var.enable_certmanager ? 1 : 0

  depends_on = []
}

module "cnpg" {
  source = "./modules/cnpg"

  count = var.enable_cnpg ? 1 : 0

  depends_on = [module.cert_manager]
}

module "minio" {
  source = "./modules/minio"

  count = var.enable_minio ? 1 : 0

  depends_on = []

  root_user    = var.minio_root_user
  root_password = var.minio_root_password
}

module "keycloak_operator" {
  source = "./modules/keycloak-operator"

  count = var.enable_keycloak_operator ? 1 : 0

  depends_on = []
}

module "keycloak" {
  source = "./modules/keycloak"

  count = var.enable_keycloak ? 1 : 0

  depends_on = [module.keycloak_operator, module.cnpg]

  admin_password = var.keycloak_admin_password
  db_password   = var.keycloak_db_password
}

module "librechat" {
  source = "./modules/librechat"

  count = var.enable_librechat ? 1 : 0

  depends_on = [module.minio]

  admin_email    = var.librechat_admin_email
  admin_password = var.librechatAdminPassword
}
#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[WIZARD]${NC} $1"; }

# Default values
CLUSTER_NAME="dev"
INSTALL_CERT_MANAGER="Y"
INSTALL_CNPG="Y"
INSTALL_MINIO="N"
INSTALL_KEYCLOAK="Y"
INSTALL_LIBRECHAT="N"

print_header() {
    echo ""
    echo "========================================="
    echo "  k3d Local Platform Bootstrap"
    echo "  Interactive Wizard"
    echo "========================================="
    echo ""
}

prompt_cluster() {
    log_step "Cluster Configuration"
    echo ""
    echo "Available clusters:"
    k3d cluster list 2>/dev/null || echo "  (none)"
    echo ""
    read -p "Use existing cluster? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        read -p "New cluster name [dev]: " CLUSTER_NAME
        CLUSTER_NAME=${CLUSTER_NAME:-dev}
        log_info "Creating cluster '$CLUSTER_NAME'..."
        k3d cluster create $CLUSTER_NAME --agents 1 -p "8080:80@loadbalancer" -p "8443:443@loadbalancer"
    else
        k3d cluster list
        read -p "Select cluster name: " SELECTED_CLUSTER
        SELECTED_CLUSTER=${SELECTED_CLUSTER:-dev}
        kubectl config use-context k3d-$SELECTED_CLUSTER 2>/dev/null || true
    fi
}

prompt_components() {
    log_step "Component Selection"
    echo ""
    echo "Select components to install:"
    echo ""

    read -p "cert-manager (TLS certificates)? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_CERT_MANAGER="N"

    read -p "CloudNativePG (PostgreSQL)? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_CNPG="N"

    read -p "MinIO (S3 storage)? [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_MINIO="Y"

    read -p "Keycloak (Identity)? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_KEYCLOAK="N"
        INSTALL_KEYCLOAK_DB="N"
    else
        if [[ $INSTALL_CNPG == "N" ]]; then
            INSTALL_KEYCLOAK_DB="Y"
        fi
    fi

    read -p "LibreChat (AI chat)? [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_LIBRECHAT="Y"
}

resolve_dependencies() {
    log_step "Resolving Dependencies"
    echo ""

    # Keycloak needs DB
    if [[ $INSTALL_KEYCLOAK == "Y" && $INSTALL_KEYCLOAK_DB == "N" && $INSTALL_CNPG == "N" ]]; then
        log_warn "Keycloak needs a database. Enabling keycloak-db (PostgreSQL)..."
        INSTALL_KEYCLOAK_DB="Y"
    fi

    echo "Dependencies resolved."
}

print_plan() {
    log_step "Execution Plan"
    echo ""
    echo "Cluster: $CLUSTER_NAME"
    echo "Install:"
    [[ $INSTALL_CERT_MANAGER == "Y" ]] && echo "[x] cert-manager"
    [[ $INSTALL_CNPG == "Y" ]] && echo "[x] CloudNativePG"
    [[ $INSTALL_MINIO == "Y" ]] && echo "[x] MinIO"
    [[ $INSTALL_KEYCLOAK == "Y" ]] && echo "[x] Keycloak"
    [[ $INSTALL_KEYCLOAK_DB == "Y" ]] && echo "[x] Keycloak DB"
    [[ $INSTALL_LIBRECHAT == "Y" ]] && echo "[x] LibreChat"
    echo ""
}

prompt_confirm() {
    read -p "Proceed? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
}

apply_plan() {
    log_step "Applying Configuration"
    echo ""

    # Export vars for helmfile
    export ENABLE_CERT_MANAGER=$INSTALL_CERT_MANAGER
    export ENABLE_CNPG=$INSTALL_CNPG
    export ENABLE_MINIO=$INSTALL_MINIO
    export ENABLE_KEYCLOAK=$INSTALL_KEYCLOAK
    export ENABLE_KEYCLOAK_DB=$INSTALL_KEYCLOAK_DB
    export ENABLE_LIBRECHAT=$INSTALL_LIBRECHAT

    # Init repos
    log_info "Initializing helm repos..."
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    helm repo add codecentric https://codecentric.github.io/helm-charts 2>/dev/null || true
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo add cloudnative-pg https://cloudnative-pg.github.io/charts 2>/dev/null || true
    helm repo update

    # Apply via helmfile
    log_info "Installing components..."
    helmfile sync

    log_info "Done!"
}

main() {
    print_header
    prompt_cluster
    prompt_components
    resolve_dependencies
    print_plan
    prompt_confirm
    apply_plan

    echo ""
    log_info "Platform ready!"
    echo ""
    echo "Use 'kubectl port-forward' to access services:"
    echo "  Keycloak: kubectl port-forward -n keycloak svc/keycloak-http 8080:80"
    echo "  LibreChat: kubectl port-forward -n librechat svc/librechat-librechat 3080:80"
    echo "  MinIO: kubectl port-forward -n minio svc/minio 9000:80"
    echo ""
}

main "$@"
#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prereqs() {
    log_info "Checking prerequisites..."
    local missing=0
    for cmd in docker kubectl terraform helm k3d; do
        if ! command -v $cmd >/dev/null 2>&1; then
            log_error "$cmd not found"
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        log_error "Missing required tools"
        exit 1
    fi
    log_info "All prerequisites found"
}

prompt_cluster() {
    echo ""
    echo "=== Cluster Configuration ==="
    read -p "Use existing cluster or create new? [y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p "Cluster name [dev]: " CLUSTER_NAME
        CLUSTER_NAME=${CLUSTER_NAME:-dev}
        log_info "Creating cluster '$CLUSTER_NAME'..."
        k3d cluster create $CLUSTER_NAME \
            --agents 1 \
            -p "8080:80@loadbalancer" \
            -p "8443:443@loadbalancer" \
            --kubeconfig-update-default \
            --kubeconfig-switch-context
    else
        k3d cluster list
        read -p "Select cluster name: " CLUSTER_NAME
        kubectl use context $CLUSTER_NAME 2>/dev/null || k3d cluster list
    fi
}

prompt_components() {
    echo ""
    echo "=== Component Selection ==="
    echo "Select components to install:"
    echo ""

    local install_certmanager="n"
    local install_cnpg="n"
    local install_minio="n"
    local install_keycloak="n"
    local install_librechat="n"

    read -p "Install cert-manager? [y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then install_certmanager="y"; fi

    read -p "Install CloudNativePG (CNPG)? [y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then install_cnpg="y"; fi

    read -p "Install MinIO? [y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then install_minio="y"; fi

    read -p "Install Keycloak? [y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then install_keycloak="y"; fi

    read -p "Install LibreChat? [y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then install_librechat="y"; fi

    export INSTALL_CERTMANAGER=$install_certmanager
    export INSTALL_CNPG=$install_cnpg
    export INSTALL_MINIO=$install_minio
    export INSTALL_KEYCLOAK=$install_keycloak
    export INSTALL_LIBRECHAT=$install_librechat
}

prompt_profile() {
    echo ""
    echo "=== Profile Selection ==="
    echo "1) minimal  - cert-manager only"
    echo "2) auth     - cert-manager + Keycloak"
    echo "3) full     - all components"
    read -p "Select profile [1-3]: " choice
    case $choice in
        1) PROFILE="minimal";;
        2) PROFILE="auth";;
        3) PROFILE="full";;
        *) PROFILE="minimal";;
    esac
    log_info "Selected profile: $PROFILE"
}

main() {
    check_prereqs

    echo ""
    echo "========================================="
    echo "  Local Kubernetes Platform Bootstrap"
    echo "========================================="
    echo ""

    prompt_cluster
    prompt_profile
    prompt_components

    echo ""
    echo "=== Summary ==="
    echo "Cluster: $CLUSTER_NAME"
    echo "Profile: $PROFILE"
    echo "cert-manager: $INSTALL_CERTMANAGER"
    echo "CNPG: $INSTALL_CNPG"
    echo "MinIO: $INSTALL_MINIO"
    echo "Keycloak: $INSTALL_KEYCLOAK"
    echo "LibreChat: $INSTALL_LIBRECHAT"
    echo ""

    read -p "Proceed? [y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi

    log_info "Initializing Terraform..."
    cd terraform
    terraform init

    log_info "Applying profile: $PROFILE"
    terraform apply -auto-approve -var-file=profiles/${PROFILE}.tfvars

    log_info "Done! Use 'make status' to check resources"
}

main "$@"
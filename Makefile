.PHONY: help up destroy status apply check-env cluster-create cluster-delete info

SHELL := /bin/bash
TF := terraform
K3D_CLUSTER ?= dev
K3D_AGENTS ?= 1
KUBECONFIG_PATH := $(HOME)/.kubeconfig
export KUBECONFIG := $(KUBECONFIG_PATH)

help:
	@echo "Local Kubernetes Platform Bootstrap"
	@echo ""
	@echo "Usage:"
	@echo "  make up                  - Create cluster and apply terraform"
	@echo "  make destroy            - Destroy cluster and cleanup"
	@echo "  make status             - Show cluster and deployed components"
	@echo "  make apply              - Apply terraform changes only"
	@echo "  make check-env          - Verify prerequisites"
	@echo "  make cluster-create     - Create k3d cluster only"
	@echo "  make cluster-delete     - Delete k3d cluster only"
	@echo ""
	@echo "Variables:"
	@echo "  CLUSTER=$(K3D_CLUSTER)  - K3d cluster name"
	@echo "  PROFILE=minimal         - Profile to apply (minimal, auth, full)"
	@echo ""

check-env:
	@echo "Checking prerequisites..."
	@command -v docker >/dev/null 2>&1 || { echo "Error: docker not found"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "Error: terraform not found"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "Error: helm not found"; exit 1; }
	@command -v k3d >/dev/null 2>&1 || { echo "Error: k3d not found"; exit 1; }
	@echo "All prerequisites found."

cluster-create:
	@echo "Creating k3d cluster '$(K3D_CLUSTER)'..."
	@k3d cluster create $(K3D_CLUSTER) \
		--agents $(K3D_AGENTS) \
		-p "8080:80@loadbalancer" \
		-p "8443:443@loadbalancer" \
		--kubeconfig-update-default \
		--kubeconfig-switch-context \
		|| echo "Cluster may already exist"
	@k3d cluster list

cluster-delete:
	@echo "Deleting k3d cluster '$(K3D_CLUSTER)'..."
	@k3d cluster delete $(K3D_CLUSTER) || true
	@echo "Cluster deleted."

up: check-env
	@echo "=== Bringing up platform ==="
	@$(MAKE) cluster-create
	@sleep 5
	@$(MAKE) -C terraform init
	@$(MAKE) apply

apply:
	@echo "=== Applying Terraform ==="
	@cd terraform && $(TF) apply -auto-approve -var-file=profiles/$(PROFILE).tfvars || true

destroy:
	@echo "=== Destroying platform ==="
	@cd terraform && $(TF) destroy -auto-approve || true
	@$(MAKE) cluster-delete

status:
	@echo "=== Cluster Status ==="
	@k3d cluster list
	@echo ""
	@echo "=== Kubernetes Resources ==="
	@-kubectl cluster-info --request-timeout=5s 2>/dev/null || echo "No cluster connected"
	@kubectl get pods -A --request-timeout=5s 2>/dev/null || true

info:
	@echo "=== Platform Info ==="
	@echo "Cluster: $(K3D_CLUSTER)"
	@echo "Kubeconfig: $(KUBECONFIG)"
	@kubectl config current-context 2>/dev/null || true
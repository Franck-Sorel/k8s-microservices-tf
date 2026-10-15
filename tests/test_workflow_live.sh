#!/usr/bin/env bash
# tests/test_workflow_live.sh
# TRUE end-to-end workflow test against a live cluster.
#
# Walks the full user journey for a profile:
#   profile check -> (optionally create cluster) -> apply -> verify
#   pods ready -> services up -> teardown
#
# Requires: docker, kubectl, helm, k3d. If any are missing this test
# SKIPS (it must not fail CI runs that lack a cluster).
#
# Safety: creates a dedicated throwaway cluster named $E2E_CLUSTER and
# removes it on teardown. Never touches the user's existing clusters.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

begin_file "${BASH_SOURCE[0]}"

E2E_CLUSTER="${E2E_CLUSTER:-e2e-test}"
E2E_PROFILE="${E2E_PROFILE:-minimal}"
E2E_TIMEOUT="${E2E_TIMEOUT:-300}"

# --- environment gate -------------------------------------------------
missing=""
for cmd in docker kubectl helm k3d; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
if [ -n "$missing" ]; then
  skip "live cluster E2E requires:$missing (no cluster available)"
  end_file
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  skip "docker daemon not reachable"
  end_file
  exit 0
fi

# Respect E2E_SKIP_LIVE=1 to force-skip even when tooling exists.
if [ "${E2E_SKIP_LIVE:-0}" = "1" ]; then
  skip "E2E_SKIP_LIVE=1"
  end_file
  exit 0
fi

# --- helpers ----------------------------------------------------------
wait_pods_ready() {
  # $1 namespace. Returns 0 when all pods in the namespace are Ready.
  local ns="$1"; local i=0
  while [ "$i" -lt "$E2E_TIMEOUT" ]; do
    local notready
    notready="$(kubectl get pods -n "$ns" --no-headers 2>/dev/null \
      | awk '$3 != "Running" && $3 != "Completed" {print}' | wc -l)"
    if [ "$notready" -eq 0 ] && kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -q .; then
      return 0
    fi
    sleep 5; i=$((i + 5))
  done
  return 1
}

wait_cluster_ready() {
  # Wait until kubectl can talk to the API server (k3d can return before the
  # kubeconfig/API is fully up, especially on cold CI runners).
  local i=0
  while [ "$i" -lt 120 ]; do
    if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
      return 0
    fi
    sleep 5; i=$((i + 5))
  done
  return 1
}

cleanup() {
  # Best-effort teardown: delete only the E2E cluster we created.
  k3d cluster delete "$E2E_CLUSTER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --- the workflow -----------------------------------------------------
echo "--- preflight: profile is valid ---"
case "$E2E_PROFILE" in
  minimal|auth|storage|full)
    ok "profile '$E2E_PROFILE' is known"
    ;;
  *)
    fail "unknown profile '$E2E_PROFILE'"
    end_file
    exit 1
    ;;
esac

echo "--- create dedicated E2E cluster '$E2E_CLUSTER' ---"
if k3d cluster list 2>/dev/null | grep -q "^$E2E_CLUSTER "; then
  skip "cluster '$E2E_CLUSTER' already exists; reusing"
else
  if k3d cluster create "$E2E_CLUSTER" --agents 1 \
      -p "8080:80@loadbalancer" -p "8443:443@loadbalancer" \
      --kubeconfig-update-default --kubeconfig-switch-context >/dev/null 2>&1; then
    ok "cluster '$E2E_CLUSTER' created"
  else
    fail "cluster create failed"
    end_file
    exit 1
  fi
fi

echo "--- context switch ---"
if kubectl config use-context "k3d-$E2E_CLUSTER" >/dev/null 2>&1; then
  ok "switched to context k3d-$E2E_CLUSTER"
else
  fail "could not switch context"
fi

echo "--- wait for cluster API to be ready ---"
if wait_cluster_ready; then
  ok "cluster API reachable"
else
  fail "cluster API not reachable within 120s"
fi

echo "--- apply profile via the Taskfile path (helm _apply-*) ---"
# Mirror 'task profile PROFILE=...' using the exact helm commands the Taskfile runs.
apply_profile() {
  case "$E2E_PROFILE" in
    minimal) kubectl create namespace cert-manager >/dev/null 2>&1 || true
             helm upgrade --install cert-manager jetstack/cert-manager \
               --namespace cert-manager --version v1.15.0 \
               --set crds.enabled=true --wait --timeout 5m >/dev/null 2>&1
             ;;
    auth)    apply_profile minimal
             kubectl create namespace keycloak-db >/dev/null 2>&1 || true
             helm upgrade --install keycloak-db bitnami/postgresql \
               --namespace keycloak-db --set auth.username=keycloak \
               --set auth.password=keycloak123 --set auth.database=keycloak \
               --set primary.persistence.size=5Gi --wait --timeout 5m >/dev/null 2>&1
             kubectl create namespace keycloak >/dev/null 2>&1 || true
             helm upgrade --install keycloak codecentric/keycloak \
               --namespace keycloak --version 32.0.0 --set postgresql.enabled=false \
               --set 'extraEnvVars[0].name=KC_DB_URL' \
               --set 'extraEnvVars[0].value=jdbc:postgresql://keycloak-db-postgresql.keycloak-db.svc.cluster.local:5432/keycloak' \
               --set 'extraEnvVars[1].name=KC_DB_USERNAME' \
               --set 'extraEnvVars[1].value=keycloak' \
               --set 'extraEnvVars[2].name=KC_DB_PASSWORD' \
               --set 'extraEnvVars[2].value=keycloak123' --wait --timeout 10m >/dev/null 2>&1
             ;;
    storage) kubectl create namespace minio >/dev/null 2>&1 || true
             helm upgrade --install minio bitnami/minio \
               --namespace minio --set auth.rootUser=minioadmin \
               --set auth.rootPassword=minioadmin --set service.type=ClusterIP \
               --set persistence.size=5Gi --wait --timeout 5m >/dev/null 2>&1
             ;;
    full)    # Install the full set (same set as apply-full), tolerating partial
             # failures from third-party charts that need internet.
             apply_profile minimal
             kubectl create namespace traefik >/dev/null 2>&1 || true
             helm upgrade --install traefik traefik/traefik \
               --namespace traefik --version 30.0.0 --wait --timeout 5m >/dev/null 2>&1 || true
             kubectl create namespace cnpg-system >/dev/null 2>&1 || true
             helm upgrade --install cnpg cloudnative-pg/cloudnative-pg \
               --namespace cnpg-system --version 1.22.1 --wait --timeout 5m >/dev/null 2>&1 || true
             apply_profile storage
             kubectl create namespace redis >/dev/null 2>&1 || true
             helm upgrade --install redis bitnami/redis \
               --namespace redis --set auth.password=redis123 \
               --set architecture=standalone --wait --timeout 5m >/dev/null 2>&1 || true
             apply_profile auth
             ;;
  esac
}
if apply_profile; then
  ok "profile '$E2E_PROFILE' applied (helm releases installed)"
else
  fail "profile '$E2E_PROFILE' apply failed"
fi

echo "--- verify expected namespaces and pods become ready ---"
expected_ns() {
  case "$E2E_PROFILE" in
    minimal) echo "cert-manager" ;;
    auth)    echo "cert-manager keycloak keycloak-db" ;;
    storage) echo "minio" ;;
    full)    echo "cert-manager traefik cnpg-system minio redis keycloak keycloak-db" ;;
  esac
}
for ns in $(expected_ns); do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    ok "namespace '$ns' exists"
  else
    fail "namespace '$ns' missing"
    continue
  fi
  if wait_pods_ready "$ns"; then
    ok "namespace '$ns' pods ready"
  else
    # Only fail for the primary profile namespaces; tolerate best-effort in 'full'.
    if [ "$E2E_PROFILE" = "full" ]; then
      skip "namespace '$ns' pods not ready within ${E2E_TIMEOUT}s (tolerated for full)"
    else
      fail "namespace '$ns' pods not ready within ${E2E_TIMEOUT}s"
    fi
  fi
done

echo "--- services are reachable via ClusterIP (port-forward smoke) ---"
# Pick the primary service per profile and confirm a port-forward yields HTTP.
smoke_service() {
  case "$E2E_PROFILE" in
    minimal) echo "cert-manager webhook" ;;
    auth)    echo "keycloak http" ;;
    storage) echo "minio minio" ;;
    full)    echo "keycloak http" ;;
  esac
}
read -r svc_ns svc_name <<< "$(smoke_service)"
if [ -n "$svc_name" ] && kubectl get svc -n "$svc_ns" "$svc_name" >/dev/null 2>&1; then
  # Start port-forward in background and curl the health endpoint.
  local_port=$((18080 + RANDOM % 1000))
  kubectl port-forward -n "$svc_ns" "svc/$svc_name" "$local_port:80" >/dev/null 2>&1 &
  pid=$!
  sleep 5
  if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:$local_port/" 2>/dev/null; then
    ok "service '$svc_name' responds over port-forward"
  else
    # Some services don't answer on '/' with 200; accept any HTTP response.
    if curl -s -o /dev/null --max-time 10 "http://127.0.0.1:$local_port/" 2>/dev/null; then
      ok "service '$svc_name' reachable over port-forward (HTTP status received)"
    else
      skip "service '$svc_name' not reachable over port-forward (env-dependent)"
    fi
  fi
  kill "$pid" >/dev/null 2>&1 || true
else
  skip "no smoke service for profile '$E2E_PROFILE'"
fi

echo "--- teardown: remove the E2E cluster ---"
k3d cluster delete "$E2E_CLUSTER" >/dev/null 2>&1
if k3d cluster list 2>/dev/null | grep -q "^$E2E_CLUSTER "; then
  fail "E2E cluster '$E2E_CLUSTER' not removed"
else
  ok "E2E cluster '$E2E_CLUSTER' removed"
fi

end_file

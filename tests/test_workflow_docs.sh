#!/usr/bin/env bash
# tests/test_workflow_docs.sh
# End-to-end workflow tests for docs + cross-layer consistency:
# README, helmfile, values templates.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

begin_file "${BASH_SOURCE[0]}"

echo "--- README documents all components that exist in the registry ---"
# README has a Component Registry table. Every components/<name> should appear.
for dir in "$ROOT_DIR"/components/*/; do
  name="$(basename "$dir")"
  if grep -qi "| $name " "$ROOT_DIR/README.md"; then
    ok "README lists component '$name'"
  else
    fail "README does not mention component '$name'"
  fi
done

echo "--- values/*/values.yaml.gotmpl exist for helmfile releases that need them ---"
# helmfile.yaml references values/<release>/values.yaml.gotmpl for minio, keycloak-db, keycloak.
for rel in minio keycloak-db keycloak; do
  if [ -f "$ROOT_DIR/values/$rel/values.yaml.gotmpl" ]; then
    ok "values template exists for '$rel'"
  else
    fail "values template MISSING for '$rel'"
  fi
done

echo "--- manifests referenced by task bootstrap-keycloak exist ---"
if grep -q 'manifests/keycloak-realm.yaml' "$ROOT_DIR/Taskfile.yml"; then
  if [ -s "$ROOT_DIR/manifests/keycloak-realm.yaml" ]; then
    ok "manifests/keycloak-realm.yaml exists"
  else
    fail "manifests/keycloak-realm.yaml MISSING"
  fi
fi

echo "--- Taskfile shell snippets are balanced (basic brace/paren sanity) ---"
# Very light sanity: count quotes-ish. Skip heavy parsing; just ensure no obviously
# unclosed here-doc style issues by checking 'case' has matching 'esac'.
cases="$(grep -c '^\s*case ' "$ROOT_DIR/Taskfile.yml")"
esacs="$(grep -c '^\s*esac' "$ROOT_DIR/Taskfile.yml")"
if [ "$cases" -eq "$esacs" ]; then
  ok "Taskfile case/esac balanced ($cases)"
else
  fail "Taskfile case/esac unbalanced (case=$cases esac=$esacs)"
fi

echo "--- helmfile env conditions match component registry profile toggles ---"
# helmfile releases are gated by ENABLE_<NAME>; ensure each release has a condition.
for release in cert-manager cnpg minio keycloak-db keycloak librechat; do
  upper="$(echo "$release" | tr 'a-z-' 'A-Z_')"
  if grep -q "condition: ENABLE_${upper}" "$ROOT_DIR/helmfile.yaml"; then
    ok "helmfile release '$release' has condition ENABLE_${upper}"
  else
    fail "helmfile release '$release' missing condition ENABLE_${upper}"
  fi
done

echo "--- Makefile kubeconfig path matches the terraform provider ---"
# The Makefile exports KUBECONFIG that terraform/providers.tf must read the same
# file, otherwise kubectl/k3d and terraform would operate on different configs.
mk_kubeconfig="$(sed -n 's/^KUBECONFIG_PATH := \(.*\)$/\1/p' "$ROOT_DIR/Makefile" | head -1)"
tf_config_path="$(sed -n 's/^  config_path = "\(.*\)"$/\1/p' "$ROOT_DIR/terraform/providers.tf" | head -1)"
# Both reference $(HOME); compare the literal path names (ignoring the HOME prefix).
mk_base="${mk_kubeconfig##*\.kube}"
tf_base="${tf_config_path##*\.kube}"
if [ -n "$mk_base" ] && [ "$mk_base" = "$tf_base" ]; then
  ok "Makefile KUBECONFIG '$mk_kubeconfig' matches terraform provider '$tf_config_path'"
else
  fail "kubeconfig mismatch: Makefile='$mk_kubeconfig' terraform='$tf_config_path'"
fi

echo "--- Makefile has a default profile with a matching tfvars file ---"
mk_profile="$(sed -n 's/^PROFILE ?= \(.*\)$/\1/p' "$ROOT_DIR/Makefile" | head -1)"
if [ -n "$mk_profile" ] && [ -s "$ROOT_DIR/terraform/profiles/$mk_profile.tfvars" ]; then
  ok "Makefile default profile '$mk_profile' has tfvars"
else
  fail "Makefile default profile '$mk_profile' missing tfvars"
fi

end_file

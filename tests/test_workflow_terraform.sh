#!/usr/bin/env bash
# tests/test_workflow_terraform.sh
# End-to-end workflow tests for the Terraform IaC layer.
# Requires: terraform. No cluster needed (validate/fmt are offline).

set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

begin_file "${BASH_SOURCE[0]}"

if ! command -v terraform >/dev/null 2>&1; then
  skip "terraform not installed"
  end_file
  exit 0
fi

TF_DIR="$ROOT_DIR/terraform"
PROFILES_DIR="$TF_DIR/profiles"

echo "--- terraform formatting ---"
# fmt -check returns non-zero if any file is unformatted.
if terraform -chdir="$TF_DIR" fmt -check -recursive >/dev/null 2>&1; then
  ok "terraform fmt -check (all files formatted)"
else
  fail "terraform fmt -check (run 'terraform fmt -recursive')"
fi

echo "--- terraform init + validate ---"
if [ -d "$TF_DIR/.terraform" ] || terraform -chdir="$TF_DIR" init -backend=false -input=false >/dev/null 2>&1; then
  ok "terraform init -backend=false"
else
  fail "terraform init -backend=false"
fi

if terraform -chdir="$TF_DIR" validate >/dev/null 2>&1; then
  ok "terraform validate"
else
  out="$(terraform -chdir="$TF_DIR" validate 2>&1)"
  fail "terraform validate"
  printf '    %s\n' "$out" | sed 's/^/    /' | head -20
fi

echo "--- profile tfvars files exist for every documented profile ---"
# README documents: minimal, auth, storage, ai, full. Terraform uses minimal/auth/storage/full.
for prof in minimal auth storage full; do
  if [ -s "$PROFILES_DIR/$prof.tfvars" ]; then
    ok "profile '$prof' tfvars exists"
  else
    fail "profile '$prof' tfvars MISSING ($PROFILES_DIR/$prof.tfvars)"
  fi
done

echo "--- each tfvars is valid terraform HCL (parse via terraform console is heavy; check keys) ---"
for tf in "$PROFILES_DIR"/*.tfvars; do
  base="$(basename "$tf")"
  if grep -qE '^[a-z_]+\s*=' "$tf"; then
    ok "$base has variable assignments"
  else
    fail "$base has no variable assignments"
  fi
done

echo "--- every module referenced by main.tf exists ---"
# Extract module source paths from main.tf and check the directories exist.
# Capture into a variable so the loop runs in the current shell (not a subshell).
srcs="$(grep -oE 'source = "\./(modules/[^"]+)"' "$TF_DIR/main.tf" | sed -E 's/source = "\.\///;s/"$//' | sort -u)"
for src in $srcs; do
  if [ -f "$TF_DIR/$src/main.tf" ]; then
    ok "module '$src' exists"
  else
    fail "module '$src' MISSING"
  fi
done

echo "--- variable declarations match usages (no undeclared refs) ---"
# A reference like var.foo must have a matching variable "foo" block.
if ! command -v terraform >/dev/null 2>&1; then
  skip "terraform not installed for var check"
else
  terraform -chdir="$TF_DIR" validate >/dev/null 2>&1 \
    && ok "no undeclared variable references (validate passed)" \
    || fail "undeclared variable references (validate failed)"
fi

end_file

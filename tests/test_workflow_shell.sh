#!/usr/bin/env bash
# tests/test_workflow_shell.sh
# End-to-end workflow tests for the shell scripts (bootstrap + wizard).

set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

begin_file "${BASH_SOURCE[0]}"

echo "--- shell scripts are syntactically valid ---"
for script in "$ROOT_DIR/bootstrap.sh" "$ROOT_DIR/scripts/wizard.sh"; do
  if bash -n "$script" 2>/dev/null; then
    ok "bash -n $(basename "$script") (syntax ok)"
  else
    fail "bash -n $(basename "$script") (syntax error)"
  fi
done

echo "--- shellcheck (if installed) ---"
if command -v shellcheck >/dev/null 2>&1; then
  for script in "$ROOT_DIR/bootstrap.sh" "$ROOT_DIR/scripts/wizard.sh"; do
    if shellcheck "$script" >/dev/null 2>&1; then
      ok "shellcheck $(basename "$script") clean"
    else
      out="$(shellcheck "$script" 2>&1)"
      fail "shellcheck $(basename "$script")"
      printf '%s\n' "$out" | sed 's/^/    /' | head -15
    fi
  done
else
  skip "shellcheck not installed"
fi

echo "--- scripts are executable ---"
for script in "$ROOT_DIR/bootstrap.sh" "$ROOT_DIR/scripts/wizard.sh"; do
  if [ -x "$script" ]; then
    ok "$(basename "$script") is executable"
  else
    fail "$(basename "$script") not executable"
  fi
done

echo "--- bootstrap.sh references only real profile files ---"
if grep -q 'profiles/\${PROFILE}.tfvars' "$ROOT_DIR/bootstrap.sh"; then
  # For each profile referenced anywhere, the tfvars must exist.
  for prof in minimal auth storage full; do
    if [ -s "$ROOT_DIR/terraform/profiles/$prof.tfvars" ]; then
      ok "bootstrap.sh profile '$prof' resolves to existing tfvars"
    else
      fail "bootstrap.sh profile '$prof' tfvars missing"
    fi
  done
fi

end_file

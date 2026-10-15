#!/usr/bin/env bash
# tests/test_workflow_static.sh
# Offline "workflow consistency" tests.
# Verifies that the component registry (components/*/component.yaml),
# the state descriptor (platform.yaml), and the Taskfile all agree.
# No cluster required.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

begin_file "${BASH_SOURCE[0]}"

COMPONENTS="$ROOT_DIR/components"
TASKFILE="$ROOT_DIR/Taskfile.yml"
PLATFORM="$ROOT_DIR/platform.yaml"

# A component directory exists for every registry entry and vice-versa.
echo "--- Component registry files ---"
for yaml in "$COMPONENTS"/*/component.yaml; do
  name="$(basename "$(dirname "$yaml")")"
  assert_file_nonempty "component.yaml exists for '$name'" "$yaml"
done

echo "--- component.yaml install/remove/status tasks exist in Taskfile ---"
for yaml in "$COMPONENTS"/*/component.yaml; do
  name="$(basename "$(dirname "$yaml")")"
  for field in install_task remove_task status_task; do
    task="$(sed -n "s/^${field}: //p" "$yaml" | tr -d ' ')"
    [ -n "$task" ] || { fail "$name: missing $field"; continue; }
    if grep -qE "^  ${task}:" "$TASKFILE"; then
      ok "$name.$field -> task '$task' exists"
    else
      fail "$name.$field -> task '$task' NOT found in Taskfile"
    fi
  done
  # bootstrap_task is optional; validate only when declared.
  if grep -q '^bootstrap_task:' "$yaml"; then
    task="$(sed -n 's/^bootstrap_task: //p' "$yaml" | tr -d ' ')"
    if grep -qE "^  ${task}:" "$TASKFILE"; then
      ok "$name.bootstrap_task -> task '$task' exists"
    else
      fail "$name.bootstrap_task -> task '$task' NOT found in Taskfile"
    fi
  fi
done

echo "--- every component.yaml task reference resolves to a real Taskfile task ---"
# Collect every task the registry references and confirm it's defined.
for yaml in "$COMPONENTS"/*/component.yaml; do
  name="$(basename "$(dirname "$yaml")")"
  for task in $(grep -oE '^(_?[a-z]+_task|_?bootstrap_task): .*' "$yaml" | awk '{print $2}'); do
    if grep -qE "^  ${task}:" "$TASKFILE"; then
      ok "$name references '$task' (defined)"
    else
      fail "$name references '$task' (NOT defined)"
    fi
  done
done

echo "--- platform.yaml toggles have a matching component registry entry ---"
# Every component key under platform.yaml components: must have a components/<name>/.
# Capture into a variable first so the loop runs in the current shell (a pipe into
# `while read` would run in a subshell and drop the PASS/FAIL counters).
names="$(sed -n '/^components:/,/^[a-z]/p' "$PLATFORM" | grep -oE '^  [a-z0-9-]+:' | tr -d ' :' | sort -u)"
for name in $names; do
  if [ -d "$COMPONENTS/$name" ]; then
    ok "platform.yaml component '$name' has registry entry"
  else
    fail "platform.yaml component '$name' has NO registry entry"
  fi
done

echo "--- every registry component is either in platform.yaml or documented as opt-in ---"
# cert-manager is enabled_by_default; others are opt-in via platform.yaml. Not failing,
# just reporting coverage.
printf '  info: components registered: '
ls "$COMPONENTS" | tr '\n' ' '; echo

echo "--- keycloak dependency on keycloak-db is real ---"
if grep -q 'depends_on: \[keycloak-db\]' "$COMPONENTS/keycloak/component.yaml"; then
  if [ -d "$COMPONENTS/keycloak-db" ]; then
    ok "keycloak depends_on keycloak-db and registry entry exists"
  else
    fail "keycloak depends_on keycloak-db but no registry entry"
  fi
else
  skip "keycloak dependency declaration not in expected inline form"
fi

echo "--- no phantom component dependencies (all depends_on resolve) ---"
for yaml in "$COMPONENTS"/*/component.yaml; do
  name="$(basename "$(dirname "$yaml")")"
  deps="$(sed -n 's/^depends_on: \[\(.*\)\]$/\1/p' "$yaml")"
  if [ -n "$deps" ]; then
    IFS=',' read -ra arr <<< "$deps"
    for dep in "${arr[@]}"; do
      dep="$(echo "$dep" | tr -d ' ')"; [ -n "$dep" ] || continue
      if [ -d "$COMPONENTS/$dep" ]; then
        ok "$name depends_on '$dep' resolves"
      else
        fail "$name depends_on '$dep' is a PHANTOM component (no registry entry)"
      fi
    done
  fi
done

end_file

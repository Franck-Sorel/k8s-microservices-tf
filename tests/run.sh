#!/usr/bin/env bash
# tests/run.sh
# Entry point for the end-to-end workflow test suite.
#
# Usage:
#   tests/run.sh                      # run all tests
#   tests/run.sh static               # run one suite: static|terraform|shell|docs|live
#   E2E_PROFILE=full tests/run.sh     # run live E2E against the 'full' profile
#   E2E_SKIP_LIVE=1 tests/run.sh      # force-skip live E2E
#
# Exit code 0 = all passed (skips allowed), 1 = at least one failure.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUITES_DIR="$ROOT_DIR/tests"

SUITES=(
  test_workflow_static.sh
  test_workflow_terraform.sh
  test_workflow_shell.sh
  test_workflow_docs.sh
  test_workflow_live.sh
)

run_suite() {
  local file="$1"
  echo ""
  echo "================================================================"
  echo "  RUNNING: $file"
  echo "================================================================"
  bash "$SUITES_DIR/$file"
  return $?
}

overall=0
if [ "$#" -gt 0 ]; then
  # Run only the requested suite(s).
  for arg in "$@"; do
    run_suite "test_workflow_${arg}.sh" || overall=1
  done
else
  for suite in "${SUITES[@]}"; do
    run_suite "$suite" || overall=1
  done
fi

echo ""
echo "================================================================"
if [ "$overall" -eq 0 ]; then
  echo "  ALL WORKFLOW TESTS PASSED"
else
  echo "  SOME WORKFLOW TESTS FAILED"
fi
echo "================================================================"
exit "$overall"

#!/usr/bin/env bash
# tests/lib/common.sh
# Shared test harness: assertion helpers, counters, summary.
# Sources this file inside each test_*.sh script.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"

PASS=0
FAIL=0
SKIP=0
CURRENT_FILE=""

declare -a FAILURES=()

# --- setup -----------------------------------------------------------
begin_file() {
  CURRENT_FILE="$(basename "$1")"
  PASS=0; FAIL=0; SKIP=0; FAILURES=()
}

# --- assertions ------------------------------------------------------
ok() {
  PASS=$((PASS + 1))
  printf '  \033[32mPASS\033[0m %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILURES+=("$1")
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
}

skip() {
  SKIP=$((SKIP + 1))
  printf '  \033[33mSKIP\033[0m %s\n' "$1"
}

# Assert a command succeeds.
assert_cmd() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    fail "$desc"
  fi
}

# Assert a command succeeds and capture its output.
assert_cmd_out() {
  local desc="$1"; local out_var="$2"; shift 2
  local out
  if out="$("$@" 2>&1)"; then
    ok "$desc"
    printf -v "$out_var" '%s' "$out"
  else
    fail "$desc"
  fi
}

# Assert a file exists and is non-empty.
assert_file_nonempty() {
  local desc="$1"; local path="$2"
  if [ -s "$path" ]; then
    ok "$desc"
  else
    fail "$desc (missing/empty: $path)"
  fi
}

# Assert a grep pattern matches a file.
assert_grep() {
  local desc="$1"; local pattern="$2"; local file="$3"
  if grep -qE "$pattern" "$file"; then
    ok "$desc"
  else
    fail "$desc (no match for /$pattern/ in $file)"
  fi
}

# Assert a string is present in a value (no leading path).
assert_contains() {
  local desc="$1"; local needle="$2"; local haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    ok "$desc"
  else
    fail "$desc (missing '$needle')"
  fi
}

# --- summary ---------------------------------------------------------
end_file() {
  echo
  echo "  [$CURRENT_FILE] pass=$PASS fail=$FAIL skip=$SKIP"
  if [ "$FAIL" -gt 0 ]; then
    echo "  Failures:"
    for f in "${FAILURES[@]}"; do echo "    - $f"; done
  fi
  echo
  [ "$FAIL" -eq 0 ]
}

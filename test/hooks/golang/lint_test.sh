#!/usr/bin/env bash
#
# Smoke tests for hooks/golang/lint.sh.
#
# Every test runs the hook inside a scratch git repository, exactly the way
# the pre-commit framework would call it: with the paths of the files that
# are staged for commit.

set -euo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/hooks/golang/lint.sh"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

failures=0

# --- helpers -----------------------------------------------------------------

setup_repo() {
  local repo="$1"

  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name test
  (cd "$repo" && go mod init example.com/smoketest > /dev/null)
}

# run_hook <repo> <file>...: run the hook the way pre-commit would
run_hook() {
  local repo="$1"
  shift

  (cd "$repo" && "$HOOK" "$@")
}

# staged_blob <repo> <file>: print the staged version of a file
staged_blob() {
  local repo="$1"
  local file="$2"

  git -C "$repo" show ":$file"
}

run_test() {
  local name="$1"
  shift

  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name" >&2
    failures=$((failures + 1))
  fi
}

# --- test cases --------------------------------------------------------------

test_ignores_non_go_files() {
  local repo="$WORK_DIR/not-go"

  setup_repo "$repo" || return 1
  echo "hello" > "$repo/README.md"

  run_hook "$repo" README.md || return 1

  if ! git -C "$repo" diff --cached --quiet; then
    echo "no file should have been staged" >&2
    return 1
  fi
}

test_rewrites_interface_to_any() {
  local repo="$WORK_DIR/rewrite"

  setup_repo "$repo" || return 1
  printf 'package main\n\nfunc Empty() interface{} { return nil }\n' > "$repo/main.go"
  git -C "$repo" add main.go || return 1

  run_hook "$repo" main.go || return 1

  grep -q "func Empty() any" "$repo/main.go" || {
    echo "working tree copy should use any" >&2
    return 1
  }
  staged_blob "$repo" main.go | grep -q "func Empty() any" || {
    echo "rewrite should be staged" >&2
    return 1
  }
}

test_only_touches_passed_files() {
  local repo="$WORK_DIR/scope"

  setup_repo "$repo" || return 1
  printf 'package main\n\nfunc A() interface{} { return nil }\n' > "$repo/a.go"
  printf 'package main\n\nfunc B() interface{} { return nil }\n' > "$repo/b.go"
  git -C "$repo" add a.go b.go || return 1

  run_hook "$repo" a.go || return 1

  grep -q "func A() any" "$repo/a.go" || {
    echo "passed file should be rewritten" >&2
    return 1
  }
  grep -q "interface{}" "$repo/b.go" || {
    echo "unpassed file should be untouched" >&2
    return 1
  }
  if staged_blob "$repo" b.go | grep -q "any"; then
    echo "unpassed file should not be staged" >&2
    return 1
  fi
}

test_passes_clean_go_files() {
  local repo="$WORK_DIR/clean"
  local staged_before
  local staged_after

  setup_repo "$repo" || return 1
  printf 'package main\n\nfunc Clean() string { return "ok" }\n' > "$repo/main.go"
  git -C "$repo" add main.go || return 1
  staged_before="$(staged_blob "$repo" main.go)"

  run_hook "$repo" main.go || return 1

  staged_after="$(staged_blob "$repo" main.go)"
  if [[ "$staged_before" != "$staged_after" ]]; then
    echo "a clean file should not be modified" >&2
    return 1
  fi
}

test_blocks_long_functions() {
  local repo="$WORK_DIR/too-long"

  setup_repo "$repo" || return 1
  {
    echo "package main"
    echo
    echo "func Long() int {"
    for _ in $(seq 1 80); do echo "	_ = 1"; done
    echo "	return 0"
    echo "}"
  } > "$repo/main.go"
  git -C "$repo" add main.go || return 1

  if run_hook "$repo" main.go; then
    echo "a function longer than 75 lines should be rejected" >&2
    return 1
  fi
}

test_blocks_high_complexity() {
  local repo="$WORK_DIR/complex"

  setup_repo "$repo" || return 1
  {
    echo "package main"
    echo
    echo "func Complex(n int) string {"
    echo '	s := ""'
    for i in $(seq 1 16); do echo "	if n > $i { s += \"x\" }"; done
    echo '	return s'
    echo "}"
  } > "$repo/main.go"
  git -C "$repo" add main.go || return 1

  if run_hook "$repo" main.go; then
    echo "a function above complexity 15 should be rejected" >&2
    return 1
  fi
}

# --- runner ------------------------------------------------------------------

run_test "ignores non-Go files" test_ignores_non_go_files
run_test "rewrites interface{} to any and restages" test_rewrites_interface_to_any
run_test "leaves files outside the commit untouched" test_only_touches_passed_files
run_test "passes clean Go files unchanged" test_passes_clean_go_files
run_test "blocks functions longer than 75 lines" test_blocks_long_functions
run_test "blocks functions above cyclomatic complexity 15" test_blocks_high_complexity

if ((failures > 0)); then
  echo "$failures test(s) failed" >&2
  exit 1
fi

echo "all tests passed"

#!/usr/bin/env bash
#
# Hook: golang-lint
#
# Lint the Go files that are staged for commit. The pre-commit framework
# calls this script with the staged file paths; anything that is not an
# existing Go file is ignored.
#
# For every staged Go file we:
#   1. rewrite `interface{}` to `any` with gofmt, then re-stage the file so
#      the rewrite lands in the commit being created
#   2. run golangci-lint with the shared rules from config/golang/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GOLANGCI_LINT_CONFIG="$REPO_ROOT/config/golang/golangci-lint.yml"
GOFMT_REWRITE_RULE='interface{} -> any'

main() {
  local go_files=()
  local path

  for path in "$@"; do
    if [[ "$path" == *.go && -f "$path" ]]; then
      go_files+=("$path")
    fi
  done

  if ((${#go_files[@]} == 0)); then
    exit 0
  fi

  rewrite_interface_to_any "${go_files[@]}"
  run_golangci_lint "${go_files[@]}"
}

# Rewrite `interface{}` to `any` in the given files and stage the result.
# Only the files that actually change are rewritten and staged, so edits in
# other files are never swept into the commit.
rewrite_interface_to_any() {
  local formatted_files
  local file

  formatted_files="$(gofmt -l -r "$GOFMT_REWRITE_RULE" "$@")"

  if [[ -z "$formatted_files" ]]; then
    return 0
  fi

  while IFS= read -r file; do
    gofmt -w -r "$GOFMT_REWRITE_RULE" "$file"
    git add "$file"
    echo "golang-lint: gofmt fixed and staged $file"
  done <<< "$formatted_files"
}

# The shared config lives outside the checked repository, and golangci-lint
# would print issue paths relative to it (a chain of "../"). Absolute paths
# keep the output readable in every consumer repository.
run_golangci_lint() {
  golangci-lint run --config "$GOLANGCI_LINT_CONFIG" --path-mode abs "$@"
}

main "$@"

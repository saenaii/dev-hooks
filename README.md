# dev-hooks

Shared git hooks for any repository, consumed through the
[pre-commit](https://pre-commit.com) framework.

## Requirements

In every repository that uses these hooks:

- [pre-commit](https://pre-commit.com)
- the Go toolchain (for `gofmt`)
- [golangci-lint](https://golangci-lint.run) v2

## Usage

Add this repository to `.pre-commit-config.yaml` — a complete example lives
in [.pre-commit-config.yaml.example](.pre-commit-config.yaml.example):

```yaml
repos:
  - repo: https://github.com/saenai/dev-hooks
    rev: v0.1.0 # use a tag or commit
    hooks:
      - id: golang-lint
```

## Hooks

### golang-lint

Runs on the Go files staged for commit; other files are ignored.

1. Rewrites `interface{}` to `any` with `gofmt -w -r` (which also applies
   standard formatting), then stages the rewritten files so the change
   lands in the commit.
2. Runs `golangci-lint` on the same files with the shared rules from
   [config/golang/golangci-lint.yml](config/golang/golangci-lint.yml):
   - function length at most 75 lines (`funlen`)
   - cyclomatic complexity at most 15 (`gocyclo`)
   - plus the golangci-lint standard linters

Only the staged files are checked, so lint issues in the rest of the
repository never block a commit. One caveat: the rewrite stages the full
working-tree copy of a rewritten file, so unstaged edits in that same file
are included in the commit.

## Repository layout

    config/<language>/   shared linter configuration used by the hooks
    hooks/<language>/    hook entry points, one script per hook
    test/                smoke tests, mirroring the hooks/ layout

## Development

Run the smoke tests:

    bash test/hooks/golang/lint_test.sh

To add a hook for another language, add `hooks/<language>/<hook>.sh`,
register it in [.pre-commit-hooks.yaml](.pre-commit-hooks.yaml), and put its
shared configuration in `config/<language>/`.

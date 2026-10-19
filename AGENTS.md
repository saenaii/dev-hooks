# dev-hooks

Shared pre-commit hooks consumed by other repositories. User-facing docs
live in README.md.

## Release

Consumers pin `rev` in their `.pre-commit-config.yaml` to a **tag** of this
repository, so every user-facing change must end with a new tag — pushing
commits alone does not release anything.

After pushing changes to `master`:

1. Decide the bump: new hook or behavior change -> minor, fix or docs -> patch.
2. Tag the release: `git tag vX.Y.Z`
3. Push the tag explicitly: `git push origin vX.Y.Z`
   (`--follow-tags` only pushes annotated tags, so prefer an explicit push)
4. Update the pinned tag in `.pre-commit-config.yaml.example` to `vX.Y.Z`
   and push again.

Do not move or re-create a published tag.

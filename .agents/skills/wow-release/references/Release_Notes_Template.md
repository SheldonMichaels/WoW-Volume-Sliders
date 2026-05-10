# Release Notes Template

## 1. Public Changelog (`CHANGELOG.md`)

Keep this simple, non-technical, and user-facing.

```markdown
## [vX.Y.Z]

### Added
- [User-facing addition]

### Fixed
- [User-facing fix]
```

## 2. Internal Dev Changelog (`local_dev_assets/dev_changelog.md`)

Use this only when the private internal changelog exists and is relevant.

```markdown
## YYYY-MM-DD - vX.Y.Z Release ([Theme])

- **[Technical change]:** [Implementation detail, variable names, rationale, and lessons learned.]
  - **Why:** [Reason this approach was chosen and alternatives avoided.]
```

## 3. Pull Request Body

```markdown
## Summary
- [High-level technical summary]
- [Validation or migration note]

## Public Changelog
[Paste public changelog section]

Closes #[Issue Number]
```

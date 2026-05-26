# Contributing to Safe-Delete

Thank you for considering contributing to Safe-Delete! This document outlines the guidelines for contributing.

## Code of Conduct

By participating, you agree to maintain a respectful, inclusive environment. Be constructive, be kind.

## How to Contribute

### Bug Reports

Open an issue with:

- **Clear title** describing the bug
- **Steps to reproduce** — exact commands, file paths, risk scores
- **Expected vs actual behavior**
- **Platform** (OS, agent type, version)
- **Safe-delete mode** (on/off/watcher)
- **Relevant log output** from deletion-log.txt

### Feature Requests

Open an issue with:

- **Problem statement** — what gap are you filling?
- **Proposed solution** — how should safe-delete handle this?
- **Alternatives considered**
- **Is this for coding, deployment, or general use?**

### Documentation Improvements

PRs for docs are always welcome. Fix typos, add examples, clarify workflows.

### New Safeguards

Adding a new production guard (like `fn-ci-cd.md` or `fn-git-aware.md`):

1. Create the function file in `functions/fn-<name>.md`
2. Update `SKILL.md` — add to Functions table
3. Update `functions/INDEX.md`
4. Update `references/cheatsheet.md` if needed
5. Add test scenarios in `tests/test-scenarios.md`
6. Update `CHANGELOG.md`

## Development Setup

```bash
git clone https://github.com/YOUR_USER/safe-delete.git
cd safe-delete

# Validate structure
make validate

# Run tests
make test

# Full CI pipeline
make ci
```

## Pull Request Process

1. **Fork the repo** and create a feature branch
2. **Follow the file naming conventions**:
   - Functions: `fn-<name>.md`
   - Tests: `test-<name>.ps1` / `.sh`
   - Docs: PascalCase (`ARCHITECTURE.md`)
3. **Update CHANGELOG.md** with your changes
4. **Run `make ci`** and ensure all checks pass
5. **Open a PR** with a clear description of what changed and why
6. **Reference any related issues**

## Style Guidelines

### Markdown

- Use ATX headings (`# ## ###`)
- Use fenced code blocks with language tags
- Keep line length under 100 characters where possible
- One sentence per line in documentation

### PowerShell

- Use full cmdlet names (not aliases)
- Add comment-based help
- Use `$true`/`$false` instead of `$TRUE`/`$FALSE`
- Follow the existing patterns in `fn-*.md`

### Bash

- Use `#!/usr/bin/env bash` shebang
- Use `set -euo pipefail` in scripts
- Add `set -x` for debug scripts
- Follow existing patterns for `rm`, `mv`, `cp` equivalents

## Release Process

Releases follow [Semantic Versioning](https://semver.org/):

- **Major** — breaking changes to the protocol workflow
- **Minor** — new features, safeguards, or functions
- **Patch** — bug fixes, documentation, non-breaking refinements

```bash
# Create a release
# 1. Update version.json
# 2. Update CHANGELOG.md
# 3. Tag the release
git tag v2.0.0
git push origin v2.0.0
```

## Questions?

Open a discussion or issue. We're happy to help.

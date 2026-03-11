# LangChain Python — Code Contribution Guide

*Source: https://docs.langchain.com/oss/python/contributing/code*

## Getting Started

For bugfixes, the workflow involves reproducing the issue, forking to a personal GitHub account, cloning the repo, and setting up the environment using `uv`:

```bash
uv venv && source .venv/bin/activate
uv sync --all-groups
```

Contributors should create a feature branch, write failing tests first, implement the fix with minimal changes, verify all tests pass locally, and submit a PR with proper issue references.

## Key Contribution Requirements

### Backwards Compatibility
Breaking changes to public APIs are prohibited except for critical security fixes. Safe modifications include:
- Adding optional parameters
- New methods
- New modules without altering existing interfaces

### New Features
- Require design discussion via an issue before implementation
- Features should demonstrate clear need
- Include comprehensive tests and documentation
- Consider security implications

### Security Guidelines
- Input validation
- Avoid dangerous functions like `eval()`
- Proper error handling without exposing sensitive data
- Careful dependency review

## Development Standards

### Type Hints
All functions require complete type annotations.

### Documentation
Google-style docstrings are mandatory for public functions, containing:
- One-line summaries
- Parameter descriptions
- Return types
- Exceptions
- Minimal usage examples

### Code Style
Automated formatting and linting via Ruff:
- `make format` — auto-format code
- `make lint` — check for lint issues

## Testing Requirements

- **Unit tests** (in `tests/unit_tests/`): No network calls, mock external dependencies, cover all code paths
- **Integration tests** (in `tests/integration_tests/`): Test real external service integrations, skip gracefully if credentials unavailable

Run tests with: `make test` or `make integration_tests`

## Dependencies

Almost all new dependencies should be optional. Users must be able to import code without side effects even without optional dependencies installed. Hard dependencies require strong justification and maintainer approval.

## PR Submission

Follow the template, reference issues with closing keywords (e.g., `Fixes #123`), ensure CI checks pass, and address failures promptly. PRs appearing to be low-effort or AI-generated spam will be closed.

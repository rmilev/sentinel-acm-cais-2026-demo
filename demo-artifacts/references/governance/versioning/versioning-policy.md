# LangChain — Versioning & API Stability Policy

*Source: https://docs.langchain.com/oss/python/versioning*

## Semantic Versioning Format

Releases follow `MAJOR.MINOR.PATCH`:
- **Major**: Breaking API changes requiring code updates
- **Minor**: New backward-compatible features
- **Patch**: Bug fixes and minor improvements

## API Stability Tiers

### Stable APIs
Production-ready without special designation. Breaking changes only occur in major releases.

### Beta APIs
Feature-complete but may undergo refinements based on feedback. Safe for production with potential minor adjustments needed.

### Alpha APIs
Experimental and subject to significant modifications. Cautious production use recommended.

### Deprecated APIs
Marked for removal in future major versions with specified timelines. Require migration to recommended alternatives.

### Internal APIs
Identified through documentation or Python underscore convention (`_prefix`). Subject to change without notice.

**Exception**: Underscored methods without implementation are intended for subclass override and constitute public API.

## Release Cycles

- Minor and patch releases maintain backward compatibility
- Major releases may include architectural overhauls and removal of deprecated features
- Major releases are accompanied by migration guides and automated tools

## LTS Designations & Support Policy

LangChain and LangGraph 1.0 receive LTS status:

| Version | Status | Policy |
|---------|--------|--------|
| Latest major version | ACTIVE | Full support |
| Previous major version | MAINTENANCE | Security/critical fixes for 12 months |

- Version 1.0 remains ACTIVE until 2.0 release
- Upon 2.0 release, 1.0 enters MAINTENANCE mode for minimum 12 months
- Deep Agents (pre-1.0) follows active development cycle; LTS policies apply post-1.0

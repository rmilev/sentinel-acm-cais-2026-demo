# LangChain — Documentation Contribution Guide

*Source: https://docs.langchain.com/oss/python/contributing/documentation*

## Quick Start for Local Development

```bash
git clone https://github.com/langchain-ai/docs.git
cd docs
make install
make dev
```

This launches a development server at `http://localhost:3000` with hot reload.

### Prerequisites
- Python 3.13+
- uv package manager
- Node.js and npm
- Make and Git
- Optional: markdownlint-cli, Mintlify MDX VSCode extension

## Editing Workflow

- Quick edits: directly on GitHub for minor changes
- Local edits: edit files in the `src/` directory (the `build/` folder is auto-generated)
- All pull requests must pass quality checks: broken link detection, formatting, linting, markdown validation

Key commands: `make format`, `make lint`, `make test` before submission.

## Documentation Categories

1. **How-to guides**: Task-oriented instructions focusing on "how" with concrete examples
2. **Conceptual guides**: Explanations emphasizing "why," design decisions, and deeper understanding
3. **Reference**: Technical API documentation (Python and JavaScript/TypeScript)
4. **Tutorials**: Longer practical activities building progressive understanding

## Writing Standards

- Use Mintlify components (`<Note>`, `<Warning>`, `<Tip>`)
- Proper page frontmatter with YAML
- Structured formatting with tabs and accordions
- Content must appear in both Python and JavaScript/TypeScript using inline syntax markers

## Quality Standards

- Proper header structure and descriptive link text
- Avoid duplication across pages
- Link frequently to related content
- Use `@[]` syntax for consistent cross-references to API documentation
- All pull requests require links to approved issues or discussions

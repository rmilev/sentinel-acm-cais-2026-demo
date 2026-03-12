# Consolidated Architecture & Development Rules — LangChain Ecosystem

*Synthesized from: `langchain` CLAUDE.md, `langgraph` CLAUDE.md (AGENTS.md), `langchainjs` AGENTS.md*

---

## 1. Ecosystem Overview

The LangChain ecosystem consists of six primary repositories organized into two language tracks:

| Repository | Language | Purpose |
|-----------|----------|---------|
| `langchain` | Python | Core framework — LLM abstractions, chains, agents, integrations |
| `langgraph` | Python | Stateful multi-actor agent orchestration with checkpointing |
| `langchainjs` | TypeScript | JavaScript/TypeScript port of LangChain with full feature parity |
| `langgraphjs` | TypeScript | JS port of LangGraph |
| `deepagents` | Python | AI coding agent built on LangGraph |
| `deepagentsjs` | TypeScript | JS port of Deep Agents |

All repositories are **monorepos** with independently versioned packages.

---

## 2. Monorepo Architecture

### 2.1 LangChain Python — Layered Architecture

```
langchain/
├── libs/
│   ├── core/             # langchain-core — Base abstractions & interfaces
│   ├── langchain/        # langchain-classic (legacy, no new features)
│   ├── langchain_v1/     # Active langchain package
│   ├── partners/         # Third-party integrations (openai, anthropic, ollama, ...)
│   ├── text-splitters/   # Document chunking utilities
│   ├── standard-tests/   # Shared integration test suite
│   └── model-profiles/   # Model configuration profiles
├── .github/              # CI/CD workflows
└── .vscode/              # IDE settings
```

**Layer responsibilities:**
- **Core layer** (`langchain-core`): Base abstractions, interfaces, protocols. Users should not need to interact directly.
- **Implementation layer** (`langchain`): Concrete implementations and high-level utilities.
- **Integration layer** (`partners/`): Third-party service integrations. Some maintained in external repos (e.g., `langchain-google`, `langchain-aws`).
- **Testing layer** (`standard-tests/`): Standardized test suites for partner integrations.

### 2.2 LangGraph Python — Library Dependency Map

```
langgraph/
├── libs/
│   ├── checkpoint/           # Base checkpointer interfaces
│   ├── checkpoint-postgres/  # Postgres checkpoint implementation
│   ├── checkpoint-sqlite/    # SQLite checkpoint implementation
│   ├── cli/                  # Official LangGraph CLI
│   ├── langgraph/            # Core stateful agent framework
│   ├── prebuilt/             # High-level agent/tool APIs
│   ├── sdk-js/               # JS/TS SDK for REST API
│   └── sdk-py/               # Python SDK for Server API
```

**Dependency graph** (changes to a library impact all downstream dependents):
```
checkpoint → checkpoint-postgres, checkpoint-sqlite, prebuilt, langgraph
prebuilt → langgraph
sdk-py → langgraph, cli
sdk-js (standalone)
```

### 2.3 LangChain.js — Package Structure

```
langchainjs/
├── libs/
│   ├── langchain-core/           # @langchain/core — Base abstractions
│   ├── langchain/                # Main langchain package
│   ├── langchain-community/      # Community integrations
│   ├── langchain-textsplitters/  # Text splitting
│   ├── langchain-standard-tests/ # Standard test suite
│   └── providers/
│       ├── langchain-openai/     # @langchain/openai
│       ├── langchain-anthropic/  # @langchain/anthropic
│       └── langchain-*/          # Other first-party providers
├── internal/
│   ├── build/     # @langchain/build — Build utilities
│   ├── eslint/    # @langchain/eslint — Shared ESLint config
│   └── tsconfig/  # @langchain/tsconfig — Shared TS config
```

---

## 3. Core Abstractions (Shared Across Python & JS)

| Abstraction | Python Import | JS/TS Import | Purpose |
|------------|---------------|--------------|---------|
| Runnable | `langchain_core.runnables` | `@langchain/core/runnables` | Foundation interface: `invoke`, `stream`, `batch` |
| Messages | `langchain_core.messages` | `@langchain/core/messages` | HumanMessage, AIMessage, SystemMessage, ToolMessage |
| Tools | `langchain_core.tools` | `@langchain/core/tools` | StructuredTool, DynamicTool, tool() |
| Chat Models | `langchain_core.language_models` | `@langchain/core/language_models/chat_models` | BaseChatModel |
| Embeddings | `langchain_core.embeddings` | `@langchain/core/embeddings` | Embedding models |
| Retrievers | `langchain_core.retrievers` | `@langchain/core/retrievers` | BaseRetriever |
| Vector Stores | `langchain_core.vectorstores` | `@langchain/core/vectorstores` | VectorStore |

**Key principle**: All major components extend `Runnable`, providing a uniform interface.

---

## 4. Development Tooling

### 4.1 Python (langchain, langgraph)

| Tool | Purpose | Command |
|------|---------|---------|
| `uv` | Package management (replaces pip/poetry) | `uv sync --all-groups` |
| `ruff` | Linting + formatting | `make lint` / `make format` |
| `mypy` | Static type checking | `uv run --group lint mypy .` |
| `pytest` | Testing | `make test` |
| `make` | Task runner | See Makefile |

### 4.2 TypeScript (langchainjs)

| Tool | Purpose | Command |
|------|---------|---------|
| `pnpm` v10.14.0 | Package management (workspaces) | `pnpm install` |
| Turborepo | Build orchestration | `pnpm build` |
| ESLint | Linting | `pnpm --filter <pkg> lint` |
| Prettier | Formatting | `pnpm --filter <pkg> format` |
| Vitest | Testing | `pnpm --filter <pkg> test` |

---

## 5. Coding Standards

### 5.1 Universal Rules (Both Languages)

1. **Stable public interfaces are sacred** — Never make breaking changes to exported APIs. Add new optional parameters with defaults instead.
2. **Type safety is mandatory** — Complete type annotations on all functions (Python type hints, TypeScript strict mode).
3. **Every change needs tests** — Unit tests for all new features/bugfixes; integration tests for external services.
4. **No `eval()` or equivalent** — No `eval()`, `exec()`, `pickle` on user input (Python); no `eval()` in TypeScript.
5. **Google-style docstrings** (Python) / JSDoc (TypeScript) — Document all public APIs.
6. **Types in signatures, not docs** — Type info belongs in function signatures, not repeated in docstrings.
7. **Single backticks for inline code** — Do NOT use Sphinx-style double backticks (`` ``code`` ``). Use single backticks (`` `code` ``).
8. **Dependencies should be optional** — Users must be able to import code without side effects even without optional deps.

### 5.2 Python-Specific Rules

- **Error messages**: Use a `msg` variable for error messages, no bare `except:` clauses
- **Docstring format**: Google-style with Args, Returns, Raises sections
- **American English spelling** (e.g., "behavior" not "behaviour")
- **Default values**: Do NOT repeat defaults in docstrings unless there is post-processing
- **Complex functions**: Break up functions >20 lines into smaller focused functions

### 5.3 TypeScript-Specific Rules

| Rule | Enforcement | Rationale |
|------|------------|-----------|
| No `instanceof` | `no-instanceof/no-instanceof: error` | Use type guards; for messages use `AIMessage.isInstance()` |
| No `process.env` | `no-process-env: error` (except tests) | Use `getEnvironmentVariable()` utility |
| No floating promises | `@typescript-eslint/no-floating-promises: error` | Always await or handle promises |
| No explicit `any` | `@typescript-eslint/no-explicit-any: error` | Use proper types |
| Prefer template literals | `prefer-template: error` | Over string concatenation |
| File extensions required | `import/extensions: error` | Always `.js` for local ESM imports |
| Named exports only | Convention | No default exports |
| Target: ES2022 | `tsconfig` | Module: ESNext with bundler resolution |

### 5.4 File Naming Conventions

| Type | Python | TypeScript |
|------|--------|------------|
| Source files | `snake_case.py` | `snake_case.ts` |
| Unit tests | `tests/unit_tests/test_*.py` | `tests/*.test.ts` |
| Integration tests | `tests/integration_tests/test_*.py` | `tests/*.int.test.ts` |
| Type tests | N/A | `tests/*.test-d.ts` |
| Standard tests | N/A | `tests/*.standard.test.ts` |

---

## 6. Testing Requirements

### 6.1 Test Categories

| Category | Python | TypeScript | Rules |
|----------|--------|------------|-------|
| Unit tests | `tests/unit_tests/` | `*.test.ts` | No network calls, mock externals, deterministic |
| Integration tests | `tests/integration_tests/` | `*.int.test.ts` | Real service calls, skip gracefully without credentials |
| Standard tests | `libs/standard-tests/` | `@langchain/standard-tests` | Shared test suite for provider integrations |
| Type tests | `mypy` | `*.test-d.ts` | Static type verification |

### 6.2 Test Checklist

- [ ] Tests fail when the new logic is broken
- [ ] Happy path is covered
- [ ] Edge cases and error conditions are tested
- [ ] External dependencies are mocked (unit tests)
- [ ] Tests are deterministic (no flaky tests)
- [ ] File structure mirrors source code structure

### 6.3 Running Tests

**Python:**
```bash
make test                          # All unit tests
make integration_tests             # Integration tests
uv run --group test pytest tests/unit_tests/test_specific.py  # Specific file
TEST=path/to/test.py make test     # LangGraph specific file
```

**TypeScript:**
```bash
pnpm --filter <package> test                    # Unit tests
pnpm --filter <package> test:integration        # Integration tests
pnpm --filter <package> test:single <path>      # Specific file
```

---

## 7. Commit & PR Standards

### 7.1 Conventional Commits (Python repos)

All PR titles must follow Conventional Commits format with mandatory scope:

```
feat(langchain): add new chat completion feature
fix(core): resolve type hinting issue in vector store
chore(anthropic): update infrastructure dependencies
```

- **Lowercase** except proper nouns/named entities
- **Scope is always required** — even for the main package (e.g., `feat(langchain):` not `feat:`)
- Allowed types/scopes defined in `.github/workflows/pr_lint.yml`

### 7.2 PR Guidelines

- Link to pre-approved issues or discussions (unlinked PRs will be closed)
- Add disclaimer mentioning AI agent involvement (if applicable)
- Describe the "why" of changes, not just the "what"
- Highlight areas requiring careful review
- Ensure CI checks pass before requesting review
- One feature/fix per PR — keep changes focused

### 7.3 PR Checklist (TypeScript)

1. [ ] Run `pnpm lint` and fix issues
2. [ ] Run `pnpm format` to format code
3. [ ] Add/update unit tests
4. [ ] Add/update integration tests if applicable
5. [ ] Add/update type tests if changing public APIs
6. [ ] Update documentation if changing public APIs
7. [ ] Ensure no circular dependencies (`lint:dpdm`)

---

## 8. Security Guidelines

| Concern | Rule |
|---------|------|
| Code injection | No `eval()`, `exec()`, `pickle` on user-controlled input |
| Error handling | No bare `except:`; use `msg` variable for error messages |
| Data exposure | Proper exception handling without exposing sensitive data |
| Dependencies | Review carefully; prefer optional deps; MIT/permissive license required |
| Resource management | Ensure proper cleanup of file handles, connections, sockets, threads |
| Race conditions | Watch for in concurrent code paths |

---

## 9. Integration Development

### 9.1 Recommended Integration Types

| Priority | Component | Why |
|----------|-----------|-----|
| High | Chat Models | Most actively used |
| High | Tools/Toolkits | Enable agent capabilities |
| High | Retrievers | Essential for RAG |
| Medium | Embedding Models | Support vector operations |
| Medium | Vector Stores | Semantic search |
| Medium | Sandboxes | Safe code execution |

### 9.2 Integration Package Requirements

**Python:**
- Each package has own `pyproject.toml` and `uv.lock`
- Pass standard test suite from `libs/standard-tests/`
- Submit docs PR with templates

**TypeScript:**
```json
{
  "name": "@langchain/provider-name",
  "type": "module",
  "engines": { "node": ">=20" },
  "peerDependencies": { "@langchain/core": "^1.0.0" },
  "devDependencies": {
    "@langchain/core": "workspace:^",
    "@langchain/eslint": "workspace:*",
    "@langchain/standard-tests": "workspace:*",
    "@langchain/tsconfig": "workspace:*"
  }
}
```

Scaffold new integrations:
- **Python**: Follow `partners/` package structure
- **TypeScript**: `npx create-langchain-integration`

### 9.3 Streaming Support

All LLM-related components should support streaming when possible:

**Python**: Implement `_stream` or `_astream` methods on chat models.

**TypeScript**:
```typescript
async *_streamResponseChunks(
  messages: BaseMessage[],
  options: this["ParsedCallOptions"],
  runManager?: CallbackManagerForLLMRun
): AsyncGenerator<ChatGenerationChunk> {
  // Yield chunks as they arrive
}
```

---

## 10. CI/CD Infrastructure

### 10.1 Python CI

- **Release**: Triggered via `.github/workflows/_release.yml` with `working-directory` and `release-version` inputs
- **PR linting**: `.github/workflows/pr_lint.yml` — enforces Conventional Commits
- **Auto-labeling**: File-based, title-based, and package-based labeling workflows
- **Change detection**: `.github/workflows/check_diffs.yml` determines which packages to test

### 10.2 Adding a New Python Partner to CI

Update these files when adding a new partner package:
- `.github/ISSUE_TEMPLATE/*.yml` — Add to package dropdown
- `.github/dependabot.yml` — Add dependency update entry
- `.github/pr-file-labeler.yml` — Add file-to-label mapping
- `.github/workflows/_release.yml` — Add API key secrets if needed
- `.github/workflows/auto-label-by-package.yml` — Add package label
- `.github/workflows/check_diffs.yml` — Add to change detection
- `.github/workflows/integration_tests.yml` — Add integration test config
- `.github/workflows/pr_lint.yml` — Add to allowed scopes

---

## 11. Environment & Runtime Support

### Python
- `uv` for all package management
- Each package has own `pyproject.toml` and `uv.lock`
- Python 3.14 support being added (as of March 2026)

### TypeScript
- **Node.js**: 20.x, 22.x, 24.x
- **Other runtimes**: Cloudflare Workers, Vercel/Next.js, Supabase Edge Functions, Deno, Bun, Browser
- **Zod**: Supports both v3 and v4 (`import { z } from "zod/v3"`)

---

## 12. Versioning & API Stability

| Tier | Description | Breaking Change Policy |
|------|-------------|----------------------|
| **Stable** | Production-ready, no special designation | Major releases only |
| **Beta** | Feature-complete, may refine | Minor adjustments possible |
| **Alpha** | Experimental | Subject to significant changes |
| **Deprecated** | Marked for removal | Timeline specified, migration guides provided |
| **Internal** | `_prefix` or documented as internal | Change without notice |

**LTS**: LangChain 1.0 and LangGraph 1.0 are LTS. Upon 2.0 release, 1.0 enters 12-month maintenance.

---

## 13. Key Differences Between Python & TypeScript

| Aspect | Python | TypeScript |
|--------|--------|------------|
| Package manager | `uv` | `pnpm` v10.14.0 + Turborepo |
| Linter/formatter | `ruff` (both) | ESLint + Prettier (separate) |
| Type checking | `mypy` (separate tool) | Built into `tsc` (strict mode) |
| Test framework | `pytest` | Vitest |
| Module system | Standard Python | ESM (`.js` extensions required) |
| Commit format | Conventional Commits (enforced) | Similar PR guidelines |
| `instanceof` | Allowed | **Banned** — use `isInstance()` |
| Env vars | Standard `os.environ` | Must use `getEnvironmentVariable()` |

---

*This document was auto-generated from CLAUDE.md and AGENTS.md files across the LangChain ecosystem repositories (langchain, langgraph, langchainjs) on 2026-03-09.*

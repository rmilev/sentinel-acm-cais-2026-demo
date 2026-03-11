# ADR-014: Schema-Agnostic Validation for LLM Providers

**Status:** Accepted
**Date:** 2026-03-09
**Decision Makers:** @colifran, @jacoblee93 (langchainjs maintainers)

---

## Context

The LangChain.js ecosystem relied exclusively on Zod for schema validation in structured output (`withStructuredOutput()`) and tool definitions across all LLM provider integrations. This created several problems:

1. **Vendor lock-in**: Every consumer of the LangChain.js SDK was forced to depend on Zod, even if their application used a different validation library (Valibot, ArkType, TypeBox, Yup, etc.).
2. **Ecosystem fragmentation risk**: As alternative TypeScript validation libraries gained traction, LangChain's Zod-only approach became a friction point for adoption.
3. **Bundle size concerns**: Applications using lighter validation libraries were forced to ship Zod as an additional dependency solely for LangChain compatibility.
4. **Interoperability barriers**: Libraries and frameworks built on non-Zod validators could not cleanly integrate with LangChain's structured output pipeline without adapter layers.

The [Standard Schema specification](https://github.com/standard-schema/standard-schema) emerged as a community-driven interoperability standard that validation libraries can implement to ensure cross-library compatibility.

## Decision

**All LLM provider integrations in LangChain.js must support Standard Schema validation in addition to Zod.** Specifically:

1. **Core framework** (`@langchain/core`) exposes Standard Schema as a first-class schema type alongside Zod for `withStructuredOutput()`, `tool()`, and `bind_tools()`.
2. **Every provider package** (`@langchain/openai`, `@langchain/anthropic`, `@langchain/google-genai`, etc.) must accept any Standard Schema-compliant validator — not just Zod.
3. **Agent framework** (`@langchain/langgraph`) tool definitions must support Standard Schema validators.
4. **Zod remains supported** but is no longer the only option. Zod v3 and v4 both remain fully supported.

## Scope of Change

The following 15+ provider packages were updated:

| Package |
|---------|
| `@langchain/core` (foundation) |
| `@langchain/openai` |
| `@langchain/anthropic` |
| `@langchain/google-genai` |
| `@langchain/google-vertexai` |
| `@langchain/aws` (Bedrock) |
| `@langchain/mistralai` |
| `@langchain/xai` |
| `@langchain/deepseek` |
| `@langchain/groq` |
| `@langchain/cerebras` |
| `@langchain/openrouter` |
| `@langchain/ollama` |
| `@langchain/langgraph` (agents) |

**Primary author:** @colifran

## Compliance With Coding Standards

This decision was evaluated against the consolidated development rules. The core framework implementation was validated in detail on 2026-03-09.

| Governance Dimension | Result | Notes |
|---------------------|--------|-------|
| **1. Conventional Commits & PR Title** | **PASS** | `feat(core): implement standard schema support for structured output` — correct format with scope |
| **2. Issue Linkage** | **UNCLEAR** | No closing keywords in PR body. Maintainer-driven initiative approved by core team member. |
| **3. Backwards Compatibility** (Sec. 5.1 #1, Sec. 12) | **PASS** | Additive change — new overloads added to `withStructuredOutput()`. Existing Zod-based code paths untouched. Function signatures widened via union, not changed. |
| **4. Type Safety** (Sec. 5.1 #2) | **PASS** | `SerializableSchema<Input, Output>` generic intersection type. `isStandardSchema()`, `isStandardJsonSchema()`, `isSerializableSchema()` are structural type guards. `RunOutput` generic carried through all overloads. |
| **5. Code Quality & Design** (Sec. 5.3) | **PASS** | Named exports only. No `instanceof` (structural type guards). No `process.env`. `.js` extensions on all imports. Refactored into composable helpers (`createContentParser`, `createFunctionCallingParser`, `assembleStructuredOutputPipeline`) reducing `withStructuredOutput` complexity. |
| **6. Test Coverage** (Sec. 6) | **PASS** | 503 lines of tests across 4 files. Covers: type guards (3 functions), `StandardSchemaOutputParser` (valid JSON, markdown-fenced, async, failure, invalid), `createContentParser` (Zod v3, v4, Standard Schema, plain JSON), `createFunctionCallingParser` (Zod v3, v4, Standard Schema, plain JSON, custom class), end-to-end `withStructuredOutput`. |
| **7. Security** (Sec. 8) | **PASS** | No `eval()`, no deserialization of arbitrary code. Validation via schema's own `["~standard"].validate()`. Error messages include LLM output for debugging, no credentials or internal state exposed. |
| **8. Documentation** (Sec. 5.1 #5) | **PARTIAL** | JSDoc present on helper functions. `SerializableSchema` type has brief comment. `getFormatInstructions()` returns empty string — known limitation since Standard Schema has no standard format instruction generation. |
| **9. Dependencies** (Sec. 5.1 #8) | **PASS*** | `@standard-schema/spec` added as hard dependency. However, this is a type-only package (~1KB, zero runtime code), so practical impact is negligible. |
| **10. Changeset / Versioning** (Sec. 12) | **PASS*** | Changeset present. Tagged as `patch` — defensible since purely additive with zero breaking changes, though `minor` would also be appropriate for new exports. |

## Consequences

### Positive

- **Eliminates Zod lock-in**: Applications can use Valibot, ArkType, TypeBox, Yup, or any Standard Schema-compliant library.
- **Reduces bundle size**: Teams using lighter validators no longer carry Zod as a transitive dependency.
- **Improves ecosystem interoperability**: Libraries built on non-Zod validators can integrate with LangChain without adapters.
- **Future-proof**: New validation libraries that implement Standard Schema will automatically work with LangChain.
- **Backwards compatible**: Zero migration effort for existing Zod-based code.
- **Code quality improvement**: Shared helpers (`createContentParser`, `createFunctionCallingParser`, `assembleStructuredOutputPipeline`) reduce duplication across provider implementations.

### Negative / Risks

- **Maintenance surface area**: Each provider must now test against multiple schema types, increasing CI matrix complexity.
- **Standard Schema spec stability**: The specification is community-driven and pre-1.0. Breaking changes to the spec could require coordinated updates across all 15+ packages.
- **Documentation burden**: Docs, examples, and tutorials must be updated to show both Zod and Standard Schema patterns, increasing content maintenance.
- **Cognitive load for contributors**: New provider contributors must understand Standard Schema in addition to Zod when implementing `withStructuredOutput()`.
- **Format instructions gap**: `StandardSchemaOutputParser.getFormatInstructions()` returns empty string — providers relying on format instructions for JSON mode prompting will not benefit from Standard Schema schemas.

### Neutral

- **Python ecosystem**: This ADR applies to LangChain.js only. The Python ecosystem does not have an equivalent multi-validator problem (Pydantic is the de facto standard). No action required on the Python side.

## Alternatives Considered

### 1. Stay Zod-only
**Rejected.** Zod lock-in was an increasingly cited friction point. Other major TypeScript frameworks (tRPC, Hono) were adopting Standard Schema, making LangChain an outlier.

### 2. Build a custom adapter layer
**Rejected.** Creating a LangChain-specific schema abstraction would add maintenance burden and not benefit from the broader ecosystem convergence around Standard Schema.

### 3. Support only Zod v3 + v4
**Rejected.** This solves the Zod version compatibility issue but not the fundamental library lock-in problem.

## Enforcement

- **New provider integrations** must pass Standard Schema validation tests as part of the `@langchain/standard-tests` suite.
- **Existing providers** have been updated in this initiative. Any regressions in Standard Schema support will be caught by CI.
- **PR reviews** should verify that `withStructuredOutput()` accepts both Zod and Standard Schema in any provider that implements structured output.
- **Core framework changes** should follow Conventional Commits with scope (Sec. 7.1) and include issue linkage (Sec. 7.2).

## Governance Evaluation History

| Date | Scope | Evaluator | Result |
|------|-------|-----------|--------|
| 2026-03-09 | Core framework implementation | Architecture Governance | 8/10 PASS, 1 PARTIAL (docs), 1 UNCLEAR (issue linkage) |
| 2026-03-09 | ADR-014 Compliance Validation | Architecture Governance | 14/15 packages compliant. 2 gaps: LangGraph agents pending, no issue linkage across 17 PRs. See details below. |

### ADR-014 Compliance Validation (2026-03-09)

**PRs evaluated:** 17 merged PRs (#10204–#10260) by @colifran
**Scope:** Core framework + 14 provider packages

#### Scope Coverage

| Required Package | PR | Status |
|-----------------|-----|--------|
| `@langchain/core` (foundation) | #10204, #10252, #10256 | COMPLIANT |
| `@langchain/openai` | #10205 | COMPLIANT |
| `@langchain/anthropic` | #10207 | COMPLIANT |
| `@langchain/google-genai` | #10209 | COMPLIANT |
| `@langchain/google-vertexai` | #10208 (google-common) | COMPLIANT |
| `@langchain/aws` (Bedrock) | #10213 | COMPLIANT |
| `@langchain/mistralai` | #10211 | COMPLIANT |
| `@langchain/xai` | #10216 | COMPLIANT |
| `@langchain/deepseek` | #10206 | COMPLIANT |
| `@langchain/groq` | #10210 | COMPLIANT |
| `@langchain/cerebras` | #10214 | COMPLIANT |
| `@langchain/openrouter` | #10215 | COMPLIANT |
| `@langchain/ollama` | #10212 | COMPLIANT |
| `@langchain/google` (unified) | #10240 | COMPLIANT |
| `@langchain/langgraph` (agents) | — | NOT YET EVALUATED |

#### Governance Dimension Compliance

| Dimension | Core #10204 | Provider PRs (sampled) | Notes |
|-----------|:-----------:|:----------------------:|-------|
| Conventional Commits | PASS | PASS | All follow `feat(scope): implement standard schema support for structured output` |
| Issue Linkage | UNCLEAR | UNCLEAR | No closing keywords across any of the 17 PRs |
| Backwards Compatibility | PASS | PASS | Additive overloads only; existing Zod paths unchanged |
| Type Safety | PASS | PASS | `SerializableSchema<RunOutput>` generics propagated through all overloads |
| Code Quality | PASS | PASS | Provider PRs leverage shared helpers from core |
| Test Coverage | PASS | PASS | Each provider PR includes tests. Core has 503 lines across 4 test files |
| Security | PASS | PASS | No eval, no arbitrary deserialization |
| Documentation | PARTIAL | PARTIAL | JSDoc on helpers; `getFormatInstructions()` returns empty string (known limitation) |
| Changesets | PASS | PASS | Every PR includes a `.changeset/` file |

#### Enforcement Criteria

| Enforcement Requirement | Status | Evidence |
|------------------------|--------|----------|
| New providers must pass Standard Schema tests in `@langchain/standard-tests` | NEEDS VERIFICATION | Standard test suite update not found in PR set |
| Existing providers updated | PASS | 14 providers confirmed updated |
| PR reviews verify both Zod and Standard Schema acceptance | PASS | All PRs describe dual-path support |
| Core changes use Conventional Commits with scope | PASS | `feat(core):`, `feat(openai):`, etc. |
| Core changes include issue linkage | FAIL | No issue linkage across the initiative |

#### Gaps

| # | Severity | Finding |
|---|----------|---------|
| 1 | Medium | `@langchain/langgraph` (agents) not yet updated — ADR explicitly requires it |
| 2 | Low | No issue linkage across any of the 17 PRs |
| 3 | Low | `getFormatInstructions()` returns empty string for Standard Schema — acknowledged as known limitation |
| 4 | Info | `@langchain/standard-tests` suite update not visible in this PR set |
| 5 | Info | PR #10178 (umbrella PR) still OPEN despite individual provider PRs being merged |

**Overall:** Substantially compliant. Actionable items: ship LangGraph agent framework support; close umbrella PR #10178.

## References

- [Standard Schema specification](https://github.com/standard-schema/standard-schema)
- LangChain.js coding standards: Sec. 5.3 of CONSOLIDATED_ARCHITECTURE_AND_DEV_RULES.md
- Versioning policy: Sec. 12 (API stability tiers)
- Contributing guide: langchainjs-INTEGRATIONS.md

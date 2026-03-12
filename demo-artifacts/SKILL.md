---
name: sentinel
description: Provides architectural governance through visibility into engineering development initiatives, technical design documentation, upstream open-source governance rules, and Architecture Decision Records (ADRs). Track weekly development initiatives across services, compare activity across time periods, explore technical design documents by team/service/technology, analyze design documentation coverage to identify gaps, reference LangChain ecosystem coding standards and contributing guidelines, evaluate development initiatives against governance standards, and manage ADRs that capture key architectural decisions. Use when the user asks about: (1) What teams are working on or development initiative activity, (2) Comparing activity across weeks or tracking service progress over time, (3) Finding or exploring technical design documents (TDDs) by various dimensions, (4) Which development initiatives lack design documentation or coverage analysis, (5) LangChain/LangGraph coding standards, dev rules, contributing guidelines, or versioning policy, (6) Evaluating a development initiative or PR against coding standards and API design guidelines, (7) Creating, reading, or listing Architecture Decision Records (ADRs).
---

# Architecture Visibility - Development Initiatives, Design Documentation & Governance

Provide visibility into weekly development initiative work across engineering teams, technical design documentation, upstream open-source governance rules, and Architecture Decision Records (ADRs). Connect development initiative activity with technical design documents to understand what teams are building, how it's architected, and whether proper design documentation exists. Reference LangChain ecosystem coding standards, contributing guidelines, and versioning policy to ensure development initiatives align with established governance. Evaluate specific development initiatives or PRs against coding standards to identify compliance gaps. Manage ADRs that capture and formalize key architectural decisions arising from development initiatives.

## When Skill is Invoked Directly

On direct invocation (e.g., "use architecture-visibility skill" or "use arch visibility") without a specific task:

1. Present each workflow from the "Workflows" section below as a numbered list
2. Include 2-4 example queries under each workflow that would trigger it
3. Use actual questions users would ask (e.g., "What are teams working on?", "Give me a development initiative overview", "Show me the last 4 weeks for commerce-ai")
4. Ask: "What would you like to explore?"

Available workflows:
- **Development Initiative Overview Reporting (DEFAULT)** - High-level development initiative summary with multi-week context for better grouping
- **Quick Service Lookup** - Focused lookup for a specific service or repository
- **Comparing Development Initiatives Across Weeks** - Week-over-week comparison and trend analysis
- **Exploring Development Initiative History** - Track a single service's progress over multiple weeks
- **Exploring Technical Design Documents** - Search and filter TDDs by team, service, technology
- **Design Document Coverage Analysis** - Identify development initiatives that may need TDDs
- **Governance & Dev Rules Reference** - Look up LangChain ecosystem coding standards, contributing guidelines, and versioning policy
- **Governance Evaluation** - Evaluate a development initiative or PR against coding standards and API design guidelines
- **Architecture Decision Records (ADRs)** - Create, list, or review ADRs that capture key architectural decisions

**Note**: All development initiative workflows load 1 week of historical context before answering. This helps identify multi-week work streams while conserving context window.

This provides a menu of capabilities with concrete examples while avoiding duplication with the detailed workflow instructions below.

### Example Queries by Workflow

When presenting the menu, include examples like these:

1. **Development Initiative Overview Reporting** — "What are teams working on?", "Give me a development initiative overview", "Summarize this week's development initiatives"
2. **Quick Service Lookup** — "What is commerce-ai working on?", "Show me ta-hotel-service activity"
3. **Comparing Development Initiatives Across Weeks** — "How does this week compare to last week?", "What changed week-over-week?"
4. **Exploring Development Initiative History** — "Show me the last 4 weeks for commerce-ai", "Track hotel-service progress"
5. **Exploring Technical Design Documents** — "Show me recent TDDs", "Find TDDs by the Payments team", "What AI-related designs exist?"
6. **Design Document Coverage Analysis** — "Which development initiatives lack design docs?", "Check design coverage for this week"
7. **Governance & Dev Rules Reference** — "What are the LangChain Python coding standards?", "Show me the TypeScript ESLint rules", "What's the versioning policy?", "How do I contribute an integration?"
8. **Governance Evaluation** — "Evaluate the GPT-5 PRs against coding standards", "Does this initiative comply with API design guidelines?", "Check the latest PR against governance rules"
9. **Architecture Decision Records** — "Write an ADR for the Standard Schema decision", "List all ADRs", "Show me the latest ADR", "Create an ADR for the streaming V2 migration"

## Data Source

- **S3 Bucket**: `features-summary-temp`
- **Structure**: Files are organized by date (YYYY-MM-DD format)
- **Format**: Each file represents a service and contains development initiative summaries from PR activity
- **Filtering**: Files with only "No recent changes" messages are automatically excluded

For AWS configuration details, see `<skill-base-dir>/references/setup/aws_configuration.md`.

## Default Behavior: Always Load Historical Context

**IMPORTANT**: For ANY query about development initiative activity (including "what are teams working on?", "give me an overview", etc.), load 1 week of historical context BEFORE loading the current week.

**Why**: Development initiatives often span multiple weeks. Historical context helps identify continuing work streams and team focus areas while conserving context window.

**Mandatory First Steps for All Development Initiative Queries**:
1. Run `<skill-base-dir>/scripts/aggregate_feature_development.sh -1` (1 week back)
2. Run `<skill-base-dir>/scripts/aggregate_feature_development.sh` (current week)
3. Read both files before answering

Only skip historical context when the user explicitly asks for a single week (e.g., "just show me this week" or "only current week").

## Workflows

### Development Initiative Overview Reporting (DEFAULT)

**This is the default workflow for general queries about development initiative activity. Historical context loading is MANDATORY.**

Trigger patterns: "What are teams working on?", "What development initiatives are teams working on?", "Give me a development initiative overview", "Summarize development initiatives", "Show me this week's development initiatives"

This workflow produces a high-level development initiative overview for a **single target week**, using historical context from previous weeks to better identify and group development initiatives. Development initiatives often span multiple PRs and multiple weeks.

**Key Principle**: Report ONLY on the target week's development initiatives. Use historical weeks as CONTEXT to identify continuing work streams—not to report on.

#### Presentation Format — ALWAYS USE TABLES

When presenting development initiative summaries to the user, **always use table format** for initiative listings. Structure each domain section with a markdown table:

```
| Development Initiative | PRs | Authors | Notes |
|------------------------|-----|---------|-------|
| Initiative name | repo #PR | @author | Brief description |
```

Include a **Summary Statistics** table at the end:

```
| Domain | Initiatives | Key Focus Areas |
|--------|-------------|-----------------|
| Domain name | count | Notable work streams |
```

Do NOT use bullet-point or prose-only summaries for initiative listings. Tables provide consistent, scannable formatting across all development initiative workflows (overview, service lookup, comparisons, history).

#### Step 0: Check for Existing Report — ALWAYS DO THIS FIRST

Before doing any work, check if `<working-dir>/aggregated_features_summary_YYYY-MM-DD.md` already exists for the target week:
1. Check if the file exists (e.g., `ls <working-dir>/aggregated_features_summary_2026-03-09.md`)
2. **If it exists**: Read it and present the contents to the user using table format. Do NOT regenerate the report. Skip Steps 1-4 entirely.
3. **If it does not exist**: Proceed with Steps 1-4 below to generate a new report.
4. **To force regeneration**: The user must explicitly ask (e.g., "regenerate the report", "refresh the overview", "rebuild the summary").

#### Step 1: Load Historical Context (1 previous week) — MANDATORY

1. Run `<skill-base-dir>/scripts/aggregate_feature_development.sh -1` (1 week back)
2. Read the file to identify:
   - Recurring work streams (development initiatives appearing across multiple weeks)
   - Team patterns and focus areas
   - Multi-week initiatives in progress

#### Step 2: Load Target Week

1. Run `<skill-base-dir>/scripts/aggregate_feature_development.sh` (current/target week)
2. Read the generated file

#### Step 3: Identify Multi-Week Work Streams

Cross-reference the target week with historical context to identify:
- **Continuing initiatives**: Development initiatives that build on work from previous weeks
- **New work**: Development initiatives appearing for the first time
- **Completed work**: Work streams that finished in earlier weeks

Examples of multi-week work streams:
- AI SDK migrations (same library upgrades across multiple services/weeks)
- Search enhancements (incremental improvements to same development initiative)
- Database migrations (same pattern applied to different services)
- New product launches (onboarding, notifications, branding across weeks)

#### Step 4: Generate Development Initiative Overview Report

Structure the report by **domain** (not by repository):

```
# Development Initiative Overview — Week of [DATE]
*Historical context from [dates] used to identify continuing work streams*

## [DOMAIN] (e.g., Flights, Hotels, Expense, Platform)

### [Development Initiative Category]
*[Note if continuing multi-week initiative]*

| Development Initiative | PRs | Authors | Notes |
|------------------------|-----|---------|-------|
| Development initiative name | repo #PR | @author | Brief description |

## Summary Statistics

| Domain | Development Initiatives This Week | Continuing Work Streams |
|--------|----------------------------------|------------------------|
| Domain | N | Work stream name |
```

#### Reporting Guidelines

1. **Report only target week development initiatives** - Do not include metrics or development initiatives from historical weeks
2. **Group by domain, not repository** - Flights, Hotels, Expense/Admin, Platform/Infrastructure, Growth, Agent Tooling
3. **Note continuing work streams** - Mark development initiatives that are part of multi-week initiatives
4. **Use tables for clarity** - Development initiative name, PRs, Authors, Notes columns
5. **Distinguish development initiatives from maintenance** - Exclude pure dependency upgrades, refactoring, and bug fixes unless they add new capabilities
6. **Include summary statistics** - Count development initiatives by domain, list active multi-week work streams

#### Output Locations

- **Raw PR summaries** (from script): `<skill-base-dir>/references/feature-development-summaries/feature_development_summary_YYYY-MM-DD.md`
- **Development initiative overview reports** (generated by this workflow): `<working-dir>/aggregated_features_summary_YYYY-MM-DD.md`

When asked for a development initiative overview, save the report to `aggregated_features_summary_YYYY-MM-DD.md` in the working directory (not in the skill's references folder).

### Quick Service Lookup

Trigger patterns: "What is commerce-ai working on?", "Show me ta-hotel-service", "What's happening in [specific-repo]?"

Use this workflow when the user asks about a **specific service or repository**.

1. **Load historical context and current week** (as per Default Behavior above):
   - Run `<skill-base-dir>/scripts/aggregate_feature_development.sh -1` (1 week back)
   - Run `<skill-base-dir>/scripts/aggregate_feature_development.sh` (current week)
2. **Read both markdown files**
3. **Search for the specific service** - Find the "## [service-name]" section in each week's markdown
4. **Provide focused answer** - Summarize that service's activity, noting any multi-week patterns or continuing work streams

Example: For "What is commerce-ai working on?", search for the "## commerce-ai" section across both weeks to identify current work and ongoing initiatives.

### Comparing Development Initiatives Across Weeks

Trigger patterns: "How does this week compare to last week?", "What changed?"

1. **Load current week** - Run `<skill-base-dir>/scripts/aggregate_feature_development.sh`
2. **Load previous week** - Run `<skill-base-dir>/scripts/aggregate_feature_development.sh -1`
3. **Read both files** - Load both markdown files to compare content
4. **Identify changes**:
   - Which repos are newly active or went quiet?
   - Which teams increased/decreased development initiative activity?
   - What new themes or development initiatives emerged?
   - What work completed or stalled?
5. **Summarize trends** - Provide comparative analysis highlighting key differences

### Exploring Development Initiative History for a Single Service

Trigger patterns: "Show me the last 4 weeks for commerce-ai", "Track hotel-service progress"

1. **Identify the service name** - Extract from user's request (e.g., "commerce-ai", "ta-hotel-service")
2. **Run fetch script** - `<skill-base-dir>/scripts/fetch_feature_development_history.sh <service-name> <weeks-back>`
   - Example: `fetch_feature_development_history.sh commerce-ai 4`
3. **Check script output** - Note which weeks were successfully downloaded
4. **Read each file** - Load each `service-name-YYYY-MM-DD.txt` file in chronological order (oldest to newest)
5. **Track evolution** - Analyze how the service's development initiatives progressed:
   - Which development initiatives progressed or completed?
   - What new work started?
   - Are there recurring themes or patterns?
   - What's the velocity/activity trend?
6. **Summarize timeline** - Present chronological narrative showing the service's development initiative trajectory

Example: For 4 weeks of commerce-ai history, the script downloads `commerce-ai-2025-11-11.txt`, `commerce-ai-2025-11-18.txt`, `commerce-ai-2025-11-25.txt`, `commerce-ai-2025-12-02.txt`.

### Exploring Technical Design Documents

Trigger patterns: "Show me recent TDDs", "What AI-related designs exist?", "Find TDDs by Team X"

1. **Update TDD index** - Always run incremental fetch to ensure fresh data:
   - Run `<skill-base-dir>/scripts/fetch_design_docs.sh` (fetches only new/updated TDDs since last sync)
   - If index doesn't exist, automatically runs full sync
   - Ensures the index at `references/design-docs/design-doc-index.md` is up-to-date

2. **Load TDD index** - Read `<skill-base-dir>/references/design-docs/design-doc-index.md`
   - Contains ~200 TDDs with: Title, Created, Last Edited, Tech Lead, Manager, Team, Epic, Services, Problem, Summary

3. **Apply filters based on user query** - Filter TDDs by:
   - Team/People: Filter by Team, Tech Lead, or Manager fields
   - Service: Search Services array for service names
   - Technology/Domain: Search Title, Problem, Summary for keywords (AI, payment, infrastructure, etc.)
   - Temporal: Filter by Created or Last Edited dates
   - Epic/Project: Filter by Epic field or pattern match
   - Complexity/Scope: Filter for cross-service designs (Services array length >1)

4. **For detailed exploration**: Load `design-doc-details/PAGEID.json` for matching TDDs to access:
   - Full problem description (~500 chars)
   - Complete solution summary (~500 chars)
   - Section-by-section summaries (Context, Goals, Design, Non-Goals, Risks, Alternatives, etc.)
   - Complete service list
   - All metadata fields

5. **Present results** with appropriate grouping:
   - **List view**: Title, Tech Lead, Team, Services, Created date, Epic
   - **Summary view**: Include Problem snippet for context
   - **Detailed view**: Full cache content for specific TDDs
   - **Analytics**: Count by team, timeline trends, technology distribution

6. **Support follow-up queries** - For deeper exploration of specific TDDs, load `design-doc-details/PAGEID.json` to access full problem/solution descriptions, section summaries, and complete metadata

### Design Document Coverage Analysis

Trigger patterns: "Which development initiatives lack design docs?", "Check design coverage for this week"

1. **Initialize design doc resources** - First time or to refresh:
   - Run `<skill-base-dir>/scripts/fetch_design_requirements.sh` to download TDD policy
   - Caches policy to `references/design-docs/design-requirements.md`
   - Run `<skill-base-dir>/scripts/fetch_design_docs.sh` to build TDD index with rich metadata
   - Uses AWS Bedrock to extract metadata and caches to `references/design-docs/design-doc-index.md` and `design-doc-details/`

2. **Load development initiative summary** - Run `<skill-base-dir>/scripts/aggregate_feature_development.sh` for target week

3. **Load coverage analysis instructions** - Read `<skill-base-dir>/references/DESIGN_COVERAGE_ANALYSIS.md`
   - Contains comprehensive instructions for performing exploratory coverage analysis
   - Leverages rich TDD metadata (Tech Lead, Manager, Team, Epic, Services, Problem, Summary)
   - Uses smart matching based on service names, keywords, Epic numbers, and temporal proximity
   - Provides guidance on confidence levels and classification criteria

4. **Perform analysis** - Follow the workflow in DESIGN_COVERAGE_ANALYSIS.md:
   - **Step 1**: Load reference data (summary, requirements, TDD index)
   - **Step 2**: Extract development initiatives from summary with complexity indicators
   - **Step 3**: Apply TDD requirements criteria (required vs exempt)
   - **Step 4**: Smart matching using service names from TDD metadata
     - Service-based matching: Look for exact/fuzzy service name matches in TDD `metadata.services`
     - Keyword-based matching: Search TDD summaries and problem descriptions
     - Epic/ticket matching: Correlate ticket references from PRs with TDD `metadata.epic`
     - Temporal analysis: Consider when TDD created/updated vs when development initiative worked
   - **Step 5**: Deep dive for candidates using `design-doc-details/*.json` for detailed context
   - **Step 6**: Classify development initiatives as: ✅ HAS_DESIGN, ⚠️ NEEDS_DESIGN, ❓ UNCLEAR, ✓ EXEMPT
   - **Step 7**: Generate coverage report with confidence levels and evidence

5. **Generate coverage report** - Include:
   - Summary statistics (coverage rate, gaps by priority)
   - 🚨 High priority gaps (security/payment/cross-service development initiatives without TDDs)
   - ✅ Development initiatives with design documentation (with match confidence and evidence)
   - ❓ Gray areas needing human review
   - Analysis notes on methodology and limitations

6. **Present findings** - Display report to user and offer to save to `references/coverage-reports/design_coverage_report_<date>.md`

**Note**: This is exploratory analysis using progressive disclosure. Load detailed instructions from DESIGN_COVERAGE_ANALYSIS.md only when performing coverage analysis to keep the skill context-efficient.

### Governance & Dev Rules Reference

Trigger patterns: "What are the LangChain coding standards?", "Show me the TypeScript ESLint rules", "What's the versioning policy?", "How do I contribute an integration?", "What are the dev rules?", "Show me contributing guidelines", "Compare Python vs TypeScript standards"

Use this workflow when the user asks about upstream open-source coding standards, contributing guidelines, versioning policy, or development rules for the LangChain ecosystem.

#### Cached Governance Documents

All governance documents are cached locally at `<skill-base-dir>/references/governance/` and organized into four categories:

**Dev Rules** (`references/governance/dev-rules/`):
| File | Source Repo | Description |
|------|-------------|-------------|
| `CONSOLIDATED_ARCHITECTURE_AND_DEV_RULES.md` | All repos | **Start here** — Unified design doc synthesizing all dev rules across Python & TypeScript |
| `langchain-python-CLAUDE.md` | langchain | Python monorepo: architecture, coding standards, commit conventions, CI/CD |
| `langgraph-CLAUDE.md` | langgraph | LangGraph monorepo structure, library descriptions, dependency map |
| `langchainjs-AGENTS.md` | langchainjs | TypeScript: ESLint rules, coding standards, core abstractions, integration patterns |

**Contributing Guidelines** (`references/governance/contributing/`):
| File | Source | Description |
|------|--------|-------------|
| `contributing-overview-python.md` | docs.langchain.com | Contribution pathways, requirements, language policy |
| `contributing-code-python.md` | docs.langchain.com | Code standards, testing, security, dependencies, PR process |
| `contributing-documentation.md` | docs.langchain.com | Doc types, writing standards, local dev setup |
| `contributing-integrations-python.md` | docs.langchain.com | Integration types, package requirements, submission steps |
| `langchainjs-CONTRIBUTING.md` | langchainjs repo | JS/TS fork-and-PR workflow, tooling (pnpm, eslint, vitest) |
| `langchainjs-INTEGRATIONS.md` | langchainjs repo | JS/TS integration contribution: entrypoints, peer deps, scaffolding |

**Versioning & API Stability** (`references/governance/versioning/`):
| File | Source | Description |
|------|--------|-------------|
| `versioning-policy.md` | docs.langchain.com | Semantic versioning, API stability tiers, LTS designations |

**Architecture Decision Records** (`references/governance/adrs/`):
| File | Status | Description |
|------|--------|-------------|
| `ADR-001-standard-schema-validation-for-llm-providers.md` | Accepted | All LLM provider integrations must support Standard Schema validation to eliminate Zod lock-in |

ADRs capture key architectural decisions with full context, compliance evaluation, consequences, alternatives considered, and enforcement criteria. New ADRs are created via the Architecture Decision Records workflow.

#### How to Answer Governance Queries

1. **For broad questions** ("What are the dev rules?", "Show me coding standards"):
   - Load `<skill-base-dir>/references/governance/dev-rules/CONSOLIDATED_ARCHITECTURE_AND_DEV_RULES.md`
   - This single document covers architecture, coding standards, testing, security, CI/CD, and versioning across both Python and TypeScript

2. **For language-specific questions** ("What are the Python type hint rules?", "Show me TypeScript ESLint config"):
   - Load the relevant language-specific file:
     - Python: `langchain-python-CLAUDE.md`
     - TypeScript: `langchainjs-AGENTS.md`
     - LangGraph: `langgraph-CLAUDE.md`

3. **For contributing questions** ("How do I submit a PR?", "How do I add an integration?"):
   - Load the relevant contributing guide from `references/governance/contributing/`
   - For Python: `contributing-code-python.md` (code) or `contributing-integrations-python.md` (integrations)
   - For TypeScript: `langchainjs-CONTRIBUTING.md` or `langchainjs-INTEGRATIONS.md`

4. **For versioning/stability questions** ("What's the LTS policy?", "When do breaking changes happen?"):
   - Load `<skill-base-dir>/references/governance/versioning/versioning-policy.md`

5. **For cross-referencing dev rules with current development initiatives**:
   - Load the consolidated dev rules doc AND the current week's development initiative summary
   - Identify whether development initiatives follow the documented standards (e.g., are PRs using Conventional Commits? Are new integrations following the package structure?)

6. **For governance evaluation requests** ("Evaluate this PR against coding standards", "Check compliance"):
   - Use the **Governance Evaluation** workflow below
   - Loads standards, fetches PR details via GitHub CLI, evaluates across 10 dimensions, produces a scorecard

7. **For ADR requests** ("Write an ADR", "List ADRs", "Show me the latest ADR"):
   - Use the **Architecture Decision Records** workflow below
   - ADRs are cached at `<skill-base-dir>/references/governance/adrs/`

#### Refreshing Governance Documents

The cached governance documents were fetched from GitHub and docs.langchain.com. To refresh:
- **CLAUDE.md/AGENTS.md files**: Fetch from GitHub API (`langchain-ai/langchain`, `langchain-ai/langgraph`, `langchain-ai/langchainjs`)
- **Contributing/versioning docs**: Fetch from `https://docs.langchain.com/oss/python/contributing/*` and `https://docs.langchain.com/oss/python/versioning`
- Save updated files to the same paths under `references/governance/`
- Regenerate the consolidated doc if individual CLAUDE/AGENTS files changed

### Governance Evaluation

Trigger patterns: "Evaluate this initiative against coding standards", "Does this PR comply with API guidelines?", "Check governance compliance for [initiative]", "Review [PR number] against dev rules"

Use this workflow when the user asks to evaluate a specific development initiative, PR, or set of PRs against the established coding standards, API design guidelines, contributing requirements, and versioning policy.

#### Step 1: Load Governance Standards

1. Load `<skill-base-dir>/references/governance/dev-rules/CONSOLIDATED_ARCHITECTURE_AND_DEV_RULES.md`
2. Load `<skill-base-dir>/references/governance/contributing/contributing-code-python.md` (for Python PRs) or `<skill-base-dir>/references/governance/contributing/langchainjs-CONTRIBUTING.md` (for TypeScript PRs)
3. Load `<skill-base-dir>/references/governance/versioning/versioning-policy.md`

#### Step 2: Fetch PR Details

Use GitHub CLI (`gh pr view`, `gh pr diff`) to retrieve:
- PR metadata: title, author, labels, state, reviews, files changed
- Full diff for code-level analysis
- Related issue details (from PR body references)
- Review comments for maintainer feedback context

#### Step 3: Evaluate Against Each Governance Dimension

Assess the initiative across these dimensions, producing a per-dimension PASS/FAIL/ISSUE rating:

1. **Conventional Commits & PR Title** — Format `type(scope): description`, lowercase, scope required
2. **Issue Linkage** — PR links to a pre-approved issue with closing keywords
3. **Backwards Compatibility** — No breaking changes to public APIs; internal (`_prefix`) changes are acceptable
4. **Type Safety** — Complete type annotations on all functions
5. **Code Quality & Design** — Follows language-specific standards (ruff/mypy for Python, ESLint/Prettier for TS), functions under 20 lines, no eval/exec
6. **Test Coverage** — Unit tests present, happy path + edge cases + negative cases covered, deterministic, file structure mirrors source
7. **Security** — No code injection vectors, proper error handling, no sensitive data exposure
8. **Documentation** — Public API changes documented with Google-style docstrings / JSDoc
9. **Commit Messages** — Descriptive, follow Conventional Commits at commit level
10. **Performance** — No regressions (check CodSpeed reports if available)

#### Step 4: Generate Evaluation Report

Structure the report as:

```
# Governance Evaluation — [Initiative Name]

**PRs under review:** [table of PRs with title, author, state]

## 1. [Dimension Name]
| Rule | PR #XXXX | PR #YYYY |
|------|----------|----------|
| Specific rule | PASS/FAIL + detail | PASS/FAIL + detail |

**Finding:** [Explanation]

...

## Summary Scorecard
| Dimension | PR #XXXX | PR #YYYY |
|-----------|----------|----------|
| Each dimension | PASS/FAIL | PASS/FAIL |

### Overall Assessment
[Key strengths, findings to address, lessons for contributors]
```

#### Step 5: Optionally Generate ADR

If the evaluation reveals a significant architectural decision, offer to create an ADR capturing the decision (see Architecture Decision Records workflow below).

### Architecture Decision Records (ADRs)

Trigger patterns: "Write an ADR for [decision]", "Create an ADR", "List all ADRs", "Show me the latest ADR", "What ADRs exist?"

Use this workflow to create, list, or review Architecture Decision Records that capture key architectural decisions arising from development initiatives, governance evaluations, or design discussions.

#### ADR Cache Location

ADRs are stored at `<skill-base-dir>/references/governance/adrs/` with the naming convention:

```
ADR-NNN-short-kebab-case-title.md
```

Example: `ADR-001-standard-schema-validation-for-llm-providers.md`

#### Creating a New ADR

1. **Determine next ADR number** — List existing files in `references/governance/adrs/` and increment
2. **Gather context** — Load relevant development initiative data, PR details, governance standards, and TDDs
3. **Write the ADR** using this template:

```markdown
# ADR-NNN: [Decision Title]

**Status:** Proposed | Accepted | Deprecated | Superseded
**Date:** YYYY-MM-DD
**Decision Makers:** [Who made or approved the decision]
**Initiative:** [Related development initiative or PR set]

---

## Context
[What is the problem or situation that requires a decision? Include technical background, business drivers, and constraints.]

## Decision
[What is the decision? Be specific and actionable. Include scope of what is affected.]

## Scope of Change
[Which packages, services, or components are affected? Include PR references.]

## Compliance With Coding Standards
[Evaluate the decision against the consolidated dev rules. Use a table mapping governance rules to PASS/FAIL assessments.]

## Consequences

### Positive
[Benefits of this decision]

### Negative / Risks
[Drawbacks, risks, increased complexity]

### Neutral
[Side effects that are neither positive nor negative]

## Alternatives Considered
[What other options were evaluated and why they were rejected?]

## Enforcement
[How will this decision be enforced going forward? CI checks, PR review requirements, standard tests, etc.]

## References
[Links to PRs, issues, specs, governance documents]
```

4. **Save the ADR** to `<skill-base-dir>/references/governance/adrs/ADR-NNN-short-title.md`

#### Listing ADRs

Read the `<skill-base-dir>/references/governance/adrs/` directory and present a summary table:

```
| ADR | Title | Status | Date | Initiative |
|-----|-------|--------|------|------------|
| ADR-001 | Standard Schema Validation for LLM Providers | Accepted | 2026-03-09 | Standard Schema Support |
```

#### Reviewing an ADR

Load the requested ADR file and present its contents. For cross-referencing:
- Link to related development initiatives from the weekly summaries
- Link to related TDDs from the design doc index
- Verify governance compliance claims against current coding standards

## Guidelines

- Maintain the original content from each service file
- Use service names (filename without .txt) as section headers
- Help identify patterns and insights across the engineering organization

## Configuration

Workflows require AWS authentication for S3 and Bedrock access. For setup instructions:

- **AWS Setup**: See `<skill-base-dir>/references/setup/aws_configuration.md`

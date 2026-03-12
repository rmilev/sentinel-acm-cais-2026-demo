# Design Document Coverage Analysis - Instructions

This document provides instructions for performing exploratory design document coverage analysis using the rich metadata available from TDD extraction.

## Overview

The goal is to identify features from weekly summaries that may require Technical Design Documents (TDDs) but don't have them, or to verify that features with significant scope have corresponding design documentation.

## Data Sources

### 1. Weekly Feature Development Summary
**Location**: `<skill-base-dir>/references/feature-development-summaries/feature_development_summary_YYYY-MM-DD.md`

**Structure**:
```markdown
## service-name

PR descriptions and feature development summaries for the week
```

### 2. TDD Requirements Policy
**Location**: `<skill-base-dir>/references/design-docs/design-requirements.md`

**Contains**: Criteria for when a TDD is required:
- Architectural complexity (multiple layers, microservices)
- Services involved (external APIs, internal dependencies)
- Integrations (external providers, real-time data)
- Database changes (schema, transactions, distributed)
- Feature thresholds (complexity, novelty, risk, business impact)

### 3. TDD Index (Lightweight)
**Location**: `<skill-base-dir>/references/design-docs/design-doc-index.md`

**Contains**: For each of ~200 TDDs:
- Page ID and URL
- Title
- Created date
- Last edited date
- Status
- Tech Lead, Manager, Team, Epic
- **Related Services** (key for matching!)
- Problem summary (~500 chars)
- Summary (~500 chars)
- Link to detailed cache

### 4. TDD Detailed Cache (Rich)
**Location**: `<skill-base-dir>/references/design-docs/design-doc-details/PAGEID.json`

**Structure**:
```json
{
  "page_id": "5204934665",
  "title": "Tech Design - OpenTelemetry Migration for Logs (ARCH-563)",
  "last_edited": "2025-12-02T23:27:42.773Z",
  "extraction": {
    "metadata": {
      "tech_lead": "Patrick Beckhelm",
      "manager": "Patrick Beckhelm",
      "team": "SRE/Release",
      "epic": "ARCH-563",
      "services": [
        "translation-service",
        "flights-incidents",
        "ta-gateway"
      ]
    },
    "problem": "Current observability infrastructure has high annual costs...",
    "summary": "This design document outlines a comprehensive migration...",
    "sections": {
      "context": "Summary of context section...",
      "goals": "Summary of goals section...",
      "design": "Summary of design section...",
      // ... 7 more sections
    }
  }
}
```

## Analysis Workflow

### Step 1: Load Reference Data

1. **Load feature development summary**: Read the weekly feature development summary file for target week
2. **Load TDD requirements**: Read criteria for when TDDs are required
3. **Load TDD index**: Read the index to get overview of all TDDs with metadata

### Step 2: Extract Features from Feature Development Summary

For each service section (`## service-name`) in the weekly feature development summary:

**Extract**:
- Service name (from header)
- PR descriptions
- Feature keywords
- Complexity indicators

**Look for signals**:
- "new service", "infrastructure", "migration"
- "API changes", "breaking changes", "schema change"
- "database migration", "new table", "SQL"
- "cross-service", "integration", "external API"
- "security", "authentication", "payment", "PCI", "PII"
- "microservice", "architecture", "design pattern"
- Size indicators: "large refactor", ">1000 LOC", "multi-sprint"

### Step 3: Apply TDD Requirements Criteria

For each feature, check against `design-requirements.md`:

**Required TDD if**:
- Multiple architectural layers involved
- Multiple microservices with complex interactions
- External API/provider integration
- Internal service dependencies with failure scenarios
- PCI/PII data handling
- Database schema changes or distributed transactions
- Feature complexity high
- Significant business impact
- Novelty/innovation introduced

**Exempt from TDD if**:
- Dependency updates only
- Test additions
- Small bug fixes (<100 LOC)
- Documentation changes
- Feature flag additions (no logic)
- Config changes only

### Step 4: Smart Matching Using Rich Metadata

This is the KEY improvement over the old script!

**CRITICAL MATCHING PRINCIPLES**:

1. **Temporal Proximity is MANDATORY**: TDDs written long ago (>3-6 months) are unlikely to be applicable to current PRs. Always consider TDD creation/update date relative to PR dates.

2. **Single-Service Constraint**: One TDD typically covers one service/repository. Do NOT match a single TDD to features from different repos or teams - they are unlikely to share a TDD.

3. **Conservative Matching**: When in doubt, DO NOT match. It's better to report "no matching TDD found" than to create false positive matches.

#### 4.1 Quick Service-Based Matching

For each feature that needs analysis:

1. **Extract service name** from section header (e.g., "ta-hotel-service")
2. **Search TDD index** for matching services:
   ```
   Look for: "Related Services: ta-hotel-service"
   Or similar: "hotel-service", "ta-hotel", "hotel"
   ```
3. **Apply STRICT temporal filter**:
   - **REJECT TDDs created/updated >6 months ago** unless explicitly recent implementation of old design
   - **PREFER TDDs within 1-3 months** of feature work
   - **IDEAL: TDDs created within ±2 weeks** of PR dates

4. **Verify single-service alignment**:
   - If TDD lists multiple services, it should only match features from ALL those services working together
   - Do NOT match individual features from different repos to the same TDD
   - Example: If TDD covers ["service-a", "service-b", "service-c"], only match if features from all three services are part of the same coordinated work

#### 4.2 Keyword-Based Candidate Matching

If no exact service match:

1. **Extract keywords** from feature description (e.g., "payment", "hotel", "OpenTelemetry")
2. **Search TDD index** summaries for keyword matches
3. **Apply STRICT temporal filter FIRST**: Eliminate TDDs >6 months old before keyword ranking
4. **Rank remaining candidates** by:
   - Keyword overlap strength
   - Temporal proximity (closer = better)
   - Service/team alignment (same team = higher confidence)
5. **Apply single-service constraint**: If candidate TDD is from a different service/team, require VERY strong evidence (Epic match, explicit cross-reference in PR)

#### 4.3 Epic/Ticket Matching

If PR mentions issue tracker tickets:

1. **Extract ticket numbers** (e.g., "ARCH-563", "ENG-1234")
2. **Search TDD index** for matching Epic field
3. **Direct match** = high confidence link

### Step 5: Deep Dive for Candidates

For each candidate TDD match:

1. **Load detailed cache**: Read `design-doc-details/PAGEID.json`
2. **Analyze rich metadata**:
   - Do `metadata.services` overlap with feature's service?
   - Does `problem` description relate to feature work?
   - Does `summary` mention similar goals/scope?
   - Are `sections.goals` or `sections.design` relevant?
3. **Temporal analysis**:
   - Was TDD created before feature work? (design-first)
   - Was TDD updated during feature week? (concurrent documentation)
   - Was TDD created after? (retroactive documentation)
   - Is TDD from much earlier? (pre-existing design being implemented)
4. **Coordinated multi-service validation** (if TDD lists multiple services):
   - Check if features from ALL listed services are present in the same week
   - Verify they reference the same Epic or have cross-references in PR descriptions
   - Confirm temporal alignment: all PRs within similar timeframe
   - If only ONE service from the TDD's service list has features this week, DO NOT match - this indicates partial/phased implementation or different work
   - Example VALID: TDD lists ["fields", "server", "ta-events-experience"], and all three have HR attribute features in week 2025-12-11
   - Example INVALID: TDD lists ["fields", "server", "ta-events-experience"], but only "fields" has features this week

### Step 6: Classification

Classify each feature into one of:

**✅ HAS_DESIGN** - Feature has matching TDD
- Criteria: Strong service/epic/keyword match + temporal alignment
- Include: TDD title, URL, confidence level (high/medium/low)

**⚠️ NEEDS_DESIGN** - Meets TDD criteria but no matching TDD found
- Criteria: Passes requirements check + no candidate matches
- Include: Why TDD is needed (which criteria triggered)
- Priority: HIGH if security/payment/cross-service, MEDIUM otherwise

**❓ UNCLEAR** - Gray area, needs human review
- Criteria: Borderline complexity OR weak candidate matches
- Include: Why unclear, what additional info would help

**✓ EXEMPT** - Doesn't require TDD
- Criteria: Matches exemption patterns
- Include: Exemption reason (optional, can skip in report)

### Step 7: Generate Coverage Report

**Report Structure**:

```markdown
# Design Document Coverage Report

**Week**: 2025-12-02
**Analysis Date**: 2025-12-05
**Total Services Analyzed**: 25
**Features Requiring Design**: 8
**Features with TDDs**: 5
**Coverage Rate**: 62.5%

---

## Summary Statistics

| Category | Count | Percentage |
|----------|-------|------------|
| Has Design (✅) | 5 | 62.5% |
| Needs Design (⚠️) | 3 | 37.5% |
| Unclear (❓) | 2 | - |
| Exempt (✓) | 15 | - |

---

## 🚨 High Priority Gaps (Features Needing TDDs)

### ta-payment-service

#### ⚠️ PCI compliance for payment processing
- **Why TDD Required**: Security + PCI data handling + Cross-service integration
- **Complexity**: Database schema changes, external provider API
- **Impact**: High - affects payment flow for all products
- **Temporal Context**: Feature worked on week of 2025-12-02
- **Search Results**: No matching TDD found
  - Searched for: "payment", "PCI", "ta-payment-service"
  - Closest match: "Tech Design - Payment Gateway Refactor (ARCH-501)" from 2024-08-15 (too old, different scope)
- **Recommendation**: ⚠️ **CREATE TDD BEFORE PROCEEDING** - This is security-critical

---

## ✅ Features with Design Documentation

### ta-hotel-service

#### ✅ Hotel search API rate limiting
- **TDD**: Tech Design - Hotel API Performance Optimization (ARCH-558)
- **URL**: https://your-wiki.example.com/pages/5191234567
- **Match Confidence**: HIGH
- **Evidence**:
  - Service match: ✅ "ta-hotel-service" in TDD metadata
  - Temporal alignment: ✅ TDD updated 2025-11-28, feature worked 2025-12-02
  - Scope overlap: ✅ TDD sections cover rate limiting design
- **Tech Lead**: John Smith
- **Team**: Travel/Hotels
- **Status**: Design approved, implementation in progress

---

## ❓ Gray Areas (Need Human Review)

### commerce-ai

#### ❓ ML model retraining pipeline refactor
- **Why Unclear**: Significant complexity but might be incremental improvement to existing design
- **Possible Match**: "Tech Design - ML Training Infrastructure (ARCH-499)" from 2025-09-10
  - Match confidence: MEDIUM
  - Unclear if this TDD covers the refactor or if new TDD needed
- **Recommendation**: Review with Tech Lead to confirm scope

---

## Analysis Notes

### Matching Methodology
- Service name matching: Direct match in TDD metadata.services
- Temporal window: ±3 months from feature week
- Keyword matching: Problem and summary fields from TDD index
- Epic correlation: Ticket extraction from PR descriptions

### Limitations
- Some TDDs may exist in other formats (Google Docs, GitHub)
- Some features may have verbal design discussions not documented
- Epic/ticket extraction relies on consistent PR description format
- Service name variations may cause missed matches (e.g., "hotel-service" vs "ta-hotel-service")

### Recommendations for Improvement
1. Standardize service naming in TDD metadata
2. Always include Epic/ticket reference in TDD title or metadata
3. Update TDDs when significant implementation deviations occur
4. Consider lightweight design docs for medium-complexity features
```

## Best Practices

### Confidence Levels for Matching

**HIGH Confidence** (Safe to report as definite match):
- Exact service name match in `metadata.services` AND
- Epic number matches (e.g., "ARCH-563") OR
- TDD created/updated within ±2 weeks of feature work AND
- Problem statement directly relates to feature
- Single service or explicitly coordinated multi-service work

**MEDIUM Confidence** (Report with caveats):
- Service name fuzzy match (e.g., "hotel" matches "ta-hotel-service") AND
- TDD within 1-3 months of feature work AND
- Keyword overlap in summaries AND
- Same team working on feature and TDD
- Single service constraint satisfied

**LOW Confidence** (Flag as UNCLEAR, needs human review):
- Only keyword matches OR
- Temporal gap >3 months OR
- Different services/teams without explicit coordination OR
- Vague correlation

**REJECT** (Do not match):
- Temporal gap >6 months (unless explicit evidence of delayed implementation)
- Cross-service match without coordination evidence
- Different teams with no shared Epic

### Common Pitfalls to Avoid

1. **Don't over-match**: Not every feature touching a service needs a design doc
2. **Consider incremental work**: Small additions to existing features are usually exempt
3. **Check TDD status**: "Draft" TDDs may not be approved yet
4. **⚠️ CRITICAL: Respect temporal proximity**:
   - TDD created >6 months ago is almost NEVER applicable to current PRs
   - Old TDDs represent past designs, not current work
   - Don't match old TDDs just because keywords overlap
5. **⚠️ CRITICAL: Avoid cross-service/cross-team matching**:
   - One TDD rarely covers features in different repositories
   - Don't match "server" features and "commerce-ai" features to the same TDD
   - Exception: Only if explicitly coordinated work (same Epic, same timeframe, TDD explicitly lists both services)
6. **Service sprawl**: A TDD for "ta-gateway" doesn't cover features in "ta-hotel-service" just because gateway is involved
7. **Conservative over liberal**: When uncertain, report "no TDD found" rather than weak matches

### When to Flag for Human Review

Flag as UNCLEAR if:
- Multiple weak candidate matches (can't pick one)
- Feature complexity borderline
- Service name mismatch but keywords match
- TDD exists but scope unclear
- Feature spans multiple services with different TDD coverage

## Output Format

Generate markdown report and optionally save to:
`<skill-base-dir>/references/coverage-reports/design_coverage_report_YYYY-MM-DD.md`

## Usage in Skill Workflow

When user asks:
- "Which features lack design docs?"
- "Check design coverage for this week"
- "Show me features without TDDs"
- "Are there any cross-service changes missing design docs?"

**Workflow**:
1. Load this instruction file
2. Load the three data sources (summary, requirements, index)
3. Follow the analysis workflow above
4. Generate and display the coverage report
5. Offer to save report to references/coverage-reports/

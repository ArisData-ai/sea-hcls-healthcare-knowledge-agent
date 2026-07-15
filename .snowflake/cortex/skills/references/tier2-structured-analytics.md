---
name: tier2-structured-analytics
description: This skill defines the Tier 2 structured analytics path for the Healthcare Knowledge Agent, covering the semantic view consumed by Cortex Analyst and the dual-tool Cortex Agent configuration that binds it alongside Cortex Search. Use this skill for any task involving semantic view design or maintenance, Cortex Analyst query patterns, binding Cortex Search and Cortex Analyst as tools on a single Cortex Agent, tool-selection instructions, or building the read-only conversational panel that answers questions about knowledge-base health.
---

# Tier 2 Structured Analytics — Skill

## Overview

Tier 1 answers questions about clinical, regulatory, and operational content. Tier 2 answers questions about the knowledge base itself: which protocols are overdue, what the open compliance fine exposure is, how the agent's self-resolution rate is trending. Both tiers are exposed through one Cortex Agent, but they are separate tools with separate data surfaces — Tier 2 never touches document content, and it is strictly read-only.

This tier powers the **Cortex Agent Conversational Panel** (Screen 4 of the human-in-the-loop workflow) and the KPI tiles on the **Compliance & Protocol Oversight** screen (Screen 3).

## When to Use

Use this skill for any task involving:

- Adding or modifying facts, dimensions, or metrics in the semantic view
- Writing natural-language-to-SQL query patterns against `SV_HEALTHCARE_KNOWLEDGE_OPS`
- Configuring the Cortex Agent's tool-selection instructions between Search and Analyst
- Building the read-only conversational panel
- Diagnosing why a knowledge-base-health question routed to the wrong tool

## Instructions

### Semantic Layer (already built — extend, don't re-derive)

The base view `AI_BI_VW_SEMANTIC_KNOWLEDGE_OPS` joins monthly query-resolution metrics with protocol-health, compliance-gap, and knowledge-coverage snapshots at an organisation-type grain. The semantic view `SV_HEALTHCARE_KNOWLEDGE_OPS` sits on top of it with the mandatory clause order `TABLES → FACTS → DIMENSIONS → METRICS`.

Four dimensions anchor every question: `REPORTING_MONTH`, `ORGANISATION_TYPE`, `USER_PERSONA_CATEGORY`, `QUERY_CONTENT_DOMAIN`. Snapshot metrics (protocol health, compliance gap, knowledge coverage) use `MAX` aggregation, not `SUM`, because those values repeat per monthly row rather than accumulate — this is already encoded in the view's `AI_SQL_GENERATION` guidance block and must stay that way when new metrics are added.

When extending the semantic view for a new question type:

1. Add the underlying fact/aggregate to the appropriate `CURATED_VW_*` view first — never compute a new metric inline inside the semantic view
2. Add the fact to the semantic view's `FACTS` block with a synonym list a business user would actually type
3. Add the metric to `METRICS`, choosing `SUM` for additive counts and `MAX`/`AVG` for snapshot or rate values — get this wrong and multi-month rollups silently double-count
4. Extend `AI_SQL_GENERATION` guidance if the new metric needs a non-obvious aggregation rule

### Binding Both Tools on One Cortex Agent

    -- Conceptual tool binding (Cortex Agent configuration, not raw SQL)
    Tool 1: KA_KNOWLEDGE_SEARCH        -- Cortex Search, unstructured content
        Use when: the question is about clinical, regulatory, or operational
                  content itself (protocol steps, policy language, regulation text)

    Tool 2: SV_HEALTHCARE_KNOWLEDGE_OPS -- Cortex Analyst, structured semantic view
        Use when: the question is about the knowledge base as a system
                  (counts, rates, trends, exposure, overdue items)

Tool-selection instruction for the agent (plain-language, goes in the Cortex Agent's orchestration config):

    "If the user is asking what a policy or protocol says, or wants an answer
    sourced from document content, use the Search tool. If the user is asking
    about the state of the knowledge base itself — counts, trends, overdue
    items, compliance exposure, resolution rates — use the Analyst tool. Never
    use the Analyst tool to answer a content question, and never use the
    Search tool to answer a metrics question."

Route ambiguous questions ("why does finding the right answer take so long") to the Analyst tool first — it is the one built to answer questions about the system's own performance.

### Read-Only Enforcement

The role backing the Cortex Agent's Analyst tool call gets `SELECT` only, on `SV_HEALTHCARE_KNOWLEDGE_OPS` and nothing else:

    GRANT USAGE ON SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;
    GRANT SELECT ON SEMANTIC VIEW SV_HEALTHCARE_KNOWLEDGE_OPS TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;

No `INSERT`, `UPDATE`, or `DELETE` grant exists on this role, on any object, ever. This is what makes "read-only" a data-layer guarantee for the Conversational Panel rather than a UI-only convention — see `healthcare-knowledge-governance.md` for the full role definition.

### Example Query Coverage

| Natural-language question | Resolves via |
|---|---|
| "Which protocols are overdue for review?" | `OPS.TOTAL_PROTOCOLS_OVERDUE`, filtered/grouped by `ORGANISATION_TYPE` |
| "What's our open fine exposure?" | `OPS.TOTAL_FINE_EXPOSURE_USD` |
| "How is agent self-resolution trending?" | `OPS.OVERALL_RESOLUTION_RATE_PCT` grouped by `REPORTING_MONTH` |
| "Where is our biggest compliance exposure right now?" | `OPS.TOTAL_CRITICAL_HIGH_FINDINGS` + `OPS.TOTAL_FINE_EXPOSURE_USD`, grouped by `ORGANISATION_TYPE` |
| "What is the current sepsis protocol?" | **Not this tool** — routes to Tier 1 / Search |

## Coding Conventions

- Never let the Analyst tool's role acquire write privileges, even temporarily, even for a demo environment
- New metrics default to `SUM`; override to `MAX` only for values confirmed to be a repeating snapshot per row, and document the reason inline in the metric's `COMMENT`
- Tool-selection instructions live in the Cortex Agent configuration, not scattered across prompt strings in application code — one source of truth
- Every semantic view change gets validated against the existing smoke-test pattern (`step_06_smoke_tests.sql` style) before it ships
- Use 4-space indentation throughout; no triple backticks in skill file content
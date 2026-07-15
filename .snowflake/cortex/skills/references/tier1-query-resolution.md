---
name: tier1-query-resolution
description: This skill defines the reactive Tier 1 query path for the Healthcare Knowledge Agent, a single confidence-plus-currency gate applied uniformly across clinical, regulatory, and operational content domains through one Cortex Search Service. Use this skill for any task involving query answering logic, relevance and currency threshold tuning, prompt design for retrieval-augmented answers, domain-specific prompt framing (clinical vs regulatory vs operational), or the decision boundary between an instant answer and a routed knowledge gap.
---

# Tier 1 Query Resolution — Skill

## Overview

This skill covers how the agent answers (or declines to answer) a single incoming question. It replaces three previously separate skills — clinical retrieval, regulatory search, and operational access — because the actual retrieval path is one Cortex Search Service (`KA_KNOWLEDGE_SEARCH`) filtered by content attributes, not three parallel raw/chunk/index table sets. Domain distinctions now live only in prompt framing, not in pipeline architecture.

**Key outcome:** every answer returned through this path is either strongly evidenced and current, or not returned at all — in which case it becomes a tracked knowledge gap instead.

## When to Use

Use this skill for any task involving:

- Building or modifying the query-answering function
- Tuning the confidence threshold or currency rules
- Writing or adjusting the prompt instructions Cortex Search / Cortex Agent uses to answer
- Deciding what reason code a routed gap should carry
- Adding a new content domain's prompt framing without adding a new pipeline

## Instructions

### The Gate

A query only gets an instant answer when both conditions hold:

    1. STRONG MATCH   — the top retrieved chunk's relevance score meets or
                         exceeds the confident-answer threshold
    2. CURRENT SOURCE — the matched chunk's STATUS != 'EXPIRED', its
                         EXPIRY_DATE (if any) is in the future, and the
                         source document is not already sitting in
                         HITL_TBL_REVIEW_QUEUE as a known, unresolved gap

If either condition fails, the agent does not answer. It logs the query and inserts a row into the review queue instead. This is Objective 1 and Objective 2 from the agent's core contract, implemented as one function.

### Query Resolution Function

    CREATE OR REPLACE FUNCTION KA_RESOLVE_QUERY(
        user_query        VARCHAR,
        content_type       VARCHAR,   -- optional filter, e.g. 'Clinical Protocol'
        department_scope   VARCHAR,   -- optional filter
        facility_scope     VARCHAR    -- optional filter
    )
    RETURNS TABLE (
        answer               VARCHAR,
        source_document       VARCHAR,
        confidence_tier       VARCHAR,   -- 'ANSWERED' | 'ROUTED'
        relevance_score       FLOAT,
        currency_status       VARCHAR,
        reason_code           VARCHAR    -- populated only when ROUTED
    )
    AS
    $$
        WITH candidates AS (
            SELECT
                CHUNK_TEXT, DOC_ID, DOCUMENT_NAME, STATUS, EXPIRY_DATE,
                SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'KA_KNOWLEDGE_SEARCH',
                    OBJECT_CONSTRUCT(
                        'query', user_query,
                        'columns', ARRAY_CONSTRUCT('CHUNK_TEXT', 'DOC_ID',
                                                    'DOCUMENT_NAME', 'STATUS', 'EXPIRY_DATE'),
                        'filter', OBJECT_CONSTRUCT(
                            '@and', ARRAY_CONSTRUCT(
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CONTENT_TYPE', content_type)),
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('DEPARTMENT_SCOPE', department_scope)),
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('FACILITY_SCOPE', facility_scope))
                            )
                        ),
                        'limit', 5
                    )
                ) AS RESULTS
        )
        -- gate evaluation and answer/route branching implemented in the
        -- calling Cortex Agent orchestration layer; see tier2-structured-analytics.md
        -- for how this function is bound as a tool alongside Cortex Analyst
        SELECT * FROM candidates
    $$;

The gate itself (comparing relevance to threshold, checking currency, deciding ANSWERED vs ROUTED) is orchestration logic sitting in front of this function, not buried inside it — keep the retrieval call and the gate decision as separate, testable steps.

### Threshold Configuration

Two thresholds, both read from `KA_CONFIG` (see `snowflake-knowledge-platform.md`), never hardcoded:

    tier1_confidence_threshold   default 0.78   -- meet or exceed: eligible for instant answer
    tier1_gap_signal_threshold   default 0.65   -- below this: "no relevant content found"
                                                  --   reason_code = NO_MATCH
                                                  -- between the two thresholds: "weak match"
                                                  --   reason_code = WEAK_MATCH
                                                  -- strong match but stale source:
                                                  --   reason_code = STALE_SOURCE
                                                  -- strong match but document already
                                                  --   in the review queue:
                                                  --   reason_code = KNOWN_GAP

### Domain-Specific Prompt Framing

The retrieval mechanism is identical across domains; only the answer-generation prompt changes:

- **Clinical questions** — plain-language answer, cite the source document, format procedural content as numbered steps
- **Regulatory questions** — stricter framing: attribute every statement to a specific regulation code and document, never generalize beyond the retrieved text, explicit non-inference instruction
- **Operational questions** — plain-language answer, cite the source document and owner, format procedural content as numbered steps, surface `OVERDUE_REVIEW` warnings if the matched content carries one

Route to the appropriate prompt template based on the `CONTENT_TYPE` of the top-matched chunk, not on a separate pipeline.

### Logging Every Interaction

Every call to this function writes one row to `CURATED_TBL_KNOWLEDGE_QUERIES`, regardless of outcome:

    -- Fast path (ANSWERED)
    RESOLUTION_CHANNEL = 'Cortex Search', ANSWER_CONFIDENCE = 'High' | 'Medium',
    WAS_KNOWLEDGE_GAP = FALSE

    -- Routed path (ROUTED)
    RESOLUTION_CHANNEL = 'Unresolved', ANSWER_CONFIDENCE = 'Low' | 'Not Found',
    WAS_KNOWLEDGE_GAP = TRUE

A `WAS_KNOWLEDGE_GAP = TRUE` row is what feeds `HITL_TBL_REVIEW_QUEUE` — see `human-in-the-loop-workflow.md` for the insert trigger.

### Output Response Structure

    {
        "query": "<original user query>",
        "answer": "<plain-language response, or null if routed>",
        "source_document": "<document name, or null if routed>",
        "confidence_tier": "ANSWERED | ROUTED",
        "relevance_score": <float>,
        "currency_status": "CURRENT | EXPIRED | OVERDUE_REVIEW | KNOWN_GAP",
        "reason_code": "NO_MATCH | WEAK_MATCH | STALE_SOURCE | KNOWN_GAP | null",
        "logged_query_id": "<CURATED_TBL_KNOWLEDGE_QUERIES.QUERY_ID>",
        "retrieved_at": "<timestamp>"
    }

## Coding Conventions

- One retrieval path for all content domains; do not create per-domain raw/chunk/index tables — filter `KA_KNOWLEDGE_SEARCH` by attribute instead
- The gate decision (ANSWERED vs ROUTED) must be deterministic and testable independent of the LLM call — never let the model itself decide whether to answer or route
- Every routed query must carry a `reason_code`; never insert a bare "unresolved" row with no explanation
- Thresholds live in `KA_CONFIG`; changing them is a config update, not a code change
- Regulatory prompt framing's non-inference instruction is non-negotiable — never relax it for a "just this once" demo
- Use 4-space indentation throughout; no triple backticks in skill file content

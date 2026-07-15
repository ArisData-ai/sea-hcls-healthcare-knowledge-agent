---
name: snowflake-knowledge-platform
description: This skill defines the Snowflake platform configuration, single-schema layout, orchestration graph, and deployment patterns for the Healthcare Knowledge Agent. Use this skill for any task involving warehouse or schema setup, the KA_CONFIG table, the full Task/Stream orchestration graph tying ingestion and human-in-the-loop pipelines together, or choosing between Snowflake Native App, Bring Your Own Snowflake, and ArisData-Managed deployment patterns.
---

# Snowflake Knowledge Platform — Skill

## Overview

This skill covers the infrastructure every other skill in this project builds on: warehouse sizing, the single-schema object layout, the configuration table, the orchestration graph that turns five formerly-manual pipelines into one, and the three ways this agent can ship into a customer's environment.

## When to Use

Use this skill for any task involving:

- Initial environment setup for the Healthcare Knowledge Agent
- Adding a new entry to `KA_CONFIG`
- Understanding or extending the Task/Stream dependency graph
- Choosing or explaining a deployment pattern to a customer

## Instructions

### Warehouse, Database, Schema

    CREATE OR REPLACE WAREHOUSE WH_HCLS_XS
        WAREHOUSE_SIZE = 'XSMALL'
        AUTO_SUSPEND = 60
        AUTO_RESUME = TRUE
        INITIALLY_SUSPENDED = TRUE
        COMMENT = 'Healthcare Knowledge Agent - retrieval, indexing, and review workloads';

    CREATE OR REPLACE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
    CREATE OR REPLACE SCHEMA DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE;

    CREATE ROLE IF NOT EXISTS ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;

Single-schema pattern: every object lives in `SCHEMA_HEALTHCARE_KNOWLEDGE`. Prefixes substitute for schema-level separation — `KA_` (pipeline), `CURATED_TBL_`/`CURATED_VW_` (structured business layer), `AI_BI_VW_`/`SV_` (semantic layer), `HITL_TBL_`/`HITL_VW_` (review layer). If a customer's governance model requires physical schema separation instead, split along these same prefix boundaries rather than inventing a new grouping.

### Configuration Table

    CREATE OR REPLACE TABLE KA_CONFIG (
        CONFIG_KEY      VARCHAR PRIMARY KEY,
        CONFIG_VALUE    VARCHAR,
        DESCRIPTION     VARCHAR,
        UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
    );

    INSERT INTO KA_CONFIG VALUES
        ('chunk_size_chars',            '1800', 'Target characters per document chunk', CURRENT_TIMESTAMP()),
        ('chunk_overlap_chars',         '300',  'Character overlap between adjacent chunks', CURRENT_TIMESTAMP()),
        ('search_target_lag',           '1 hour', 'Cortex Search Service refresh lag', CURRENT_TIMESTAMP()),
        ('tier1_confidence_threshold',  '0.78', 'Minimum relevance score for an instant answer', CURRENT_TIMESTAMP()),
        ('tier1_gap_signal_threshold',  '0.65', 'Below this, treat as no relevant match', CURRENT_TIMESTAMP()),
        ('escalation_age_days',         '14',   'Days an open queue item may sit before auto-escalation', CURRENT_TIMESTAMP()),
        ('gap_queue_sweep_schedule',     'USING CRON 0 6 * * * UTC', 'Schedule for TASK_REFRESH_GAP_QUEUE', CURRENT_TIMESTAMP());

Every threshold referenced in `tier1-query-resolution.md` and `human-in-the-loop-workflow.md` is read from this table at run time — no threshold is hardcoded in a Task or function body.

### Orchestration Graph (the single pipeline)

This is what "orchestrated into one pipeline" means concretely — one dependency graph instead of six scripts run by hand:

    STREAM_KA_DOC_STAGE_DIR (stage stream)
        └── TASK_PARSE_NEW_DOCS            (10-min poll, WHEN stream has data)
                └── STREAM_KA_DOC_RAW (table stream)
                        └── TASK_CHUNK_NEW_DOCS     (AFTER TASK_PARSE_NEW_DOCS)
                                └── [Cortex Search Service refreshes itself, TARGET_LAG]

    TASK_REFRESH_GAP_QUEUE               (independent daily schedule, 06:00 UTC)
        └── TASK_ESCALATE_STALE_REVIEWS  (AFTER TASK_REFRESH_GAP_QUEUE)

    Tier 1 query resolution (KA_RESOLVE_QUERY) — event-driven, not scheduled;
    inserts directly into HITL_TBL_REVIEW_QUEUE on every ROUTED outcome

Two independent roots (document ingestion, gap-queue maintenance) instead of one — this matches the overview document's description of the pipeline having "two independent entry points... that meet in a shared governed layer." Forcing them into a single linear chain would create a false dependency (gap detection does not need to wait on document parsing to run).

    -- Resume order matters: leaf tasks before root when using AFTER dependencies
    ALTER TASK TASK_CHUNK_NEW_DOCS RESUME;
    ALTER TASK TASK_PARSE_NEW_DOCS RESUME;
    ALTER TASK TASK_ESCALATE_STALE_REVIEWS RESUME;
    ALTER TASK TASK_REFRESH_GAP_QUEUE RESUME;

Use `SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_DEPENDENTS(TASK_NAME => 'TASK_PARSE_NEW_DOCS', RECURSIVE => TRUE));` to visually confirm the graph before handing this off for Snowsight development — see the Snowsight submission plan for the exact verification step.

### Horizon Tagging (platform-level, extends governance skill)

    CREATE OR REPLACE TAG SCHEMA_HEALTHCARE_KNOWLEDGE.KA_TAG_PHI_SENSITIVITY
        ALLOWED_VALUES 'CONTAINS_PHI', 'DE_IDENTIFIED', 'NON_CLINICAL', 'UNKNOWN';

    ALTER TABLE KA_DOC_RAW
        SET TAG KA_TAG_PHI_SENSITIVITY = 'CONTAINS_PHI';
    ALTER TABLE CURATED_TBL_KNOWLEDGE_QUERIES
        SET TAG KA_TAG_PHI_SENSITIVITY = 'DE_IDENTIFIED';

Detailed RBAC and row access policy grants live in `healthcare-knowledge-governance.md`; this skill only owns the tag taxonomy itself.

### Deployment Patterns

Three ways to get this agent running in a customer's environment, differing mainly in who owns the Snowflake infrastructure it runs on:

| Pattern                                | Description                                                                                                                                                                                                         | Best fit                                                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Snowflake Native App**               | The agent — search service, semantic model, schema, governance policies — ships through the Marketplace or a private listing. Customer data never leaves their account.                                             | PHI-adjacent content, where the customer's account never changing hands is the easiest position to defend |
| **Bring Your Own Snowflake (BYOS)**    | ArisData builds and configures the agent inside the customer's existing account using Terraform or deployment scripts. Customer owns the infrastructure going forward; ArisData owns getting it stood up correctly. | Customers who want ownership but not implementation burden                                                |
| **ArisData-Managed Snowflake Account** | ArisData runs a dedicated account on the customer's behalf; source data reaches it through Snowflake Data Sharing. Customer gets the agent without operating any Snowflake infrastructure themselves.               | Customers who want zero Snowflake operations overhead, trading away infrastructure ownership              |

## Coding Conventions

- No threshold, schedule, or tunable value is hardcoded anywhere outside `KA_CONFIG`
- Task `SCHEDULE` and `AFTER` clauses are the only place dependency order is expressed — never simulate ordering with `WAIT`/`CALL SYSTEM$WAIT` inside a task body
- Resume child tasks before parent tasks; suspend parent before child when tearing down
- Warehouse auto-suspend stays at 60 seconds unless a specific workload justifies a change — document the justification in the warehouse `COMMENT` if it does
- Use 4-space indentation throughout; no triple backticks in skill file content

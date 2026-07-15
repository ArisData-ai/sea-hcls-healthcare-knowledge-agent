---
name: knowledge-ingestion-and-indexing
description: This skill defines the orchestrated ingestion pipeline for the Healthcare Knowledge Agent, covering document staging, AI_PARSE_DOCUMENT text extraction, SPLIT_TEXT_RECURSIVE_CHARACTER chunking, and Cortex Search Service indexing, wired together with Snowflake Streams and Tasks into a single pipeline instead of manually run steps. Use this skill for any task involving stage setup, document parsing, chunking configuration, Cortex Search Service creation, or automating the flow from a newly staged file to a searchable chunk without manual script execution.
---

# Knowledge Ingestion & Indexing — Skill

## Overview

This skill covers the unstructured document pipeline: staging, parsing, chunking, and search indexing, orchestrated as one continuous flow. Previously this ran as five manually executed scripts (`step_01` through `step_05`); this skill replaces manual execution with Stream-triggered Tasks so that a file landing in the stage flows to a searchable chunk without a person running each step in order.

This pipeline is one of two independent entry points into the agent (the other is the structured operational tables — staff roles, documents registry, protocols, requirements, findings — which are populated separately and do not block on this pipeline finishing).

## When to Use

Use this skill for any task involving:

- Creating or modifying `KA_DOC_STAGE` / `KA_META_STAGE`
- Changing the parse mode, chunk size, or overlap for document processing
- Creating or tuning the `KA_KNOWLEDGE_SEARCH` Cortex Search Service
- Building or debugging the Task/Stream chain that automates parse → chunk → index
- Diagnosing why a newly uploaded document isn't yet searchable

## Instructions

### Stage Layer

    -- Document and metadata stages, directory-enabled for file discovery
    CREATE OR REPLACE STAGE KA_DOC_STAGE
        DIRECTORY = (ENABLE = TRUE)
        ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

    CREATE OR REPLACE STAGE KA_META_STAGE
        DIRECTORY = (ENABLE = TRUE)
        ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

`KA_DOC_METADATA` loads from `KA_META_STAGE/corpus_metadata.csv` and carries `DOC_ID`, `DOCUMENT_NAME`, `RELATIVE_PATH`, `CONTENT_TYPE`, `FACILITY_SCOPE`, `DEPARTMENT_SCOPE`, `STATUS`, `EFFECTIVE_DATE`, `EXPIRY_DATE`, `REVIEW_DATE`, `DOCUMENT_OWNER`. This table is the join key between the unstructured pipeline and the currency checks used in `tier1-query-resolution.md`.

### Parsing Layer

    CREATE OR REPLACE TABLE KA_DOC_RAW (
        RELATIVE_PATH   VARCHAR(500)  NOT NULL,
        RAW_TEXT        VARCHAR(16777216),
        PARSE_STATUS    VARCHAR(20)
    );

Parse with `AI_PARSE_DOCUMENT` in `LAYOUT` mode. `RELATIVE_PATH` from `DIRECTORY(@KA_DOC_STAGE)` carries a leading slash that must be stripped with `LTRIM(RELATIVE_PATH, '/')` before it will join cleanly to `KA_DOC_METADATA.RELATIVE_PATH` — this is a confirmed platform quirk, not optional.

### Chunking Layer

    CREATE OR REPLACE TABLE KA_DOC_CHUNKS (
        CHUNK_ID            VARCHAR(100)      NOT NULL,
        DOC_ID               VARCHAR(50)       NOT NULL,
        DOCUMENT_NAME        VARCHAR(500),
        RELATIVE_PATH        VARCHAR(500)      NOT NULL,
        CHUNK_INDEX          INT               NOT NULL,
        CHUNK_TEXT           VARCHAR(16777216) NOT NULL,
        CONTENT_TYPE         VARCHAR(100),
        DEPARTMENT_SCOPE     VARCHAR(200),
        FACILITY_SCOPE       VARCHAR(200),
        STATUS               VARCHAR(50),
        EFFECTIVE_DATE       DATE,
        EXPIRY_DATE          DATE
    );

`SPLIT_TEXT_RECURSIVE_CHARACTER` operates on characters, not tokens: 1,800 characters with 300 overlap maps to roughly a 400–600 token target per chunk. Every chunk carries the parent document's currency fields (`STATUS`, `EXPIRY_DATE`) directly, so the confidence-plus-currency gate in Tier 1 never needs a second join at query time.

### Search Indexing Layer

    CREATE OR REPLACE CORTEX SEARCH SERVICE KA_KNOWLEDGE_SEARCH
        ON CHUNK_TEXT
        ATTRIBUTES DOC_ID, DOCUMENT_NAME, CONTENT_TYPE, DEPARTMENT_SCOPE,
                   FACILITY_SCOPE, STATUS, EXPIRY_DATE
        WAREHOUSE = WH_HCLS_XS
        TARGET_LAG = '1 hour'
        AS (
            SELECT CHUNK_TEXT, DOC_ID, DOCUMENT_NAME, CONTENT_TYPE,
                   DEPARTMENT_SCOPE, FACILITY_SCOPE, STATUS, EXPIRY_DATE
            FROM KA_DOC_CHUNKS
        );

The search service watches `KA_DOC_CHUNKS` directly and refreshes on its own `TARGET_LAG` — nothing in the Task chain below needs to trigger it manually. It is the same service across every content domain (clinical, regulatory, operational); domain separation happens through the `CONTENT_TYPE` / `DEPARTMENT_SCOPE` / `FACILITY_SCOPE` attributes, not through separate services or separate raw/chunk tables per domain.

### Orchestration: One Pipeline Instead of Five Manual Steps

Replace manual script execution with a Stream-triggered Task chain so new files flow through automatically.

    -- Stream on the stage directory table: fires when new files land
    CREATE OR REPLACE STREAM STREAM_KA_DOC_STAGE_DIR ON STAGE KA_DOC_STAGE;

    -- Task 1: refresh the directory table and parse only newly staged files
    CREATE OR REPLACE TASK TASK_PARSE_NEW_DOCS
        WAREHOUSE = WH_HCLS_XS
        SCHEDULE = '10 MINUTE'
    WHEN
        SYSTEM$STREAM_HAS_DATA('STREAM_KA_DOC_STAGE_DIR')
    AS
        INSERT INTO KA_DOC_RAW (RELATIVE_PATH, RAW_TEXT, PARSE_STATUS)
        WITH PARSED AS (
            SELECT
                LTRIM(RELATIVE_PATH, '/') AS RELATIVE_PATH,
                SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                    '@KA_DOC_STAGE', RELATIVE_PATH, {'mode': 'LAYOUT'}
                ):content::VARCHAR AS RAW_TEXT
            FROM STREAM_KA_DOC_STAGE_DIR
        )
        SELECT RELATIVE_PATH, RAW_TEXT,
               CASE WHEN RAW_TEXT IS NOT NULL AND LENGTH(RAW_TEXT) > 0
                    THEN 'SUCCESS' ELSE 'FAILED' END
        FROM PARSED;

    -- Stream on the raw table: fires when TASK_PARSE_NEW_DOCS inserts rows
    CREATE OR REPLACE STREAM STREAM_KA_DOC_RAW ON TABLE KA_DOC_RAW;

    -- Task 2: chunk only newly parsed documents, chained after Task 1
    CREATE OR REPLACE TASK TASK_CHUNK_NEW_DOCS
        WAREHOUSE = WH_HCLS_XS
        AFTER TASK_PARSE_NEW_DOCS
    WHEN
        SYSTEM$STREAM_HAS_DATA('STREAM_KA_DOC_RAW')
    AS
        INSERT INTO KA_DOC_CHUNKS
        SELECT
            m.DOC_ID || '-' || c.INDEX, m.DOC_ID, m.DOCUMENT_NAME, r.RELATIVE_PATH,
            c.INDEX, c.VALUE::VARCHAR, m.CONTENT_TYPE, m.DEPARTMENT_SCOPE,
            m.FACILITY_SCOPE, m.STATUS, m.EFFECTIVE_DATE, m.EXPIRY_DATE
        FROM STREAM_KA_DOC_RAW r
        JOIN KA_DOC_METADATA m ON r.RELATIVE_PATH = m.RELATIVE_PATH,
        LATERAL FLATTEN(
            INPUT => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
                r.RAW_TEXT, 'markdown', 1800, 300
            )
        ) c
        WHERE r.METADATA$ACTION = 'INSERT';

    ALTER TASK TASK_CHUNK_NEW_DOCS RESUME;
    ALTER TASK TASK_PARSE_NEW_DOCS RESUME;

This gives a single root-to-leaf pipeline: file lands → `STREAM_KA_DOC_STAGE_DIR` has data → `TASK_PARSE_NEW_DOCS` fires → `STREAM_KA_DOC_RAW` has data → `TASK_CHUNK_NEW_DOCS` fires → Cortex Search picks up new chunks on its own `TARGET_LAG`. No step requires a person to open a worksheet and run it manually.

### Operational Table Population (the second entry point)

Staff roles, document registry, clinical protocols, regulatory requirements, and compliance findings load into the `CURATED_TBL_*` tables independently of this pipeline — see `tier2-structured-analytics.md` for how they feed the semantic layer, and `human-in-the-loop-workflow.md` for how `CURATED_TBL_DOCUMENTS` gets written back to after a human review decision. Keep the load path for these tables (batch DML today; a source-system feed later) decoupled from the document Task chain above — they answer different questions and have different refresh cadences.

## Coding Conventions

- All ingestion pipeline objects prefixed `KA_`; all orchestration objects prefixed `TASK_` or `STREAM_`, named for the action performed, not the table touched
- `LTRIM(RELATIVE_PATH, '/')` is mandatory on every read from `DIRECTORY(@KA_DOC_STAGE)` before any join to `KA_DOC_METADATA`
- Chunk size and overlap (1800 / 300 characters) are configuration, not hardcoded literals — read from `KA_CONFIG` (see `snowflake-knowledge-platform.md`) once that table exists
- Never chunk or index a document until its metadata row exists in `KA_DOC_METADATA` — the join in `TASK_CHUNK_NEW_DOCS` silently drops unmatched files, which is the correct behavior (no orphaned chunks) but should be monitored
- Task schedules are a starting point (10-minute poll on the parse task); tune against actual document arrival cadence once the customer's source system is known
- Use 4-space indentation throughout; no triple backticks in skill file content

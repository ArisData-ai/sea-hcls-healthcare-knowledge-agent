---
name: human-in-the-loop-workflow
description: This skill defines the governed review layer behind the Healthcare Knowledge Agent's four human-in-the-loop screens - Knowledge Gap & Review Queue, Content Review Detail, Compliance & Protocol Oversight, and the Cortex Agent Conversational Panel - including the review queue table, decision write-back, and automated escalation. Use this skill for any task involving knowledge gap queue population, review decision recording, escalation logic, reassignment, priority/risk scoring for the queue, or the guardrails that keep every content-status change a human decision.
---

# Human-in-the-Loop Workflow — Skill

## Overview

This is the governed decision layer the rest of the agent feeds into. Every query the confidence-plus-currency gate declines to answer, and every document that ages past its review window, lands in one place: a prioritized queue a person works through. The agent's role stops at raising the flag and gathering context — deciding what changes about a document is always a human action recorded through the Content Review Detail screen.

**Key outcome:** no `CURATED_TBL_DOCUMENTS`, `CURATED_TBL_CLINICAL_PROTOCOLS`, or `CURATED_TBL_COMPLIANCE_FINDINGS` status field is ever written by a Task, a Stream, or the Cortex Agent. Those writes only happen through a human-submitted decision.

## When to Use

Use this skill for any task involving:

- Designing or modifying `HITL_TBL_REVIEW_QUEUE` or `HITL_TBL_REVIEW_DECISIONS`
- Wiring the routed-query insert trigger from `tier1-query-resolution.md`
- Building the scheduled sweep that catches overdue/stale items not yet queued
- Priority/risk scoring for the queue's sort order
- Escalation logic (Compliance & Protocol Oversight) and reassignment
- Write-back logic from a review decision to the curated content tables

## Instructions

### Review Queue Table

    CREATE OR REPLACE TABLE HITL_TBL_REVIEW_QUEUE (
        QUEUE_ID             VARCHAR(100)  NOT NULL DEFAULT UUID_STRING() PRIMARY KEY,
        TRIGGER_TYPE          VARCHAR(30)   NOT NULL,  -- QUERY_GAP / OVERDUE_REVIEW /
                                                        -- STALE_CONTENT / KNOWN_GAP
        DOC_REF_KEY            VARCHAR(100),            -- nullable: a pure query gap may
                                                        -- have no matching document at all
        SOURCE_QUERY_ID         NUMBER,                  -- FK to CURATED_TBL_KNOWLEDGE_QUERIES
        TRIGGERING_QUERY_TEXT   VARCHAR(500),
        REASON_CODE             VARCHAR(30),             -- NO_MATCH / WEAK_MATCH /
                                                        -- STALE_SOURCE / KNOWN_GAP
        RISK_LEVEL               VARCHAR(20)   NOT NULL,  -- Critical / High / Medium / Low
        STATUS                    VARCHAR(30)   NOT NULL DEFAULT 'Open',  -- Open / In Review /
                                                                          -- Escalated / Closed
        ASSIGNED_OWNER            VARCHAR(200),
        ESCALATED_FLAG            BOOLEAN       DEFAULT FALSE,
        ESCALATION_REASON         VARCHAR(200),
        CREATED_AT                TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        LAST_UPDATED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    )
    DATA_RETENTION_TIME_IN_DAYS = 0;

    CREATE OR REPLACE TABLE HITL_TBL_REVIEW_DECISIONS (
        DECISION_ID    VARCHAR(100)  NOT NULL DEFAULT UUID_STRING() PRIMARY KEY,
        QUEUE_ID        VARCHAR(100)  NOT NULL,   -- FK to HITL_TBL_REVIEW_QUEUE
        DOC_REF_KEY      VARCHAR(100),
        DECISION          VARCHAR(30)   NOT NULL,   -- No Change / Minor Update /
                                                    -- Major Revision / Retired
        DECISION_NOTES    VARCHAR(1000),
        DECIDED_BY         VARCHAR(200)  NOT NULL DEFAULT CURRENT_USER(),
        DECIDED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        CONSTRAINT FK_DECISION_QUEUE FOREIGN KEY (QUEUE_ID)
            REFERENCES HITL_TBL_REVIEW_QUEUE (QUEUE_ID)
    )
    DATA_RETENTION_TIME_IN_DAYS = 0;

`HITL_TBL_REVIEW_DECISIONS` is append-only. A document's history of decisions is never overwritten — each review cycle adds a new row.

### Populating the Queue: Two Independent Triggers

**Trigger A — event-driven, from Tier 1.** Every query the gate marks `ROUTED` (see `tier1-query-resolution.md`) inserts a queue row directly at query time, `TRIGGER_TYPE = 'QUERY_GAP'`, carrying the original question and the gate's `reason_code`.

**Trigger B — scheduled sweep, independent of query volume.** A document can go stale without anyone ever asking about it. A daily task catches those:

    CREATE OR REPLACE TASK TASK_REFRESH_GAP_QUEUE
        WAREHOUSE = WH_HCLS_XS
        SCHEDULE = 'USING CRON 0 6 * * * UTC'
    AS
        INSERT INTO HITL_TBL_REVIEW_QUEUE
            (TRIGGER_TYPE, DOC_REF_KEY, REASON_CODE, RISK_LEVEL, STATUS, ASSIGNED_OWNER)
        SELECT
            CASE
                WHEN COVERAGE_HEALTH = 'Gap Detected' THEN 'KNOWN_GAP'
                WHEN REVIEW_STATUS = 'Overdue'         THEN 'OVERDUE_REVIEW'
                WHEN COVERAGE_HEALTH = 'Stale'          THEN 'STALE_CONTENT'
            END,
            DOC_REF_KEY,
            COVERAGE_HEALTH,
            CASE WHEN REVIEW_STATUS = 'Overdue' AND COVERAGE_HEALTH = 'Gap Detected'
                 THEN 'Critical' ELSE 'High' END,
            'Open',
            NULL
        FROM CURATED_VW_KNOWLEDGE_COVERAGE_MATRIX
        WHERE (COVERAGE_HEALTH IN ('Stale', 'Gap Detected') OR REVIEW_STATUS = 'Overdue')
          AND DOC_REF_KEY NOT IN (
              SELECT DOC_REF_KEY FROM HITL_TBL_REVIEW_QUEUE
              WHERE STATUS != 'Closed' AND DOC_REF_KEY IS NOT NULL
          );

    ALTER TASK TASK_REFRESH_GAP_QUEUE RESUME;

The `NOT IN (... STATUS != 'Closed' ...)` guard is what stops the sweep from re-queuing an item that's already open — the queue accumulates unique open work, it doesn't duplicate it every morning.

### Priority View (backs the Knowledge Gap & Review Queue screen)

    CREATE OR REPLACE VIEW HITL_VW_REVIEW_QUEUE_PRIORITIZED AS
    SELECT
        q.*,
        DATEDIFF('day', q.CREATED_AT, CURRENT_TIMESTAMP()) AS AGE_DAYS,
        d.DOC_TITLE, d.CONTENT_DOMAIN, d.OWNING_DEPARTMENT
    FROM HITL_TBL_REVIEW_QUEUE q
    LEFT JOIN CURATED_TBL_DOCUMENTS d ON q.DOC_REF_KEY = d.DOC_REF_KEY
    WHERE q.STATUS != 'Closed'
    ORDER BY
        CASE q.RISK_LEVEL WHEN 'Critical' THEN 1 WHEN 'High' THEN 2
                           WHEN 'Medium' THEN 3 ELSE 4 END,
        AGE_DAYS DESC;

### Content Review Detail: Decision Write-Back

This is the only path in the entire system permitted to change a document's governance status. It runs as a single transaction when a content owner submits a decision:

    BEGIN;

    INSERT INTO HITL_TBL_REVIEW_DECISIONS (QUEUE_ID, DOC_REF_KEY, DECISION, DECISION_NOTES)
    VALUES (:queue_id, :doc_ref_key, :decision, :notes);

    UPDATE CURATED_TBL_DOCUMENTS
    SET STATUS = CASE WHEN :decision = 'Retired' THEN 'Archived' ELSE STATUS END,
        LAST_REVIEWED_DATE = CURRENT_DATE(),
        NEXT_REVIEW_DATE = CASE WHEN :decision != 'Retired'
                                 THEN DATEADD('month', 6, CURRENT_DATE())
                                 ELSE NEXT_REVIEW_DATE END
    WHERE DOC_REF_KEY = :doc_ref_key;

    UPDATE HITL_TBL_REVIEW_QUEUE
    SET STATUS = 'Closed', LAST_UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE QUEUE_ID = :queue_id;

    COMMIT;

Every field in this block is bound from the Streamlit form (see `streamlit-dashboard-development.md`); nothing here is ever assembled from free-text string concatenation.

### Escalation (Compliance & Protocol Oversight)

Items don't sit with one owner indefinitely. A daily task promotes stalled or high-severity items:

    CREATE OR REPLACE TASK TASK_ESCALATE_STALE_REVIEWS
        WAREHOUSE = WH_HCLS_XS
        AFTER TASK_REFRESH_GAP_QUEUE
    AS
        UPDATE HITL_TBL_REVIEW_QUEUE q
        SET ESCALATED_FLAG = TRUE,
            STATUS = 'Escalated',
            ESCALATION_REASON = CASE
                WHEN DATEDIFF('day', q.CREATED_AT, CURRENT_TIMESTAMP()) > 14
                    THEN 'Unresolved beyond 14 days'
                ELSE 'Linked to Critical/High compliance finding'
            END
        FROM CURATED_VW_COMPLIANCE_GAP_SUMMARY c
        WHERE q.STATUS = 'Open'
          AND (
              DATEDIFF('day', q.CREATED_AT, CURRENT_TIMESTAMP()) > 14
              OR (q.DOC_REF_KEY IS NOT NULL AND c.SEVERITY IN ('Critical', 'High')
                  AND c.OPEN_FINDINGS > 0)
          );

    ALTER TASK TASK_ESCALATE_STALE_REVIEWS RESUME;

    CREATE OR REPLACE VIEW HITL_VW_ESCALATIONS AS
    SELECT * FROM HITL_TBL_REVIEW_QUEUE WHERE ESCALATED_FLAG = TRUE AND STATUS != 'Closed';

Reassignment updates only `ASSIGNED_OWNER` and clears `STATUS` back to `'Open'` (or leaves it `'Escalated'` if the compliance lead wants it to stay visible); it flows back into the same Content Review Detail screen with a new owner attached — there is no separate decision screen for escalated items.

### Orchestration: This Skill's Tasks Join the Ingestion Chain

`TASK_REFRESH_GAP_QUEUE` and `TASK_ESCALATE_STALE_REVIEWS` complete the single pipeline described in `knowledge-ingestion-and-indexing.md`: ingestion Tasks keep the corpus current, these Tasks keep the review queue current, and neither requires manual execution once resumed. See `snowflake-knowledge-platform.md` for the full task-graph view.

### Coverage-Health Feedback Loop

`CURATED_VW_KNOWLEDGE_COVERAGE_MATRIX` already classifies documents as `Healthy`, `Stale`, `Gap Detected`, or `Unused` based on review recency and query-hit history. A closed review decision changes `LAST_REVIEWED_DATE` on the underlying document, which is what moves it out of `Stale` on the next view refresh — the human decision is the only thing that improves the score; no Task ever touches `COVERAGE_HEALTH` directly, because it's derived, not stored.

## Coding Conventions

- `HITL_` prefix on every object in this skill; never write to `CURATED_TBL_*` status/date fields from anywhere except the decision write-back transaction above
- `HITL_TBL_REVIEW_DECISIONS` is append-only — no `UPDATE` or `DELETE` permitted, ever
- Every queue insert must carry a non-null `RISK_LEVEL`; never default it silently to `'Low'`
- Escalation thresholds (14 days, severity tiers) belong in `KA_CONFIG`, not hardcoded in the task body, once that table is extended (see `snowflake-knowledge-platform.md`)
- The decision write-back transaction is the single most security-sensitive object in the project — any change to it requires review by whoever owns `healthcare-knowledge-governance.md`
- Use 4-space indentation throughout; no triple backticks in skill file content

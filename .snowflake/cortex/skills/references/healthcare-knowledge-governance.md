---
name: healthcare-knowledge-governance
description: This skill defines the access control, content classification, and audit lineage layer for the Healthcare Knowledge Agent, covering Snowflake Horizon sensitivity tagging, row access policies scoped to the four human-in-the-loop screens, RBAC for content owners, compliance/quality leads, clinicians, and executives, and Data Sharing governance for cross-organizational knowledge distribution. Use this skill for any task involving role design for the review screens, row access policy setup on curated or HITL tables, audit trail generation, or data sharing governance for the knowledge base.
---

# Healthcare Knowledge — Governance

## Overview

This skill governs access control and audit lineage across both layers of the agent: the document/content layer (`KA_*`, `CURATED_TBL_*`) and the human-in-the-loop review layer (`HITL_TBL_*`). The two layers need different access models — content is scoped by department/facility, review work is scoped by ownership and escalation status — and this skill keeps them from being conflated into one over-broad role.

Apply this skill before enabling knowledge base sharing, before granting anyone Content Review Detail write access, and whenever a new role or partner sharing relationship is introduced.

## When to Use

Activate this skill when:

- Granting a new content owner, compliance lead, clinician, or executive access
- Setting up row access policies on `CURATED_TBL_*` or `HITL_TBL_*` tables
- Configuring Data Sharing for partner distribution
- Generating audit reports for content or review access
- Responding to a compliance inquiry about who could have changed a document's status and when

## Instructions

### RBAC Role Configuration

All roles are functional sub-roles beneath the base implementation role `ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE`, scoped to `DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE`.

| Role                           | Persona                      | Access Scope                                                                                                                                                                                                   | Screens                                                                              |
| ------------------------------ | ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `ROLE_HK_ADMIN`                | Platform admin               | Full access to all objects; only role that can modify Tasks/Streams                                                                                                                                            | All                                                                                  |
| `ROLE_HK_CONTENT_OWNER`        | Content/protocol owners      | `SELECT` on document content; `SELECT`/`INSERT` on `HITL_TBL_REVIEW_DECISIONS` restricted by row access to their own assigned queue items; `UPDATE` on `HITL_TBL_REVIEW_QUEUE.STATUS` for their own items only | Knowledge Gap & Review Queue; Content Review Detail                                  |
| `ROLE_HK_COMPLIANCE_LEAD`      | Quality / compliance leads   | Everything `ROLE_HK_CONTENT_OWNER` has, plus `UPDATE` on `HITL_TBL_REVIEW_QUEUE.ASSIGNED_OWNER` for any row (reassignment), `SELECT` on compliance findings and fine-exposure views                            | Knowledge Gap & Review Queue; Content Review Detail; Compliance & Protocol Oversight |
| `ROLE_HK_CLINICIAN_VIEWER`     | Care team / query submitters | `SELECT` on approved, current content only, via `KA_RESOLVE_QUERY`; no review-queue access at all                                                                                                              | Query intake only (no screen)                                                        |
| `ROLE_HK_CORTEX_AGENT_ANALYST` | Cortex Agent's Analyst tool  | `SELECT` only on `SV_HEALTHCARE_KNOWLEDGE_OPS`; no other grant of any kind                                                                                                                                     | Cortex Agent Conversational Panel                                                    |
| `ROLE_HK_EXEC_VIEWER`          | CDO / executives             | `SELECT` on coverage, compliance, and resolution dashboards; no content-level or review-decision access                                                                                                        | Compliance & Protocol Oversight (read-only); Cortex Agent Conversational Panel       |

    CREATE ROLE IF NOT EXISTS ROLE_HK_ADMIN;
    CREATE ROLE IF NOT EXISTS ROLE_HK_CONTENT_OWNER;
    CREATE ROLE IF NOT EXISTS ROLE_HK_COMPLIANCE_LEAD;
    CREATE ROLE IF NOT EXISTS ROLE_HK_CLINICIAN_VIEWER;
    CREATE ROLE IF NOT EXISTS ROLE_HK_CORTEX_AGENT_ANALYST;
    CREATE ROLE IF NOT EXISTS ROLE_HK_EXEC_VIEWER;

    GRANT ROLE ROLE_HK_CONTENT_OWNER TO ROLE ROLE_HK_COMPLIANCE_LEAD;
    GRANT ROLE ROLE_HK_COMPLIANCE_LEAD TO ROLE ROLE_HK_ADMIN;

    GRANT USAGE ON DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS TO ROLE ROLE_HK_CONTENT_OWNER;
    GRANT USAGE ON SCHEMA DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE TO ROLE ROLE_HK_CONTENT_OWNER;
    GRANT SELECT, INSERT ON TABLE HITL_TBL_REVIEW_DECISIONS TO ROLE ROLE_HK_CONTENT_OWNER;
    GRANT SELECT, UPDATE ON TABLE HITL_TBL_REVIEW_QUEUE TO ROLE ROLE_HK_CONTENT_OWNER;
    GRANT SELECT ON TABLE CURATED_TBL_DOCUMENTS TO ROLE ROLE_HK_CONTENT_OWNER;
    GRANT UPDATE ON TABLE CURATED_TBL_DOCUMENTS TO ROLE ROLE_HK_CONTENT_OWNER;

    -- Compliance lead: adds reassignment and oversight visibility
    GRANT SELECT ON VIEW HITL_VW_ESCALATIONS TO ROLE ROLE_HK_COMPLIANCE_LEAD;
    GRANT SELECT ON VIEW CURATED_VW_COMPLIANCE_GAP_SUMMARY TO ROLE ROLE_HK_COMPLIANCE_LEAD;

    -- Cortex Agent Analyst tool: read-only, one object, nothing else
    GRANT USAGE ON SCHEMA DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;
    GRANT SELECT ON SEMANTIC VIEW SV_HEALTHCARE_KNOWLEDGE_OPS TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;

### Row Access Policy — Review Queue Ownership Scoping

    CREATE OR REPLACE ROW ACCESS POLICY HITL_RAP_OWNER_SCOPED
        AS (assigned_owner VARCHAR, escalated_flag BOOLEAN) RETURNS BOOLEAN ->
            CURRENT_ROLE() IN ('ROLE_HK_ADMIN', 'ROLE_HK_COMPLIANCE_LEAD')
            OR assigned_owner = CURRENT_USER()
            OR (assigned_owner IS NULL AND escalated_flag = FALSE);

    ALTER TABLE HITL_TBL_REVIEW_QUEUE
        ADD ROW ACCESS POLICY HITL_RAP_OWNER_SCOPED ON (ASSIGNED_OWNER, ESCALATED_FLAG);

A content owner sees their own assigned items plus unassigned open items (so the queue is still browsable before anyone claims something); only compliance leads and admins see everything, including escalated items belonging to someone else.

### Content Sensitivity Classification

    CREATE OR REPLACE TAG SCHEMA_HEALTHCARE_KNOWLEDGE.KA_TAG_CONTENT_SENSITIVITY
        ALLOWED_VALUES 'RESTRICTED', 'CONFIDENTIAL', 'INTERNAL', 'PUBLIC';

    ALTER TABLE CURATED_TBL_DOCUMENTS
        SET TAG KA_TAG_CONTENT_SENSITIVITY = 'INTERNAL';
    ALTER TABLE CURATED_TBL_COMPLIANCE_FINDINGS
        SET TAG KA_TAG_CONTENT_SENSITIVITY = 'CONFIDENTIAL';
    ALTER TABLE HITL_TBL_REVIEW_DECISIONS
        SET TAG KA_TAG_CONTENT_SENSITIVITY = 'CONFIDENTIAL';

### Review & Retrieval Audit Log

Extend the retrieval audit pattern to also cover human decisions — one append-only table, two event types:

    CREATE OR REPLACE TABLE KA_ACCESS_AUDIT_LOG (
        AUDIT_ID           VARCHAR       DEFAULT UUID_STRING() PRIMARY KEY,
        EVENT_TYPE          VARCHAR(30)   NOT NULL,   -- QUERY_RETRIEVAL / REVIEW_DECISION / REASSIGNMENT
        REFERENCE_ID         VARCHAR,                  -- QUERY_ID or QUEUE_ID or DECISION_ID
        CONTENT_DOMAIN        VARCHAR,
        ACCESSING_ROLE          VARCHAR       DEFAULT CURRENT_ROLE(),
        SESSION_USER             VARCHAR       DEFAULT SESSION_USER(),
        EVENT_DETAIL               VARIANT,
        EVENT_AT                     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

Every Content Review Detail submission and every reassignment writes here, alongside every Tier 1 query. This is the single table a compliance inquiry gets pointed at.

### Data Sharing — Partner Knowledge Distribution

    CREATE OR REPLACE SECURE VIEW SHARE_VW_PARTNER_KNOWLEDGE AS
    SELECT DOC_REF_KEY, DOC_TITLE, CONTENT_DOMAIN, STATUS, PUBLISHED_DATE, NEXT_REVIEW_DATE
    FROM CURATED_TBL_DOCUMENTS
    WHERE STATUS = 'Active';

    CREATE OR REPLACE SHARE HK_PARTNER_KNOWLEDGE_SHARE;
    GRANT USAGE ON DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS TO SHARE HK_PARTNER_KNOWLEDGE_SHARE;
    GRANT SELECT ON VIEW SHARE_VW_PARTNER_KNOWLEDGE TO SHARE HK_PARTNER_KNOWLEDGE_SHARE;

Never share `RESTRICTED` or `CONFIDENTIAL`-tagged content, and never share `HITL_TBL_*` objects — review-queue and decision data stays internal even when document content is shared with partners.

## Coding Conventions

- Role names must match exactly: `ROLE_HK_ADMIN`, `ROLE_HK_CONTENT_OWNER`, `ROLE_HK_COMPLIANCE_LEAD`, `ROLE_HK_CLINICIAN_VIEWER`, `ROLE_HK_CORTEX_AGENT_ANALYST`, `ROLE_HK_EXEC_VIEWER`
- `KA_ACCESS_AUDIT_LOG` is append-only; no `UPDATE` or `DELETE` permitted
- `ROLE_HK_CORTEX_AGENT_ANALYST` must never receive a grant beyond `SELECT` on the semantic view — treat any pull request that adds one as a governance incident, not a normal review comment
- Row access policy logic lives in the policy body; never hardcode a specific username or owner value there
- Fully qualified three-part naming for every object reference
- Use 4-space indentation throughout; no triple backticks in skill file content

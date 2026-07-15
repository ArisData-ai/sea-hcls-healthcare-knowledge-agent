-- Create the append-only audit log table for tracking all access and decision events.
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- KA_ACCESS_AUDIT_LOG — Append-Only Audit Trail
--
-- Captures three event types:
--   QUERY_RETRIEVAL  — Tier 1 knowledge query resolution
--   REVIEW_DECISION  — Human review decision submission
--   REASSIGNMENT     — Queue item reassigned to a different owner
--
-- CRITICAL: This table is append-only. No UPDATE or DELETE will ever be issued
--           against it. Any script that modifies or removes rows is a
--           governance incident.
--
-- Note: Wiring actual INSERTs from Tier 1 query resolution and from the
--       Phase 6 decision write-back is out of scope for this phase — it
--       happens when those respective files are built/revisited.
--
-- Best practice: SYSADMIN owns the schema and creates tables within it.
--------------------------------------------------------------------------------

USE ROLE SYSADMIN;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;

CREATE TABLE IF NOT EXISTS DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.KA_ACCESS_AUDIT_LOG (
    AUDIT_ID        VARCHAR       DEFAULT UUID_STRING()    NOT NULL PRIMARY KEY,
    EVENT_TYPE      VARCHAR(30)   NOT NULL,
    REFERENCE_ID    VARCHAR,
    CONTENT_DOMAIN  VARCHAR,
    ACCESSING_ROLE  VARCHAR       DEFAULT CURRENT_ROLE(),
    EVENT_USER      VARCHAR       DEFAULT CURRENT_USER(),
    EVENT_DETAIL    VARIANT,
    EVENT_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Add comment to reinforce append-only contract
COMMENT ON TABLE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.KA_ACCESS_AUDIT_LOG IS
    'Append-only audit log. No UPDATE or DELETE permitted. Tracks QUERY_RETRIEVAL, REVIEW_DECISION, and REASSIGNMENT events.';

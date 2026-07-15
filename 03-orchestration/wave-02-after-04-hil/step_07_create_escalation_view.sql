-- Creates HITL_VW_ESCALATIONS: the view Phase 6 Compliance & Protocol Oversight screen will query
-- Co-authored with CoCo

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.ANALYTICS;

-- =============================================================================
-- HITL_VW_ESCALATIONS
-- Surfaces all escalated, non-closed review items. This is the exact view the
-- Compliance & Protocol Oversight screen queries in Phase 6 — do not rename
-- its output columns without coordinating with that phase.
-- =============================================================================

CREATE OR REPLACE VIEW HITL_VW_ESCALATIONS AS
SELECT
    QUEUE_ID,
    TRIGGER_TYPE,
    DOC_REF_KEY,
    SOURCE_QUERY_ID,
    TRIGGERING_QUERY_TEXT,
    REASON_CODE,
    RISK_LEVEL,
    STATUS,
    ASSIGNED_OWNER,
    ESCALATED_FLAG,
    ESCALATION_REASON,
    CREATED_AT,
    LAST_UPDATED_AT
FROM CURATED.HITL_TBL_REVIEW_QUEUE
WHERE ESCALATED_FLAG = TRUE
  AND STATUS != 'Closed';

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SELECT COUNT(*) AS ESCALATED_ITEMS FROM HITL_VW_ESCALATIONS;
-- Expected: 0 (no items have been escalated yet)

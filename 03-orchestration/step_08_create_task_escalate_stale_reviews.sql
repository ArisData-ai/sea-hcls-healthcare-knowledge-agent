-- Creates TASK_ESCALATE_STALE_REVIEWS: promotes stalled or high-severity items to escalated status
-- Co-authored with CoCo

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

-- =============================================================================
-- TASK_ESCALATE_STALE_REVIEWS
-- Runs AFTER TASK_REFRESH_GAP_QUEUE.
-- Escalates open review items that either:
--   (a) have aged beyond KA_CONFIG.escalation_age_days, OR
--   (b) are linked to a DOC_REF_KEY where the system has open Critical/High
--       compliance findings (per CURATED_VW_COMPLIANCE_GAP_SUMMARY).
-- Sets ESCALATED_FLAG = TRUE, STATUS = 'Escalated', and records the reason.
-- Created SUSPENDED — resumed in step_09.
-- =============================================================================

CREATE OR REPLACE TASK TASK_ESCALATE_STALE_REVIEWS
    WAREHOUSE = WH_HCLS_XS
    AFTER TASK_REFRESH_GAP_QUEUE
AS
    UPDATE HITL_TBL_REVIEW_QUEUE
    SET
        ESCALATED_FLAG    = TRUE,
        STATUS            = 'Escalated',
        ESCALATION_REASON = CASE
            WHEN DATEDIFF('day', CREATED_AT, CURRENT_TIMESTAMP()) >
                 (SELECT CONFIG_VALUE::INT FROM KA_CONFIG WHERE CONFIG_KEY = 'escalation_age_days')
             AND EXISTS (
                 SELECT 1 FROM CURATED_VW_COMPLIANCE_GAP_SUMMARY
                 WHERE SEVERITY IN ('Critical', 'High') AND OPEN_FINDINGS > 0
             )
            THEN 'AGE_AND_COMPLIANCE_RISK'
            WHEN DATEDIFF('day', CREATED_AT, CURRENT_TIMESTAMP()) >
                 (SELECT CONFIG_VALUE::INT FROM KA_CONFIG WHERE CONFIG_KEY = 'escalation_age_days')
            THEN 'AGE_THRESHOLD_EXCEEDED'
            ELSE 'LINKED_COMPLIANCE_RISK'
        END,
        LAST_UPDATED_AT   = CURRENT_TIMESTAMP()
    WHERE STATUS = 'Open'
      AND (
          DATEDIFF('day', CREATED_AT, CURRENT_TIMESTAMP()) >
              (SELECT CONFIG_VALUE::INT FROM KA_CONFIG WHERE CONFIG_KEY = 'escalation_age_days')
          OR EXISTS (
              SELECT 1 FROM CURATED_VW_COMPLIANCE_GAP_SUMMARY
              WHERE SEVERITY IN ('Critical', 'High') AND OPEN_FINDINGS > 0
          )
      );

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SHOW TASKS LIKE 'TASK_ESCALATE_STALE_REVIEWS';
-- Expected: one row, state = suspended, predecessors includes TASK_REFRESH_GAP_QUEUE

-- Creates TASK_REFRESH_GAP_QUEUE: scheduled sweep inserting stale/gap/overdue docs into the review queue
-- Co-authored with CoCo

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
-- USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

-- =============================================================================
-- TASK_REFRESH_GAP_QUEUE
-- Reads schedule from KA_CONFIG.gap_queue_sweep_schedule via scripting block.
-- Inserts into HITL_TBL_REVIEW_QUEUE from CURATED_VW_KNOWLEDGE_COVERAGE_MATRIX
-- for documents classified as Gap Detected, Overdue, or Stale.
-- Excludes DOC_REF_KEY values already open in the queue (prevents duplicates).
-- Created SUSPENDED — resumed in step_09.
-- =============================================================================

DECLARE
    v_schedule VARCHAR;
    v_sql      VARCHAR;
BEGIN
    SELECT CONFIG_VALUE INTO :v_schedule
    FROM SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CONFIG.KA_CONFIG
    WHERE CONFIG_KEY = 'gap_queue_sweep_schedule';

    v_sql := '
        CREATE OR REPLACE TASK TASK_REFRESH_GAP_QUEUE
            WAREHOUSE = SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH
            SCHEDULE  = ''' || v_schedule || '''
        AS
            INSERT INTO CURATED.HITL_TBL_REVIEW_QUEUE
                (TRIGGER_TYPE, DOC_REF_KEY, REASON_CODE, RISK_LEVEL, STATUS, ASSIGNED_OWNER)
            SELECT
                CASE
                    WHEN COVERAGE_HEALTH = ''Gap Detected'' THEN ''KNOWN_GAP''
                    WHEN REVIEW_STATUS   = ''Overdue''      THEN ''OVERDUE_REVIEW''
                    WHEN COVERAGE_HEALTH = ''Stale''        THEN ''STALE_CONTENT''
                END,
                DOC_REF_KEY,
                COVERAGE_HEALTH,
                CASE
                    WHEN REVIEW_STATUS = ''Overdue'' AND COVERAGE_HEALTH = ''Gap Detected''
                        THEN ''Critical''
                    ELSE ''High''
                END,
                ''Open'',
                NULL
            FROM ANALYTICS.ANALYTICS_VW_KNOWLEDGE_COVERAGE_MATRIX
            WHERE (COVERAGE_HEALTH IN (''Stale'', ''Gap Detected'') OR REVIEW_STATUS = ''Overdue'')
              AND DOC_REF_KEY NOT IN (
                  SELECT DOC_REF_KEY FROM HITL_TBL_REVIEW_QUEUE
                  WHERE STATUS != ''Closed'' AND DOC_REF_KEY IS NOT NULL
              )';

    EXECUTE IMMEDIATE v_sql;
END;

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SHOW TASKS LIKE 'TASK_REFRESH_GAP_QUEUE';

-- Expected: one row, state = suspended, schedule = 'USING CRON 0 6 * * * UTC'

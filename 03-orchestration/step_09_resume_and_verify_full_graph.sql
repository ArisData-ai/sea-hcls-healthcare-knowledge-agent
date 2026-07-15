-- Resumes and executes the Gap Queue & Escalation task graph (child-first pattern)
-- Co-authored with CoCo

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

-- =============================================================================
-- TASK GRAPH: Gap Queue & Escalation Pipeline
--
--   TASK_REFRESH_GAP_QUEUE (root, daily at 06:00 UTC)
--       └── TASK_ESCALATE_STALE_REVIEWS (child, no condition)
--
-- Snowflake rules:
--   1. Resume children BEFORE their parent — parent resume commits graph version.
--   2. EXECUTE TASK is only valid on root tasks; children fire automatically.
-- =============================================================================

-- =============================================================================
-- STEP 1: DESCRIBE ALL TASKS
-- =============================================================================

DESCRIBE TASK TASK_REFRESH_GAP_QUEUE;
DESCRIBE TASK TASK_ESCALATE_STALE_REVIEWS;

-- =============================================================================
-- STEP 2: SUSPEND ROOT (required to re-commit graph version)
-- =============================================================================

ALTER TASK TASK_REFRESH_GAP_QUEUE SUSPEND;

-- =============================================================================
-- STEP 3: RESUME CHILD FIRST, THEN ROOT
-- =============================================================================

ALTER TASK TASK_ESCALATE_STALE_REVIEWS RESUME;
ALTER TASK TASK_REFRESH_GAP_QUEUE RESUME;

-- =============================================================================
-- STEP 4: VERIFY BOTH TASKS ARE STARTED
-- =============================================================================

SHOW TASKS LIKE 'TASK_REFRESH_GAP_QUEUE' IN SCHEMA;
SHOW TASKS LIKE 'TASK_ESCALATE_STALE_REVIEWS' IN SCHEMA;

-- =============================================================================
-- STEP 5: VERIFY DEPENDENCY GRAPH
-- Expected: TASK_ESCALATE_STALE_REVIEWS appears as a dependent
-- =============================================================================

SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_DEPENDENTS(
    TASK_NAME => 'TASK_REFRESH_GAP_QUEUE',
    RECURSIVE => TRUE
));

-- =============================================================================
-- STEP 6: EXECUTE ROOT TASK ONLY
-- Child fires automatically after root completes successfully.
-- =============================================================================

EXECUTE TASK TASK_REFRESH_GAP_QUEUE;

-- =============================================================================
-- STEP 7: VERIFY RESULTS (wait ~60 seconds for root + child to complete)
-- =============================================================================

SELECT COUNT(*) AS TOTAL_QUEUE_ITEMS,
       COUNT(DISTINCT DOC_REF_KEY) AS UNIQUE_DOCS,
       SUM(CASE WHEN ESCALATED_FLAG = TRUE THEN 1 ELSE 0 END) AS ESCALATED_COUNT
FROM HITL_TBL_REVIEW_QUEUE;

-- Expected: 5 rows (matching the dry-run results)
SELECT COUNT(*) AS ESCALATION_VIEW_ROWS FROM HITL_VW_ESCALATIONS;

-- =============================================================================
-- STEP 8: CONFIRM CHILD TASK RAN
-- Expected: TASK_ESCALATE_STALE_REVIEWS shows a SUCCEEDED run after the root
-- =============================================================================

SELECT NAME, STATE, GRAPH_VERSION, SCHEDULED_TIME, COMPLETED_TIME, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 10
))
WHERE NAME IN ('TASK_REFRESH_GAP_QUEUE', 'TASK_ESCALATE_STALE_REVIEWS')
ORDER BY SCHEDULED_TIME DESC;

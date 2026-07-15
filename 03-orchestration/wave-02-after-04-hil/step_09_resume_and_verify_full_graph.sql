-- Resumes and executes the Gap Queue & Escalation task graph (child-first pattern)
-- Co-authored with CoCo

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

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

-- [ PARENT TASK ]
DESCRIBE TASK TASK_REFRESH_GAP_QUEUE;

-- [ CHILD TASK ]
DESCRIBE TASK TASK_ESCALATE_STALE_REVIEWS;

-- =============================================================================
-- STEP 2: SUSPEND ROOT (required to re-commit graph version)
-- =============================================================================

-- SUSPENDING RULE:
-- PARENT TO CHILD

ALTER TASK TASK_REFRESH_GAP_QUEUE SUSPEND;

ALTER TASK TASK_ESCALATE_STALE_REVIEWS SUSPEND;

-- =============================================================================
-- STEP 3: RESUME CHILD FIRST, THEN ROOT
-- =============================================================================

-- RESUMING RULES
-- CHILD TO PARENT

-- [ CHILD TASK ]
ALTER TASK TASK_ESCALATE_STALE_REVIEWS RESUME;

-- [ PARENT TASK ]
ALTER TASK TASK_REFRESH_GAP_QUEUE RESUME;

-- =============================================================================
-- STEP 4: VERIFY BOTH TASKS ARE STARTED
-- =============================================================================

-- [ PARENT TASK ]
SHOW TASKS LIKE 'TASK_REFRESH_GAP_QUEUE' IN SCHEMA;

-- [ CHILD TASK ]
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

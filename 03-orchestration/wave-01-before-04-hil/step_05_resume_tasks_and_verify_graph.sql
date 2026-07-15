-- Step 5: Resume tasks (child before parent) and verify the task graph
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 5a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

----------------------------------------------------------------------
-- 5b. Resume tasks — child first, then root
----------------------------------------------------------------------

-- Parsing  happens First,
-- Chunking happens Later

-- [ CHILD TASK ]
ALTER TASK TASK_CHUNK_NEW_DOCS RESUME;

-- [ PARENT TASK ]
ALTER TASK TASK_PARSE_NEW_DOCS RESUME;

----------------------------------------------------------------------
-- 5c. Verification
----------------------------------------------------------------------
-- 1. Task graph: expect two rows showing the parent-child relationship
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_DEPENDENTS(
    TASK_NAME => 'TASK_PARSE_NEW_DOCS',
    RECURSIVE => TRUE
));

-- 2. Both tasks should show state = 'started'
SHOW TASKS LIKE 'TASK_PARSE_NEW_DOCS';
SHOW TASKS LIKE 'TASK_CHUNK_NEW_DOCS';
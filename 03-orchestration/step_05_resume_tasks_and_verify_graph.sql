-- Step 5: Resume tasks (child before parent) and verify the task graph
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 5a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 5b. Resume tasks — child first, then root
----------------------------------------------------------------------
ALTER TASK TASK_CHUNK_NEW_DOCS RESUME;
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

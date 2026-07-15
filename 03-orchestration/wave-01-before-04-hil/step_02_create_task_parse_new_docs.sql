-- Step 2: Create task to parse newly staged documents into KA_DOC_RAW
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 2a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

----------------------------------------------------------------------
-- 2b. Create parse task (SUSPENDED — resumed in step_05)
--     Polls every 10 minutes; fires only when new files appear in
--     STREAM_KA_DOC_STAGE_DIR. Inserts parsed text into KA_DOC_RAW.
----------------------------------------------------------------------
CREATE OR REPLACE TASK TASK_PARSE_NEW_DOCS
    WAREHOUSE = SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH
    SCHEDULE  = '10 MINUTE'
WHEN
    SYSTEM$STREAM_HAS_DATA('STREAM_KA_DOC_STAGE_DIR')
AS
    INSERT INTO KA_DOC_RAW (RELATIVE_PATH, RAW_TEXT, PARSE_STATUS)
    WITH PARSED AS (
        SELECT
            LTRIM(RELATIVE_PATH, '/') AS RELATIVE_PATH,
            SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                '@KA_DOC_STAGE',
                RELATIVE_PATH,
                {'mode': 'LAYOUT'}
            ):content::VARCHAR AS RAW_TEXT
        FROM STREAM_KA_DOC_STAGE_DIR
    )
    SELECT
        RELATIVE_PATH,
        RAW_TEXT,
        CASE
            WHEN RAW_TEXT IS NOT NULL AND LENGTH(RAW_TEXT) > 0 THEN 'SUCCESS'
            ELSE 'FAILED'
        END AS PARSE_STATUS
    FROM PARSED;

----------------------------------------------------------------------
-- 2c. Verification
----------------------------------------------------------------------
-- Expect one row: TASK_PARSE_NEW_DOCS, state = 'suspended', schedule = '10 MINUTE'
SHOW TASKS LIKE 'TASK_PARSE_NEW_DOCS';

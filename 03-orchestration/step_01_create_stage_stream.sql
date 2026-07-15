-- Step 1: Create directory stream on KA_DOC_STAGE to detect newly staged documents
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 1a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 1b. Create stream on stage directory
--     Fires when new files are added to KA_DOC_STAGE.
----------------------------------------------------------------------
CREATE OR REPLACE STREAM STREAM_KA_DOC_STAGE_DIR
    ON STAGE KA_DOC_STAGE;

----------------------------------------------------------------------
-- 1c. Verification
----------------------------------------------------------------------
-- Expect one row: STREAM_KA_DOC_STAGE_DIR, mode = DEFAULT, stale = false
SHOW STREAMS LIKE 'STREAM_KA_DOC_STAGE_DIR';

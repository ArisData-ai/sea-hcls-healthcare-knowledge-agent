-- Step 1: Create directory stream on KA_DOC_STAGE to detect newly staged documents
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 1a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

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

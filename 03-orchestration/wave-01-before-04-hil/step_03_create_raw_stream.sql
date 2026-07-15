-- Step 3: Create stream on KA_DOC_RAW to detect newly parsed documents
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 3a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

----------------------------------------------------------------------
-- 3b. Create stream on raw document table
--     Fires when TASK_PARSE_NEW_DOCS inserts new rows into KA_DOC_RAW.
----------------------------------------------------------------------
CREATE OR REPLACE STREAM STREAM_KA_DOC_RAW
    ON TABLE KA_DOC_RAW;

----------------------------------------------------------------------
-- 3c. Verification
----------------------------------------------------------------------
-- Expect one row: STREAM_KA_DOC_RAW, stale = false, source = KA_DOC_RAW
SHOW STREAMS LIKE 'STREAM_KA_DOC_RAW';

-- Step 3: Create stream on KA_DOC_RAW to detect newly parsed documents
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 3a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

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

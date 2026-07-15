-- Step 1: Set session context and create document/metadata stages
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 1a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;


----------------------------------------------------------------------
-- 1b. Create stages (internal, directory-enabled, SSE encryption)
----------------------------------------------------------------------
CREATE OR REPLACE STAGE KA_DOC_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE OR REPLACE STAGE KA_META_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

----------------------------------------------------------------------
-- 1c. Verification (run AFTER uploading files)
--     Expect 8 rows from KA_DOC_STAGE
----------------------------------------------------------------------
ALTER STAGE KA_DOC_STAGE REFRESH;
ALTER STAGE KA_META_STAGE REFRESH;

SELECT * FROM DIRECTORY(@KA_DOC_STAGE);

SELECT * FROM DIRECTORY(@KA_META_STAGE);

-- Step 1: Set session context and create document/metadata stages
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 1a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

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
SELECT * FROM DIRECTORY(@KA_DOC_STAGE);

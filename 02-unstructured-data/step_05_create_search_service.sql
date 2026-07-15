-- Step 5: Create KA_KNOWLEDGE_SEARCH Cortex Search Service
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 5a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 5b. Create Cortex Search Service on KA_DOC_CHUNKS
----------------------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE KA_KNOWLEDGE_SEARCH
    ON CHUNK_TEXT
    ATTRIBUTES DOC_ID, DOCUMENT_NAME, CONTENT_TYPE, DEPARTMENT_SCOPE, FACILITY_SCOPE, STATUS, EXPIRY_DATE
    WAREHOUSE = WH_HCLS_XS
    TARGET_LAG = '1 hour'
    AS (
        SELECT
            CHUNK_TEXT,
            DOC_ID,
            DOCUMENT_NAME,
            CONTENT_TYPE,
            DEPARTMENT_SCOPE,
            FACILITY_SCOPE,
            STATUS,
            EXPIRY_DATE
        FROM KA_DOC_CHUNKS
    );
    
----------------------------------------------------------------------
-- 5c. Verification
----------------------------------------------------------------------

-- Confirm the search service exists and is active
SHOW CORTEX SEARCH SERVICES;

-- Describe the service to verify columns and configuration
DESCRIBE CORTEX SEARCH SERVICE KA_KNOWLEDGE_SEARCH;
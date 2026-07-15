-- Step 5: Create KA_KNOWLEDGE_SEARCH Cortex Search Service
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 5a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.SEMANTICS;

----------------------------------------------------------------------
-- 5b. Create Cortex Search Service on KA_DOC_CHUNKS
----------------------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.SEMANTICS.KA_KNOWLEDGE_SEARCH
    ON CHUNK_TEXT
    ATTRIBUTES DOC_ID, DOCUMENT_NAME, CONTENT_TYPE, DEPARTMENT_SCOPE, FACILITY_SCOPE, STATUS, EXPIRY_DATE
    WAREHOUSE = SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH
    TARGET_LAG = '3 hour'
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
        FROM SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED.KA_DOC_CHUNKS
    );
    
----------------------------------------------------------------------
-- 5c. Verification
----------------------------------------------------------------------

-- Confirm the search service exists and is active
SHOW CORTEX SEARCH SERVICES;

-- Describe the service to verify columns and configuration
DESCRIBE CORTEX SEARCH SERVICE KA_KNOWLEDGE_SEARCH;
-- Step 6: Smoke tests - retrieval queries and governance gap queries
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 6a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 6b. RETRIEVAL TEST 1: MRSA contact precautions
--     Expect results from BOTH Main Campus and Community Hospital
----------------------------------------------------------------------
SELECT
    PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'KA_KNOWLEDGE_SEARCH',
            '{
                "query": "MRSA contact precautions",
                "columns": ["CHUNK_TEXT", "DOC_ID", "FACILITY_SCOPE", "CONTENT_TYPE"],
                "limit": 5
            }'
        )
    )['results'] AS MRSA_RESULTS;

----------------------------------------------------------------------
-- 6c. RETRIEVAL TEST 2: Sepsis first-hour bundle
----------------------------------------------------------------------
SELECT
    PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'KA_KNOWLEDGE_SEARCH',
            '{
                "query": "sepsis first hour bundle",
                "columns": ["CHUNK_TEXT", "DOC_ID", "FACILITY_SCOPE", "CONTENT_TYPE"],
                "limit": 5
            }'
        )
    )['results'] AS SEPSIS_RESULTS;

----------------------------------------------------------------------
-- 6d. RETRIEVAL TEST 3: DKA v2.0 potassium change
----------------------------------------------------------------------
SELECT
    PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'KA_KNOWLEDGE_SEARCH',
            '{
                "query": "DKA version 2.0 potassium protocol change",
                "columns": ["CHUNK_TEXT", "DOC_ID", "FACILITY_SCOPE", "CONTENT_TYPE"],
                "limit": 5
            }'
        )
    )['results'] AS DKA_RESULTS;

----------------------------------------------------------------------
-- 6e. GAP QUERY 1: Documents expired or past review date
--     (Plain SQL on KA_DOC_METADATA — NOT the search service)
----------------------------------------------------------------------
SELECT
    DOC_ID,
    DOCUMENT_NAME,
    STATUS,
    EXPIRY_DATE,
    REVIEW_DATE,
    DOCUMENT_OWNER,
    CASE
        WHEN STATUS = 'EXPIRED' THEN 'EXPIRED'
        WHEN EXPIRY_DATE < CURRENT_DATE() THEN 'PAST EXPIRY'
        WHEN REVIEW_DATE < CURRENT_DATE() THEN 'PAST REVIEW DATE'
    END AS GAP_REASON
FROM KA_DOC_METADATA
WHERE STATUS = 'EXPIRED'
   OR EXPIRY_DATE < CURRENT_DATE()
   OR REVIEW_DATE < CURRENT_DATE()
ORDER BY EXPIRY_DATE;

----------------------------------------------------------------------
-- 6f. GAP QUERY 2: Documents expiring within 30 days with owner
----------------------------------------------------------------------
SELECT
    DOC_ID,
    DOCUMENT_NAME,
    EXPIRY_DATE,
    DATEDIFF('day', CURRENT_DATE(), EXPIRY_DATE) AS DAYS_UNTIL_EXPIRY,
    DOCUMENT_OWNER,
    DEPARTMENT_SCOPE
FROM KA_DOC_METADATA
WHERE EXPIRY_DATE BETWEEN CURRENT_DATE() AND DATEADD('day', 30, CURRENT_DATE())
  AND STATUS != 'EXPIRED'
ORDER BY EXPIRY_DATE;

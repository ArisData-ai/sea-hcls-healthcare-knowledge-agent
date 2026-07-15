-- Step 3: Parse documents from KA_DOC_STAGE using AI_PARSE_DOCUMENT
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 3a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

----------------------------------------------------------------------
-- 3b. Create raw document table
----------------------------------------------------------------------
CREATE OR REPLACE TABLE KA_DOC_RAW (
    RELATIVE_PATH   VARCHAR(500)  NOT NULL,
    RAW_TEXT         VARCHAR(16777216),
    PARSE_STATUS    VARCHAR(20)
);

----------------------------------------------------------------------
-- 3c. Parse all documents from stage using AI_PARSE_DOCUMENT (LAYOUT)
--     Strip leading slash from RELATIVE_PATH for consistent joining.
----------------------------------------------------------------------
INSERT INTO KA_DOC_RAW (RELATIVE_PATH, RAW_TEXT, PARSE_STATUS)
WITH PARSED AS (
    SELECT
        LTRIM(RELATIVE_PATH, '/') AS RELATIVE_PATH,
        SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
            '@KA_DOC_STAGE',
            RELATIVE_PATH,
            {'mode': 'LAYOUT'}
        ):content::VARCHAR AS RAW_TEXT
    FROM DIRECTORY(@KA_DOC_STAGE)
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
-- 3d. Verification
----------------------------------------------------------------------
-- Expect 8 rows, all with PARSE_STATUS = 'SUCCESS' and non-empty RAW_TEXT
SELECT COUNT(*) AS TOTAL_ROWS,
       SUM(CASE WHEN PARSE_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) AS SUCCESS_COUNT,
       SUM(CASE WHEN PARSE_STATUS = 'FAILED' THEN 1 ELSE 0 END) AS FAILED_COUNT
FROM KA_DOC_RAW;

-- Quick preview: first 200 chars of each document
SELECT RELATIVE_PATH, PARSE_STATUS, LEFT(RAW_TEXT, 2000) AS TEXT_PREVIEW
FROM KA_DOC_RAW
ORDER BY RELATIVE_PATH;

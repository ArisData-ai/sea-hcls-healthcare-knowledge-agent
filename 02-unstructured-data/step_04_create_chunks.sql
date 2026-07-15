-- Step 4: Create KA_DOC_CHUNKS by splitting raw text and joining metadata
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 4a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 4b. Create chunks table
----------------------------------------------------------------------
CREATE OR REPLACE TABLE KA_DOC_CHUNKS (
    CHUNK_ID            VARCHAR(100)      NOT NULL,
    DOC_ID              VARCHAR(50)       NOT NULL,
    DOCUMENT_NAME       VARCHAR(500),
    RELATIVE_PATH       VARCHAR(500)      NOT NULL,
    CHUNK_INDEX         INT               NOT NULL,
    CHUNK_TEXT          VARCHAR(16777216) NOT NULL,
    CONTENT_TYPE        VARCHAR(100),
    DEPARTMENT_SCOPE    VARCHAR(200),
    FACILITY_SCOPE      VARCHAR(200),
    STATUS              VARCHAR(50),
    EFFECTIVE_DATE      DATE,
    EXPIRY_DATE         DATE
);
----------------------------------------------------------------------
-- 4c. Split raw text into chunks (~1800 chars, 300 overlap) and join metadata
----------------------------------------------------------------------

INSERT INTO KA_DOC_CHUNKS
SELECT
    m.DOC_ID || '-' || c.INDEX                AS CHUNK_ID,
    m.DOC_ID,
    m.DOCUMENT_NAME,
    r.RELATIVE_PATH,
    c.INDEX                                    AS CHUNK_INDEX,
    c.VALUE::VARCHAR                           AS CHUNK_TEXT,
    m.CONTENT_TYPE,
    m.DEPARTMENT_SCOPE,
    m.FACILITY_SCOPE,
    m.STATUS,
    m.EFFECTIVE_DATE,
    m.EXPIRY_DATE
FROM KA_DOC_RAW r
JOIN KA_DOC_METADATA m
    ON r.RELATIVE_PATH = m.RELATIVE_PATH,
LATERAL FLATTEN(
    INPUT => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
        r.RAW_TEXT,
        'markdown',
        1800,
        300
    )
) c;

----------------------------------------------------------------------
-- 4d. Verification
----------------------------------------------------------------------
-- All 8 doc_ids present, each with >= 1 chunk
SELECT
    m.DOC_ID,
    m.DOCUMENT_NAME,
    COUNT(c.CHUNK_ID) AS CHUNK_COUNT
FROM KA_DOC_METADATA m
LEFT JOIN KA_DOC_CHUNKS c ON m.DOC_ID = c.DOC_ID
GROUP BY m.DOC_ID, m.DOCUMENT_NAME
ORDER BY m.DOC_ID;
-- Total chunk count
SELECT COUNT(*) AS TOTAL_CHUNKS FROM KA_DOC_CHUNKS;
-- Step 4: Create task to chunk newly parsed documents into KA_DOC_CHUNKS
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 4a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 4b. Create chunk task (SUSPENDED — resumed in step_05)
--     Chained AFTER TASK_PARSE_NEW_DOCS; fires only when
--     STREAM_KA_DOC_RAW has new inserts. Reads chunk_size_chars and
--     chunk_overlap_chars from KA_CONFIG (not hardcoded).
----------------------------------------------------------------------
CREATE OR REPLACE TASK TASK_CHUNK_NEW_DOCS
    WAREHOUSE = WH_HCLS_XS
    AFTER TASK_PARSE_NEW_DOCS
WHEN
    SYSTEM$STREAM_HAS_DATA('STREAM_KA_DOC_RAW')
AS
    INSERT INTO KA_DOC_CHUNKS
    WITH CONFIG AS (
        SELECT
            MAX(CASE WHEN CONFIG_KEY = 'chunk_size_chars'    THEN CONFIG_VALUE::INT END) AS CHUNK_SIZE,
            MAX(CASE WHEN CONFIG_KEY = 'chunk_overlap_chars' THEN CONFIG_VALUE::INT END) AS CHUNK_OVERLAP
        FROM KA_CONFIG
        WHERE CONFIG_KEY IN ('chunk_size_chars', 'chunk_overlap_chars')
    )
    SELECT
        m.DOC_ID || '-' || c.INDEX      AS CHUNK_ID,
        m.DOC_ID,
        m.DOCUMENT_NAME,
        r.RELATIVE_PATH,
        c.INDEX                          AS CHUNK_INDEX,
        c.VALUE::VARCHAR                 AS CHUNK_TEXT,
        m.CONTENT_TYPE,
        m.DEPARTMENT_SCOPE,
        m.FACILITY_SCOPE,
        m.STATUS,
        m.EFFECTIVE_DATE,
        m.EXPIRY_DATE
    FROM STREAM_KA_DOC_RAW r
    JOIN KA_DOC_METADATA m
        ON r.RELATIVE_PATH = m.RELATIVE_PATH
    CROSS JOIN CONFIG cfg
    , LATERAL FLATTEN(
        INPUT => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
            r.RAW_TEXT,
            'markdown',
            cfg.CHUNK_SIZE,
            cfg.CHUNK_OVERLAP
        )
    ) c
    WHERE r.METADATA$ACTION = 'INSERT';

----------------------------------------------------------------------
-- 4c. Verification
----------------------------------------------------------------------
-- Expect one row: TASK_CHUNK_NEW_DOCS, state = 'suspended',
-- predecessor = TASK_PARSE_NEW_DOCS
SHOW TASKS LIKE 'TASK_CHUNK_NEW_DOCS';

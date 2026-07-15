-- Step 2: Create KA_DOC_METADATA table and load corpus_metadata.csv
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 2a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 2b. Create metadata table
----------------------------------------------------------------------
CREATE OR REPLACE TABLE KA_DOC_METADATA (
    DOC_ID              VARCHAR(50)   NOT NULL,
    DOCUMENT_NAME       VARCHAR(500)  NOT NULL,
    RELATIVE_PATH       VARCHAR(500)  NOT NULL,
    CONTENT_TYPE        VARCHAR(100),
    FACILITY_SCOPE      VARCHAR(200),
    DEPARTMENT_SCOPE    VARCHAR(200),
    VERSION             VARCHAR(20),
    EFFECTIVE_DATE      DATE,
    EXPIRY_DATE         DATE,
    REVIEW_DATE         DATE,
    SUPERSEDED_DATE     DATE,
    STATUS              VARCHAR(50),
    DOCUMENT_OWNER      VARCHAR(200),
    SOURCE_SYSTEM       VARCHAR(100)
);

----------------------------------------------------------------------
-- 2c. Load CSV from KA_META_STAGE
----------------------------------------------------------------------
COPY INTO KA_DOC_METADATA
FROM @KA_META_STAGE/corpus_metadata.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('', 'NULL')
);

----------------------------------------------------------------------
-- 2d. Verification queries
----------------------------------------------------------------------
-- Expect 8 rows
SELECT COUNT(*) AS ROW_COUNT FROM KA_DOC_METADATA;

-- REG-004 should have status = 'EXPIRED'
SELECT DOC_ID, DOCUMENT_NAME, STATUS
FROM KA_DOC_METADATA
WHERE DOC_ID = 'REG-004';

-- REG-002 expiry_date should be within ~3 weeks of today
SELECT DOC_ID, DOCUMENT_NAME, EXPIRY_DATE,
       DATEDIFF('day', CURRENT_DATE(), EXPIRY_DATE) AS DAYS_UNTIL_EXPIRY
FROM KA_DOC_METADATA
WHERE DOC_ID = 'REG-002';

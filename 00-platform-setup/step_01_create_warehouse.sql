-- Create the XS warehouse for Healthcare Knowledge Agent workloads (idempotent)
-- Co-authored with CoCo

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;

CREATE WAREHOUSE IF NOT EXISTS WH_HCLS_XS
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Healthcare Knowledge Agent - retrieval, indexing, and review workloads';

-- Verification: confirm warehouse exists and inspect current settings
SHOW WAREHOUSES LIKE 'WH_HCLS_XS';
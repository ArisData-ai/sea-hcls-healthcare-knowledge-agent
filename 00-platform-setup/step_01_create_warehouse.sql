-- Create the XS warehouse for Healthcare Knowledge Agent workloads (idempotent)
-- Co-authored with CoCo

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;

CREATE WAREHOUSE IF NOT EXISTS SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Healthcare Knowledge Agent - retrieval, indexing, and review workloads';

-- Verification: confirm warehouse exists and inspect current settings
SHOW WAREHOUSES LIKE 'SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH';
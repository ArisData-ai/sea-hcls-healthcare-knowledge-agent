-- Step 1: Create the HITL review queue table that backs the Knowledge Gap & Review Queue screen
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 1a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

----------------------------------------------------------------------
-- 1b. Create HITL_TBL_REVIEW_QUEUE
--     Central queue for all human-review triggers: query gaps, overdue
--     reviews, stale content, and known coverage gaps. Every row
--     represents one actionable item a content owner must resolve.
----------------------------------------------------------------------
CREATE OR REPLACE TABLE HITL_TBL_REVIEW_QUEUE (
    QUEUE_ID              VARCHAR(100)    NOT NULL DEFAULT UUID_STRING() PRIMARY KEY,
    TRIGGER_TYPE          VARCHAR(30)     NOT NULL,
        -- QUERY_GAP / OVERDUE_REVIEW / STALE_CONTENT / KNOWN_GAP
    DOC_REF_KEY           VARCHAR(100),
        -- nullable: a pure query gap may have no matching document
    SOURCE_QUERY_ID       NUMBER,
        -- FK to CURATED_TBL_KNOWLEDGE_QUERIES
    TRIGGERING_QUERY_TEXT VARCHAR(500),
    REASON_CODE           VARCHAR(30),
        -- NO_MATCH / WEAK_MATCH / STALE_SOURCE / KNOWN_GAP
    RISK_LEVEL            VARCHAR(20)     NOT NULL,
        -- Critical / High / Medium / Low
    STATUS                VARCHAR(30)     NOT NULL DEFAULT 'Open',
        -- Open / In Review / Escalated / Closed
    ASSIGNED_OWNER        VARCHAR(200),
    ESCALATED_FLAG        BOOLEAN         DEFAULT FALSE,
    ESCALATION_REASON     VARCHAR(200),
    CREATED_AT            TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    LAST_UPDATED_AT       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
DATA_RETENTION_TIME_IN_DAYS = 0;

----------------------------------------------------------------------
-- 1c. Verification
----------------------------------------------------------------------
-- Expect: one row showing HITL_TBL_REVIEW_QUEUE with 12 columns,
--         kind = TABLE, retention_time = 0
DESCRIBE TABLE HITL_TBL_REVIEW_QUEUE;

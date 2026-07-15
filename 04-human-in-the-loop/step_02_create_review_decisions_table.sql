-- Step 2: Create the append-only review decisions table for audit trail of human judgments
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 2a. Session context
----------------------------------------------------------------------
USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.CURATED;

----------------------------------------------------------------------
-- 2b. Create HITL_TBL_REVIEW_DECISIONS
--     Append-only ledger: every decision a reviewer makes against a
--     queue item is recorded here. No UPDATE or DELETE will ever be
--     issued against this table by any phase of the project.
----------------------------------------------------------------------
CREATE OR REPLACE TABLE HITL_TBL_REVIEW_DECISIONS (
    DECISION_ID     VARCHAR(100)    NOT NULL DEFAULT UUID_STRING() PRIMARY KEY,
    QUEUE_ID        VARCHAR(100)    NOT NULL,
        -- FK to HITL_TBL_REVIEW_QUEUE.QUEUE_ID
    DOC_REF_KEY     VARCHAR(100),
    DECISION        VARCHAR(30)     NOT NULL,
        -- No Change / Minor Update / Major Revision / Retired
    DECISION_NOTES  VARCHAR(1000),
    DECIDED_BY      VARCHAR(200)    DEFAULT CURRENT_USER(),
    DECIDED_AT      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT FK_DECISIONS_QUEUE
        FOREIGN KEY (QUEUE_ID) REFERENCES HITL_TBL_REVIEW_QUEUE (QUEUE_ID)
)
DATA_RETENTION_TIME_IN_DAYS = 0;

----------------------------------------------------------------------
-- 2c. Verification
----------------------------------------------------------------------
-- Expect: 7 rows (one per column: DECISION_ID through DECIDED_AT)
DESCRIBE TABLE HITL_TBL_REVIEW_DECISIONS;

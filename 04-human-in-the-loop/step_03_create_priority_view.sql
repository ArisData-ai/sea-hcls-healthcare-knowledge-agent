-- Step 3: Create prioritized review queue view for the Knowledge Gap & Review Queue screen
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 3a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 3b. Create HITL_VW_REVIEW_QUEUE_PRIORITIZED
--     This is the exact view the Phase 6 Streamlit screen will query.
--     It enriches queue rows with document metadata, computes age, and
--     applies a deterministic priority sort: risk level first (Critical
--     > High > Medium > Low), then oldest items surface next.
----------------------------------------------------------------------
CREATE OR REPLACE VIEW HITL_VW_REVIEW_QUEUE_PRIORITIZED AS
SELECT
    q.QUEUE_ID,
    q.TRIGGER_TYPE,
    q.DOC_REF_KEY,
    d.DOC_TITLE,
    d.CONTENT_DOMAIN,
    d.OWNING_DEPARTMENT,
    q.SOURCE_QUERY_ID,
    q.TRIGGERING_QUERY_TEXT,
    q.REASON_CODE,
    q.RISK_LEVEL,
    q.STATUS,
    q.ASSIGNED_OWNER,
    q.ESCALATED_FLAG,
    q.ESCALATION_REASON,
    DATEDIFF('day', q.CREATED_AT, CURRENT_TIMESTAMP()) AS AGE_DAYS,
    q.CREATED_AT,
    q.LAST_UPDATED_AT
FROM HITL_TBL_REVIEW_QUEUE q
LEFT JOIN CURATED_TBL_DOCUMENTS d
    ON q.DOC_REF_KEY = d.DOC_REF_KEY
WHERE q.STATUS != 'Closed'
ORDER BY
    CASE q.RISK_LEVEL
        WHEN 'Critical' THEN 1
        WHEN 'High'     THEN 2
        WHEN 'Medium'   THEN 3
        WHEN 'Low'      THEN 4
        ELSE 5
    END,
    AGE_DAYS DESC;

----------------------------------------------------------------------
-- 3c. Verification
----------------------------------------------------------------------
-- Expect: 17 columns listed (QUEUE_ID through LAST_UPDATED_AT including
-- DOC_TITLE, CONTENT_DOMAIN, OWNING_DEPARTMENT, AGE_DAYS).
-- Zero rows returned since the queue is empty — that's correct at this step.
DESCRIBE VIEW HITL_VW_REVIEW_QUEUE_PRIORITIZED;

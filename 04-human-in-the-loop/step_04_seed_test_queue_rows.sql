-- Step 4: Seed the review queue with synthetic rows to exercise the Phase 6 dashboard
-- Co-authored with CoCo

----------------------------------------------------------------------
-- 4a. Session context
----------------------------------------------------------------------
USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

----------------------------------------------------------------------
-- 4b. Insert synthetic review-queue items
--     Covers all four TRIGGER_TYPEs and all four RISK_LEVELs.
--     DOC_REF_KEYs reference real rows in CURATED_TBL_DOCUMENTS.
--     CREATED_AT values are staggered so AGE_DAYS ordering is testable.
----------------------------------------------------------------------
INSERT INTO HITL_TBL_REVIEW_QUEUE
    (TRIGGER_TYPE, DOC_REF_KEY, SOURCE_QUERY_ID, TRIGGERING_QUERY_TEXT,
     REASON_CODE, RISK_LEVEL, STATUS, ASSIGNED_OWNER, CREATED_AT, LAST_UPDATED_AT)
VALUES
    -- 1. Critical / QUERY_GAP — no doc matches a sepsis-related query
    ('QUERY_GAP', NULL, 1,
     'What is our protocol for pediatric sepsis in the NICU?',
     'NO_MATCH', 'Critical', 'Open', NULL,
     DATEADD('day', -14, CURRENT_TIMESTAMP()),
     DATEADD('day', -14, CURRENT_TIMESTAMP())),

    -- 2. High / OVERDUE_REVIEW — SSI bundle overdue since 2024-04-10
    ('OVERDUE_REVIEW', 'DOC-018', NULL, NULL,
     'STALE_SOURCE', 'High', 'Open', 'Surgical Services',
     DATEADD('day', -9, CURRENT_TIMESTAMP()),
     DATEADD('day', -9, CURRENT_TIMESTAMP())),

    -- 3. High / STALE_CONTENT — anticoagulation protocol weak match
    ('STALE_CONTENT', 'DOC-016', 5,
     'Latest DOAC reversal guidance for emergency surgery patients',
     'WEAK_MATCH', 'High', 'In Review', 'Pharmacy',
     DATEADD('day', -6, CURRENT_TIMESTAMP()),
     DATEADD('day', -3, CURRENT_TIMESTAMP())),

    -- 4. Medium / KNOWN_GAP — no behavioral-health crisis de-escalation doc
    ('KNOWN_GAP', NULL, NULL,
     'Behavioral health crisis de-escalation procedures',
     'NO_MATCH', 'Medium', 'Open', NULL,
     DATEADD('day', -4, CURRENT_TIMESTAMP()),
     DATEADD('day', -4, CURRENT_TIMESTAMP())),

    -- 5. Medium / QUERY_GAP — contrast reaction in pediatric patients
    ('QUERY_GAP', 'DOC-022', 8,
     'Contrast reaction management for pediatric patients under 12',
     'WEAK_MATCH', 'Medium', 'Open', 'Radiology',
     DATEADD('day', -2, CURRENT_TIMESTAMP()),
     DATEADD('day', -2, CURRENT_TIMESTAMP())),

    -- 6. Low / OVERDUE_REVIEW — remote-work policy approaching review
    ('OVERDUE_REVIEW', 'DOC-015', NULL, NULL,
     'STALE_SOURCE', 'Low', 'Open', 'IT Security',
     DATEADD('day', -1, CURRENT_TIMESTAMP()),
     DATEADD('day', -1, CURRENT_TIMESTAMP()));

----------------------------------------------------------------------
-- 4c. Verification
----------------------------------------------------------------------
-- Expect: 6 rows returned, ordered Critical first (AGE_DAYS 14),
-- then High (AGE_DAYS 9, 6), then Medium (AGE_DAYS 4, 2),
-- then Low (AGE_DAYS 1). DOC_TITLE populated for rows with a
-- DOC_REF_KEY, NULL for the two pure query-gap rows.
SELECT QUEUE_ID, TRIGGER_TYPE, RISK_LEVEL, DOC_TITLE,
       CONTENT_DOMAIN, STATUS, AGE_DAYS
FROM HITL_VW_REVIEW_QUEUE_PRIORITIZED;

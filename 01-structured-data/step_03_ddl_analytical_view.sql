-- =============================================================================
-- SECTION 3 : CURATED VIEWS (VW_)
-- Four analytical views that compute derived metrics over the base tables.
-- These are standard views — no additional storage cost.
-- =============================================================================

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.ANALYTICS;

-- ----------------------------------------------------------------------------
-- 3.1  ANALYTICS_VW_PROTOCOL_CURRENCY
--      Classifies every clinical protocol by age and freshness status,
--      computing days since last review and days until next review is due.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS_VW_PROTOCOL_CURRENCY AS
SELECT
    p.PROTOCOL_ID,
    p.PROTOCOL_CODE,
    p.PROTOCOL_NAME,
    p.CLINICAL_CATEGORY,
    p.APPLICABLE_CARE_SETTING,
    p.OWNING_SPECIALTY,
    p.STATUS,
    p.COMPLIANCE_RISK_LEVEL,
    p.REGULATORY_STANDARD,
    p.CURRENT_VERSION,
    p.VERSION_EFFECTIVE_DATE,
    p.LAST_REVIEWED_DATE,
    p.NEXT_REVIEW_DUE_DATE,
    p.AVERAGE_ADHERENCE_PCT,
    p.TOTAL_REVISIONS,
    DATEDIFF('day', p.LAST_REVIEWED_DATE, CURRENT_DATE())    AS DAYS_SINCE_LAST_REVIEW,
    DATEDIFF('day', CURRENT_DATE(), p.NEXT_REVIEW_DUE_DATE)  AS DAYS_UNTIL_NEXT_REVIEW,
    CASE
        WHEN p.NEXT_REVIEW_DUE_DATE < CURRENT_DATE()                         THEN 'Overdue'
        WHEN p.NEXT_REVIEW_DUE_DATE BETWEEN CURRENT_DATE()
             AND DATEADD('day', 60, CURRENT_DATE())                           THEN 'Due Soon'
        WHEN p.STATUS = 'Under Review'                                        THEN 'In Review'
        ELSE 'Current'
    END                                                       AS FRESHNESS_STATUS,
    CASE
        WHEN p.AVERAGE_ADHERENCE_PCT >= 90 THEN 'High'
        WHEN p.AVERAGE_ADHERENCE_PCT >= 75 THEN 'Medium'
        ELSE 'Low'
    END                                                       AS ADHERENCE_TIER,
    d.DOC_TITLE                                               AS LINKED_DOCUMENT_TITLE,
    d.SOURCE_SYSTEM                                           AS DOCUMENT_SOURCE
FROM CURATED.CURATED_TBL_CLINICAL_PROTOCOLS p
LEFT JOIN CURATED.CURATED_TBL_DOCUMENTS d
    ON p.LINKED_DOC_REF_KEY = d.DOC_REF_KEY;


-- ----------------------------------------------------------------------------
-- 3.2  ANALYTICS_VW_COMPLIANCE_GAP_SUMMARY
--      Aggregates compliance findings by regulation body, requirement, and
--      severity; surfaces open risk exposure in USD and count.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS_VW_COMPLIANCE_GAP_SUMMARY AS
SELECT
    r.REGULATION_BODY,
    r.REGULATION_NAME,
    r.REQUIREMENT_CODE,
    r.REQUIREMENT_TITLE,
    r.REQUIREMENT_CATEGORY,
    r.APPLICABLE_ORG_TYPE,
    r.ENFORCEMENT_LEVEL,
    f.SEVERITY,
    COUNT(*)                                                  AS TOTAL_FINDINGS,
    SUM(CASE WHEN f.REMEDIATION_STATUS IN ('Open', 'In Progress') THEN 1 ELSE 0 END)
                                                              AS OPEN_FINDINGS,
    SUM(CASE WHEN f.REMEDIATION_STATUS = 'Resolved' THEN 1 ELSE 0 END)
                                                              AS RESOLVED_FINDINGS,
    SUM(CASE WHEN f.REMEDIATION_STATUS IN ('Open', 'In Progress')
             THEN f.ESTIMATED_FINE_EXPOSURE ELSE 0 END)       AS OPEN_FINE_EXPOSURE_USD,
    SUM(f.ESTIMATED_FINE_EXPOSURE)                            AS TOTAL_FINE_EXPOSURE_USD,
    AVG(CASE WHEN f.RESOLVED_DATE IS NOT NULL
             THEN DATEDIFF('day', f.FINDING_DATE, f.RESOLVED_DATE)
             ELSE NULL END)                                   AS AVG_DAYS_TO_RESOLVE,
    MAX(f.FINDING_DATE)                                       AS MOST_RECENT_FINDING_DATE,
    MIN(f.REMEDIATION_DUE_DATE)                               AS EARLIEST_OPEN_DUE_DATE
FROM CURATED.CURATED_TBL_COMPLIANCE_FINDINGS f
JOIN CURATED.CURATED_TBL_REGULATORY_REQUIREMENTS r
    ON f.REQUIREMENT_ID = r.REQUIREMENT_ID
GROUP BY ALL;


-- ----------------------------------------------------------------------------
-- 3.3  ANALYTICS_VW_QUERY_RESOLUTION_METRICS
--      Computes query resolution KPIs by persona, org type, content domain,
--      and month — the operational health layer of the Knowledge Agent.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS_VW_QUERY_RESOLUTION_METRICS AS
SELECT
    DATE_TRUNC('month', q.QUERY_DATE)                         AS QUERY_MONTH,
    q.ROLE_CODE,
    sr.ROLE_DISPLAY_NAME,
    sr.PERSONA_CATEGORY,
    q.ORG_TYPE,
    q.QUERY_CATEGORY,
    COUNT(*)                                                  AS TOTAL_QUERIES,
    SUM(CASE WHEN q.RESOLUTION_CHANNEL = 'Cortex Search' THEN 1 ELSE 0 END)
                                                              AS RESOLVED_BY_AGENT,
    SUM(CASE WHEN q.RESOLUTION_CHANNEL = 'Manual Lookup'  THEN 1 ELSE 0 END)
                                                              AS REQUIRED_MANUAL_LOOKUP,
    SUM(CASE WHEN q.RESOLUTION_CHANNEL = 'Unresolved'     THEN 1 ELSE 0 END)
                                                              AS UNRESOLVED,
    SUM(CASE WHEN q.WAS_KNOWLEDGE_GAP = TRUE THEN 1 ELSE 0 END)
                                                              AS KNOWLEDGE_GAP_QUERIES,
    SUM(CASE WHEN q.ESCALATED_FLAG = TRUE THEN 1 ELSE 0 END)
                                                              AS ESCALATED_QUERIES,
    ROUND(
        SUM(CASE WHEN q.RESOLUTION_CHANNEL = 'Cortex Search' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 1)                             AS AGENT_RESOLUTION_RATE_PCT,
    AVG(CASE WHEN q.RESOLUTION_CHANNEL = 'Cortex Search'
             THEN q.TIME_TO_RESOLUTION_MIN ELSE NULL END)     AS AVG_AGENT_RESOLUTION_MIN,
    AVG(CASE WHEN q.RESOLUTION_CHANNEL = 'Manual Lookup'
             THEN q.TIME_TO_RESOLUTION_MIN ELSE NULL END)     AS AVG_MANUAL_RESOLUTION_MIN,
    AVG(q.SATISFACTION_SCORE)                                 AS AVG_SATISFACTION_SCORE,
    ROUND(
        SUM(CASE WHEN q.ANSWER_CONFIDENCE = 'High' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 1)                             AS HIGH_CONFIDENCE_PCT
FROM CURATED.CURATED_TBL_KNOWLEDGE_QUERIES q
JOIN CURATED.CURATED_TBL_STAFF_ROLES sr
    ON q.ROLE_CODE = sr.ROLE_CODE
GROUP BY ALL;


-- ----------------------------------------------------------------------------
-- 3.4  ANALYTICS_VW_KNOWLEDGE_COVERAGE_MATRIX
--      Maps every document in the knowledge base to its content health:
--      recency, coverage completeness, query demand, and gap status.
--      Feeds the Knowledge Gap Detection capability of the agent.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS_VW_KNOWLEDGE_COVERAGE_MATRIX AS
SELECT
    d.DOC_REF_KEY,
    d.DOC_TITLE,
    d.DOC_TYPE,
    d.CONTENT_DOMAIN,
    d.ORG_TYPE_TARGET,
    d.SOURCE_SYSTEM,
    d.STATUS                                                  AS DOCUMENT_STATUS,
    d.VERSION_LABEL,
    d.PUBLISHED_DATE,
    d.LAST_REVIEWED_DATE,
    d.NEXT_REVIEW_DATE,
    DATEDIFF('day', d.LAST_REVIEWED_DATE, CURRENT_DATE())    AS DAYS_SINCE_REVIEW,
    CASE
        WHEN d.STATUS = 'Archived'                            THEN 'Archived'
        WHEN d.NEXT_REVIEW_DATE < CURRENT_DATE()              THEN 'Overdue'
        WHEN d.NEXT_REVIEW_DATE BETWEEN CURRENT_DATE()
             AND DATEADD('day', 90, CURRENT_DATE())           THEN 'Due Soon'
        ELSE 'Current'
    END                                                       AS REVIEW_STATUS,
    COUNT(q.QUERY_ID)                                         AS TOTAL_QUERY_HITS,
    SUM(CASE WHEN q.ANSWER_CONFIDENCE IN ('High', 'Medium') THEN 1 ELSE 0 END)
                                                              AS CONFIDENT_ANSWER_COUNT,
    SUM(CASE WHEN q.WAS_KNOWLEDGE_GAP = TRUE THEN 1 ELSE 0 END)
                                                              AS QUERY_GAPS_FLAGGED,
    AVG(q.SATISFACTION_SCORE)                                 AS AVG_SATISFACTION,
    MAX(q.QUERY_DATE)                                         AS LAST_QUERIED_DATE,
    CASE
        WHEN COUNT(q.QUERY_ID) = 0                            THEN 'Unused'
        WHEN AVG(q.SATISFACTION_SCORE) < 3
             OR SUM(q.WAS_KNOWLEDGE_GAP::INT) > 0             THEN 'Gap Detected'
        WHEN d.NEXT_REVIEW_DATE < CURRENT_DATE()              THEN 'Stale'
        ELSE 'Healthy'
    END                                                       AS COVERAGE_HEALTH
FROM CURATED.CURATED_TBL_DOCUMENTS d
LEFT JOIN CURATED.CURATED_TBL_KNOWLEDGE_QUERIES q
    ON d.DOC_REF_KEY = q.RESOLVED_DOC_REF_KEY
GROUP BY ALL;
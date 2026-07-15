-- Semantic view and underlying analytical view for the Healthcare Knowledge Cortex Agent
-- Co-authored with CoCo
-- =============================================================================
-- SECTION 4 : AI_BI SEMANTIC VIEW
-- The single semantic layer consumed by Cortex Analyst.
-- Joins all curated views into one business-friendly, wide fact surface.
-- Business terms are used as column aliases; technical keys are excluded.
-- =============================================================================

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
-- USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.ANALYTICS;

CREATE OR REPLACE VIEW SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.ANALYTICS.AI_BI_VW_SEMANTIC_KNOWLEDGE_OPS AS

WITH MONTHLY_QUERY_METRICS AS (
    SELECT
        QUERY_MONTH,
        ORG_TYPE,
        QUERY_CATEGORY,
        PERSONA_CATEGORY,
        SUM(TOTAL_QUERIES)              AS TOTAL_QUERIES,
        SUM(RESOLVED_BY_AGENT)          AS QUERIES_RESOLVED_BY_AGENT,
        SUM(REQUIRED_MANUAL_LOOKUP)     AS QUERIES_REQUIRING_MANUAL_LOOKUP,
        SUM(UNRESOLVED)                 AS UNRESOLVED_QUERIES,
        SUM(KNOWLEDGE_GAP_QUERIES)      AS KNOWLEDGE_GAP_QUERIES,
        SUM(ESCALATED_QUERIES)          AS ESCALATED_QUERIES,
        ROUND(AVG(AGENT_RESOLUTION_RATE_PCT), 1)    AS AVG_AGENT_RESOLUTION_RATE_PCT,
        ROUND(AVG(AVG_AGENT_RESOLUTION_MIN), 2)     AS AVG_AGENT_RESOLUTION_TIME_MIN,
        ROUND(AVG(AVG_MANUAL_RESOLUTION_MIN), 2)    AS AVG_MANUAL_RESOLUTION_TIME_MIN,
        ROUND(AVG(AVG_SATISFACTION_SCORE), 2)       AS AVG_SATISFACTION_SCORE,
        ROUND(AVG(HIGH_CONFIDENCE_PCT), 1)          AS HIGH_CONFIDENCE_ANSWER_RATE_PCT
    FROM ANALYTICS_VW_QUERY_RESOLUTION_METRICS
    GROUP BY ALL
)

SELECT
    -- Time dimension
    mqm.QUERY_MONTH                                           AS REPORTING_MONTH,

    -- Audience dimension
    mqm.ORG_TYPE                                              AS ORGANISATION_TYPE,
    mqm.PERSONA_CATEGORY                                      AS USER_PERSONA_CATEGORY,
    mqm.QUERY_CATEGORY                                        AS QUERY_CONTENT_DOMAIN,

    -- Knowledge Agent throughput metrics
    mqm.TOTAL_QUERIES                                         AS TOTAL_KNOWLEDGE_QUERIES,
    mqm.QUERIES_RESOLVED_BY_AGENT                             AS QUERIES_RESOLVED_BY_AGENT,
    mqm.QUERIES_REQUIRING_MANUAL_LOOKUP                       AS QUERIES_REQUIRING_MANUAL_LOOKUP,
    mqm.UNRESOLVED_QUERIES                                    AS UNRESOLVED_QUERIES,
    mqm.KNOWLEDGE_GAP_QUERIES                                 AS QUERIES_WITH_KNOWLEDGE_GAPS,
    mqm.ESCALATED_QUERIES                                     AS QUERIES_ESCALATED,
    mqm.AVG_AGENT_RESOLUTION_RATE_PCT                         AS AGENT_SELF_RESOLUTION_RATE_PCT,
    mqm.AVG_AGENT_RESOLUTION_TIME_MIN                         AS AVG_AGENT_RESOLUTION_TIME_MINUTES,
    mqm.AVG_MANUAL_RESOLUTION_TIME_MIN                        AS AVG_MANUAL_RESOLUTION_TIME_MINUTES,
    mqm.AVG_SATISFACTION_SCORE                                AS AVERAGE_USER_SATISFACTION_SCORE,
    mqm.HIGH_CONFIDENCE_ANSWER_RATE_PCT                       AS HIGH_CONFIDENCE_ANSWER_RATE_PCT,

    -- Protocol health snapshot (org-type filtered aggregate)
    prot_agg.TOTAL_ACTIVE_PROTOCOLS,
    prot_agg.OVERDUE_PROTOCOLS,
    prot_agg.DUE_SOON_PROTOCOLS,
    prot_agg.HIGH_RISK_PROTOCOLS,
    prot_agg.AVG_PROTOCOL_ADHERENCE_PCT,
    prot_agg.LOW_ADHERENCE_PROTOCOLS,

    -- Compliance gap snapshot (org-type filtered aggregate)
    comp_agg.TOTAL_OPEN_FINDINGS,
    comp_agg.CRITICAL_HIGH_OPEN_FINDINGS,
    comp_agg.OPEN_FINE_EXPOSURE_USD,
    comp_agg.REGULATIONS_WITH_OPEN_FINDINGS,

    -- Knowledge base coverage snapshot (org-type filtered aggregate)
    cov_agg.TOTAL_DOCUMENTS_IN_KNOWLEDGE_BASE,
    cov_agg.HEALTHY_DOCUMENTS,
    cov_agg.STALE_DOCUMENTS,
    cov_agg.OVERDUE_REVIEW_DOCUMENTS,
    cov_agg.DOCUMENTS_WITH_GAP_DETECTED,
    cov_agg.UNUSED_DOCUMENTS

FROM MONTHLY_QUERY_METRICS mqm

-- Protocol health aggregate per org type
LEFT JOIN (
    SELECT
        CASE
            WHEN APPLICABLE_CARE_SETTING IN ('ICU', 'ED', 'ED/Inpatient', 'Inpatient', 'OR/Inpatient', 'Labor & Delivery', 'Pediatric Units', 'Psych Units')
                THEN 'Health System'
            ELSE 'Health System'   -- All protocols belong to Health System in this corpus
        END                                                   AS ORG_TYPE,
        COUNT(*)                                              AS TOTAL_ACTIVE_PROTOCOLS,
        SUM(CASE WHEN FRESHNESS_STATUS = 'Overdue'  THEN 1 ELSE 0 END) AS OVERDUE_PROTOCOLS,
        SUM(CASE WHEN FRESHNESS_STATUS = 'Due Soon' THEN 1 ELSE 0 END) AS DUE_SOON_PROTOCOLS,
        SUM(CASE WHEN COMPLIANCE_RISK_LEVEL = 'High' THEN 1 ELSE 0 END) AS HIGH_RISK_PROTOCOLS,
        ROUND(AVG(AVERAGE_ADHERENCE_PCT), 1)                  AS AVG_PROTOCOL_ADHERENCE_PCT,
        SUM(CASE WHEN ADHERENCE_TIER = 'Low' THEN 1 ELSE 0 END) AS LOW_ADHERENCE_PROTOCOLS
    FROM ANALYTICS_VW_PROTOCOL_CURRENCY
    WHERE STATUS IN ('Active', 'Under Review')
    GROUP BY ALL
) prot_agg ON mqm.ORG_TYPE = prot_agg.ORG_TYPE

-- Compliance gap aggregate per org type
LEFT JOIN (
    SELECT
        APPLICABLE_ORG_TYPE                                   AS ORG_TYPE,
        SUM(OPEN_FINDINGS)                                    AS TOTAL_OPEN_FINDINGS,
        SUM(CASE WHEN SEVERITY IN ('Critical', 'High')
                 THEN OPEN_FINDINGS ELSE 0 END)               AS CRITICAL_HIGH_OPEN_FINDINGS,
        SUM(OPEN_FINE_EXPOSURE_USD)                           AS OPEN_FINE_EXPOSURE_USD,
        COUNT(DISTINCT REGULATION_BODY)                       AS REGULATIONS_WITH_OPEN_FINDINGS
    FROM ANALYTICS_VW_COMPLIANCE_GAP_SUMMARY
    WHERE OPEN_FINDINGS > 0
    GROUP BY ALL
) comp_agg ON mqm.ORG_TYPE = comp_agg.ORG_TYPE

-- Knowledge base coverage aggregate per org type
LEFT JOIN (
    SELECT
        ORG_TYPE_TARGET                                       AS ORG_TYPE,
        COUNT(*)                                              AS TOTAL_DOCUMENTS_IN_KNOWLEDGE_BASE,
        SUM(CASE WHEN COVERAGE_HEALTH = 'Healthy'         THEN 1 ELSE 0 END) AS HEALTHY_DOCUMENTS,
        SUM(CASE WHEN COVERAGE_HEALTH = 'Stale'           THEN 1 ELSE 0 END) AS STALE_DOCUMENTS,
        SUM(CASE WHEN REVIEW_STATUS   = 'Overdue'         THEN 1 ELSE 0 END) AS OVERDUE_REVIEW_DOCUMENTS,
        SUM(CASE WHEN COVERAGE_HEALTH = 'Gap Detected'    THEN 1 ELSE 0 END) AS DOCUMENTS_WITH_GAP_DETECTED,
        SUM(CASE WHEN COVERAGE_HEALTH = 'Unused'          THEN 1 ELSE 0 END) AS UNUSED_DOCUMENTS
    FROM ANALYTICS_VW_KNOWLEDGE_COVERAGE_MATRIX
    GROUP BY ALL
) cov_agg ON mqm.ORG_TYPE = cov_agg.ORG_TYPE

ORDER BY mqm.QUERY_MONTH DESC, mqm.ORG_TYPE, mqm.PERSONA_CATEGORY;


-- =============================================================================
-- SECTION 4B : SEMANTIC VIEW FOR CORTEX AGENT
-- Defines business-friendly dimensions, facts, and metrics over the base view.
-- This is what the Cortex Agent queries via natural language.
-- =============================================================================

-- =============================================================================
-- SECTION 4B : SEMANTIC VIEW FOR CORTEX AGENT
-- Snowflake CREATE SEMANTIC VIEW syntax (GA as of 2025):
--   - No inline COMMENT or WITH SYNONYMS clauses on individual columns
--   - SYNONYMS and COMMENTS are YAML semantic model attributes, not DDL
--   - DIMENSIONS = columns used as GROUP BY / filter axes
--   - FACTS = raw numeric columns available for ad-hoc aggregation
--   - METRICS = named, pre-aggregated expressions
--   - Table alias is declared in the TABLES block, referenced via alias.col
-- =============================================================================

-- =============================================================================
-- SV_HEALTHCARE_KNOWLEDGE_OPS — Snowflake Native Semantic View
-- Syntax source: docs.snowflake.com/en/sql-reference/sql/create-semantic-view
--
-- Correct DDL rules (verified against official docs):
--   TABLES   : [alias AS] table_name [WITH SYNONYMS = (...)] [COMMENT = '...']
--   FACTS     : alias.fact_name AS sql_expr [WITH SYNONYMS = (...)] [COMMENT = '...']
--   DIMENSIONS: alias.dim_name  AS sql_expr [WITH SYNONYMS = (...)] [COMMENT = '...']
--   METRICS   : alias.metric_name AS agg_expr [WITH SYNONYMS = (...)] [COMMENT = '...']
--   Clause order is mandatory: TABLES → FACTS → DIMENSIONS → METRICS
--   Commas between entries within each block are required
--   WITH SYNONYMS and COMMENT are legal inline on each entry (not YAML-only)
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.SEMANTICS.SV_HEALTHCARE_KNOWLEDGE_OPS

  -- ── TABLES ────────────────────────────────────────────────────────────────
  TABLES (
    OPS AS AI_BI_VW_SEMANTIC_KNOWLEDGE_OPS
      WITH SYNONYMS = ('healthcare ops', 'knowledge ops', 'agent metrics', 'knowledge operations')
      COMMENT = 'Monthly grain operational view combining agent query throughput, clinical protocol health, compliance gap exposure, and knowledge base coverage across organisation types and user personas.'
  )

  -- ── FACTS ─────────────────────────────────────────────────────────────────
  FACTS (
    -- Agent throughput
    OPS.TOTAL_KNOWLEDGE_QUERIES           AS OPS.TOTAL_KNOWLEDGE_QUERIES
      WITH SYNONYMS = ('total queries', 'query count', 'queries submitted')
      COMMENT = 'Total knowledge queries submitted in the reporting period.',

    OPS.QUERIES_RESOLVED_BY_AGENT         AS OPS.QUERIES_RESOLVED_BY_AGENT
      WITH SYNONYMS = ('agent resolved', 'auto resolved', 'self-service queries')
      COMMENT = 'Queries answered directly by the Cortex Search agent without manual intervention.',

    OPS.QUERIES_REQUIRING_MANUAL_LOOKUP   AS OPS.QUERIES_REQUIRING_MANUAL_LOOKUP
      WITH SYNONYMS = ('manual lookups', 'manual queries')
      COMMENT = 'Queries that required a staff member to manually locate the answer.',

    OPS.UNRESOLVED_QUERIES                AS OPS.UNRESOLVED_QUERIES
      WITH SYNONYMS = ('unresolved', 'unanswered queries')
      COMMENT = 'Queries that could not be answered by the agent or manually.',

    OPS.QUERIES_WITH_KNOWLEDGE_GAPS       AS OPS.QUERIES_WITH_KNOWLEDGE_GAPS
      WITH SYNONYMS = ('knowledge gaps', 'gap queries', 'content gaps')
      COMMENT = 'Queries where the knowledge base lacked relevant content.',

    OPS.QUERIES_ESCALATED                 AS OPS.QUERIES_ESCALATED
      WITH SYNONYMS = ('escalated queries', 'escalations')
      COMMENT = 'Queries escalated to a human specialist.',

    OPS.AGENT_SELF_RESOLUTION_RATE_PCT    AS OPS.AGENT_SELF_RESOLUTION_RATE_PCT
      WITH SYNONYMS = ('resolution rate', 'self-service rate', 'agent success rate')
      COMMENT = 'Percentage of queries resolved by the agent without human intervention.',

    OPS.AVG_AGENT_RESOLUTION_TIME_MINUTES AS OPS.AVG_AGENT_RESOLUTION_TIME_MINUTES
      WITH SYNONYMS = ('agent response time', 'agent resolution time')
      COMMENT = 'Average minutes for the agent to resolve a query.',

    OPS.AVG_MANUAL_RESOLUTION_TIME_MINUTES AS OPS.AVG_MANUAL_RESOLUTION_TIME_MINUTES
      WITH SYNONYMS = ('manual resolution time', 'manual lookup time')
      COMMENT = 'Average minutes to resolve a query via manual lookup.',

    OPS.AVERAGE_USER_SATISFACTION_SCORE   AS OPS.AVERAGE_USER_SATISFACTION_SCORE
      WITH SYNONYMS = ('satisfaction score', 'user satisfaction', 'csat')
      COMMENT = 'Average user satisfaction score on a 1-5 scale.',

    OPS.HIGH_CONFIDENCE_ANSWER_RATE_PCT   AS OPS.HIGH_CONFIDENCE_ANSWER_RATE_PCT
      WITH SYNONYMS = ('confidence rate', 'high confidence rate', 'answer confidence')
      COMMENT = 'Percentage of agent answers rated High confidence by the retrieval engine.',

    -- Protocol health
    OPS.TOTAL_ACTIVE_PROTOCOLS            AS OPS.TOTAL_ACTIVE_PROTOCOLS
      WITH SYNONYMS = ('active protocols', 'protocol count')
      COMMENT = 'Total clinical protocols in Active or Under Review status.',

    OPS.OVERDUE_PROTOCOLS                 AS OPS.OVERDUE_PROTOCOLS
      WITH SYNONYMS = ('overdue protocols', 'past due protocols', 'protocols overdue')
      COMMENT = 'Protocols whose next review date has passed with no completed review.',

    OPS.DUE_SOON_PROTOCOLS                AS OPS.DUE_SOON_PROTOCOLS
      WITH SYNONYMS = ('protocols due soon', 'upcoming protocol reviews')
      COMMENT = 'Protocols due for review within the next 60 days.',

    OPS.HIGH_RISK_PROTOCOLS               AS OPS.HIGH_RISK_PROTOCOLS
      WITH SYNONYMS = ('high risk protocols', 'high compliance risk protocols')
      COMMENT = 'Protocols classified as high compliance risk level.',

    OPS.AVG_PROTOCOL_ADHERENCE_PCT        AS OPS.AVG_PROTOCOL_ADHERENCE_PCT
      WITH SYNONYMS = ('protocol adherence', 'adherence rate', 'protocol compliance rate')
      COMMENT = 'Average adherence percentage across all active clinical protocols.',

    OPS.LOW_ADHERENCE_PROTOCOLS           AS OPS.LOW_ADHERENCE_PROTOCOLS
      WITH SYNONYMS = ('low adherence protocols', 'non-compliant protocols')
      COMMENT = 'Protocols with adherence below 75 percent.',

    -- Compliance gaps
    OPS.TOTAL_OPEN_FINDINGS               AS OPS.TOTAL_OPEN_FINDINGS
      WITH SYNONYMS = ('open findings', 'open compliance findings', 'compliance issues')
      COMMENT = 'Total compliance findings in Open or In Progress status.',

    OPS.CRITICAL_HIGH_OPEN_FINDINGS       AS OPS.CRITICAL_HIGH_OPEN_FINDINGS
      WITH SYNONYMS = ('critical findings', 'high severity findings', 'critical compliance gaps')
      COMMENT = 'Open compliance findings rated Critical or High severity.',

    OPS.OPEN_FINE_EXPOSURE_USD            AS OPS.OPEN_FINE_EXPOSURE_USD
      WITH SYNONYMS = ('fine exposure', 'regulatory fine risk', 'penalty exposure', 'fine risk usd')
      COMMENT = 'Estimated regulatory fine exposure in USD from unresolved compliance findings.',

    OPS.REGULATIONS_WITH_OPEN_FINDINGS    AS OPS.REGULATIONS_WITH_OPEN_FINDINGS
      WITH SYNONYMS = ('regulations at risk', 'regulations with findings')
      COMMENT = 'Count of distinct regulatory bodies with at least one open finding.',

    -- Knowledge base coverage
    OPS.TOTAL_DOCUMENTS_IN_KNOWLEDGE_BASE AS OPS.TOTAL_DOCUMENTS_IN_KNOWLEDGE_BASE
      WITH SYNONYMS = ('total documents', 'knowledge base size', 'document count')
      COMMENT = 'Total documents indexed in the Knowledge Agent knowledge base.',

    OPS.HEALTHY_DOCUMENTS                 AS OPS.HEALTHY_DOCUMENTS
      WITH SYNONYMS = ('healthy docs', 'good documents', 'current documents')
      COMMENT = 'Documents rated Healthy — current, queried, and returning high-confidence answers.',

    OPS.STALE_DOCUMENTS                   AS OPS.STALE_DOCUMENTS
      WITH SYNONYMS = ('stale docs', 'outdated documents', 'old documents')
      COMMENT = 'Documents past their review date still returning answers — stale content risk.',

    OPS.OVERDUE_REVIEW_DOCUMENTS          AS OPS.OVERDUE_REVIEW_DOCUMENTS
      WITH SYNONYMS = ('overdue documents', 'documents past review date')
      COMMENT = 'Documents with a missed review date — immediate attention required.',

    OPS.DOCUMENTS_WITH_GAP_DETECTED       AS OPS.DOCUMENTS_WITH_GAP_DETECTED
      WITH SYNONYMS = ('gap documents', 'documents with gaps', 'knowledge gap documents')
      COMMENT = 'Documents where queries returned low-confidence answers or were flagged as knowledge gaps.',

    OPS.UNUSED_DOCUMENTS                  AS OPS.UNUSED_DOCUMENTS
      WITH SYNONYMS = ('unused docs', 'dead documents', 'zero-hit documents')
      COMMENT = 'Documents in the knowledge base that have received zero query hits.'
  )

  -- ── DIMENSIONS ─────────────────────────────────────────────────────────────
  DIMENSIONS (
    OPS.REPORTING_MONTH                   AS OPS.REPORTING_MONTH
      WITH SYNONYMS = ('month', 'period', 'reporting period', 'time period')
      COMMENT = 'Calendar month of the reporting period (truncated to first of month).',

    OPS.ORGANISATION_TYPE                 AS OPS.ORGANISATION_TYPE
      WITH SYNONYMS = ('org type', 'organization', 'organisation', 'entity type', 'customer type')
      COMMENT = 'Type of healthcare organisation: Health System, Payer, or Pharma.',

    OPS.USER_PERSONA_CATEGORY             AS OPS.USER_PERSONA_CATEGORY
      WITH SYNONYMS = ('persona', 'user type', 'role category', 'user category', 'staff type')
      COMMENT = 'Category of the user persona submitting queries: Clinical, Compliance, Operational, or Executive.',

    OPS.QUERY_CONTENT_DOMAIN              AS OPS.QUERY_CONTENT_DOMAIN
      WITH SYNONYMS = ('content domain', 'query category', 'topic area', 'query topic', 'domain')
      COMMENT = 'Subject domain of the knowledge query: Clinical, Regulatory, Operational, or Research.'
  )

  -- ── METRICS ────────────────────────────────────────────────────────────────
  METRICS (
    -- Agent throughput metrics
    OPS.TOTAL_QUERIES_SUBMITTED           AS SUM(OPS.TOTAL_KNOWLEDGE_QUERIES)
      WITH SYNONYMS = ('total queries submitted', 'total volume', 'query volume')
      COMMENT = 'Sum of all knowledge queries submitted across the selected dimensions.',

    OPS.TOTAL_AGENT_RESOLVED              AS SUM(OPS.QUERIES_RESOLVED_BY_AGENT)
      WITH SYNONYMS = ('total resolved by agent', 'agent resolutions')
      COMMENT = 'Total queries resolved autonomously by the Knowledge Agent.',

    OPS.TOTAL_MANUAL_LOOKUPS              AS SUM(OPS.QUERIES_REQUIRING_MANUAL_LOOKUP)
      WITH SYNONYMS = ('total manual lookups', 'manual resolution count')
      COMMENT = 'Total queries that required manual staff intervention to resolve.',

    OPS.TOTAL_UNRESOLVED                  AS SUM(OPS.UNRESOLVED_QUERIES)
      WITH SYNONYMS = ('total unresolved', 'unanswered count')
      COMMENT = 'Total queries that remained unanswered.',

    OPS.TOTAL_KNOWLEDGE_GAP_QUERIES       AS SUM(OPS.QUERIES_WITH_KNOWLEDGE_GAPS)
      WITH SYNONYMS = ('total knowledge gaps', 'gap count', 'total gaps')
      COMMENT = 'Total queries that exposed a gap in the knowledge base.',

    OPS.TOTAL_ESCALATED                   AS SUM(OPS.QUERIES_ESCALATED)
      WITH SYNONYMS = ('total escalations', 'escalation count')
      COMMENT = 'Total queries escalated to human specialists.',

    OPS.OVERALL_RESOLUTION_RATE_PCT       AS AVG(OPS.AGENT_SELF_RESOLUTION_RATE_PCT)
      WITH SYNONYMS = ('overall resolution rate', 'average resolution rate', 'agent success rate')
      COMMENT = 'Average agent self-resolution rate across the selected dimensions (percentage).',

    OPS.OVERALL_SATISFACTION              AS AVG(OPS.AVERAGE_USER_SATISFACTION_SCORE)
      WITH SYNONYMS = ('overall satisfaction', 'average satisfaction', 'avg csat')
      COMMENT = 'Average user satisfaction score (1-5 scale) across all queries.',

    OPS.OVERALL_AVG_AGENT_MINS            AS AVG(OPS.AVG_AGENT_RESOLUTION_TIME_MINUTES)
      WITH SYNONYMS = ('average agent time', 'mean agent resolution time')
      COMMENT = 'Average minutes for the agent to resolve queries.',

    OPS.OVERALL_AVG_MANUAL_MINS           AS AVG(OPS.AVG_MANUAL_RESOLUTION_TIME_MINUTES)
      WITH SYNONYMS = ('average manual time', 'mean manual lookup time')
      COMMENT = 'Average minutes for staff to manually resolve queries.',

    OPS.OVERALL_HIGH_CONFIDENCE_PCT       AS AVG(OPS.HIGH_CONFIDENCE_ANSWER_RATE_PCT)
      WITH SYNONYMS = ('average confidence rate', 'overall confidence')
      COMMENT = 'Average high-confidence answer rate across all queries.',

    -- Protocol health metrics
    -- MAX used for snapshot figures: these repeat per month row, not additive across months
    OPS.TOTAL_PROTOCOLS_ACTIVE            AS MAX(OPS.TOTAL_ACTIVE_PROTOCOLS)
      WITH SYNONYMS = ('active protocol count', 'number of active protocols')
      COMMENT = 'Total active clinical protocols (snapshot — MAX aggregation prevents double-counting).',

    OPS.TOTAL_PROTOCOLS_OVERDUE           AS MAX(OPS.OVERDUE_PROTOCOLS)
      WITH SYNONYMS = ('overdue protocol count', 'protocols past due')
      COMMENT = 'Count of protocols overdue for review.',

    OPS.TOTAL_PROTOCOLS_DUE_SOON          AS MAX(OPS.DUE_SOON_PROTOCOLS)
      WITH SYNONYMS = ('protocols due soon count', 'upcoming review count')
      COMMENT = 'Count of protocols due for review within 60 days.',

    OPS.TOTAL_HIGH_RISK_PROTOCOLS         AS MAX(OPS.HIGH_RISK_PROTOCOLS)
      WITH SYNONYMS = ('high risk protocol count', 'number of high risk protocols')
      COMMENT = 'Count of protocols classified as high compliance risk.',

    OPS.TOTAL_LOW_ADHERENCE_PROTOCOLS     AS MAX(OPS.LOW_ADHERENCE_PROTOCOLS)
      WITH SYNONYMS = ('low adherence count', 'non-compliant protocol count')
      COMMENT = 'Count of protocols with adherence below 75 percent.',

    OPS.OVERALL_PROTOCOL_ADHERENCE_PCT    AS AVG(OPS.AVG_PROTOCOL_ADHERENCE_PCT)
      WITH SYNONYMS = ('average adherence', 'mean protocol adherence', 'overall adherence rate')
      COMMENT = 'Average protocol adherence rate across all active protocols (percentage).',

    -- Compliance gap metrics
    OPS.TOTAL_OPEN_COMPLIANCE_FINDINGS    AS MAX(OPS.TOTAL_OPEN_FINDINGS)
      WITH SYNONYMS = ('open findings count', 'compliance finding count', 'total open issues')
      COMMENT = 'Total open compliance findings across all regulations.',

    OPS.TOTAL_CRITICAL_HIGH_FINDINGS      AS MAX(OPS.CRITICAL_HIGH_OPEN_FINDINGS)
      WITH SYNONYMS = ('critical finding count', 'high severity count', 'critical issues')
      COMMENT = 'Count of open Critical or High severity compliance findings.',

    OPS.TOTAL_FINE_EXPOSURE_USD           AS MAX(OPS.OPEN_FINE_EXPOSURE_USD)
      WITH SYNONYMS = ('total fine exposure', 'regulatory risk usd', 'penalty risk', 'fine risk')
      COMMENT = 'Total estimated regulatory fine exposure in USD for all open findings.',

    OPS.TOTAL_REGS_WITH_OPEN_FINDINGS     AS MAX(OPS.REGULATIONS_WITH_OPEN_FINDINGS)
      WITH SYNONYMS = ('regulations at risk count', 'number of regulations with findings')
      COMMENT = 'Count of regulatory bodies with at least one open finding.',

    -- Knowledge base coverage metrics
    OPS.TOTAL_KNOWLEDGE_DOCUMENTS         AS MAX(OPS.TOTAL_DOCUMENTS_IN_KNOWLEDGE_BASE)
      WITH SYNONYMS = ('total documents', 'knowledge base document count', 'document total')
      COMMENT = 'Total documents in the knowledge base.',

    OPS.TOTAL_HEALTHY_DOCUMENTS           AS MAX(OPS.HEALTHY_DOCUMENTS)
      WITH SYNONYMS = ('healthy document count', 'number of healthy documents')
      COMMENT = 'Count of documents classified as Healthy.',

    OPS.TOTAL_STALE_DOCUMENTS             AS MAX(OPS.STALE_DOCUMENTS)
      WITH SYNONYMS = ('stale document count', 'number of stale documents', 'outdated doc count')
      COMMENT = 'Count of documents classified as stale.',

    OPS.TOTAL_OVERDUE_REVIEW_DOCS         AS MAX(OPS.OVERDUE_REVIEW_DOCUMENTS)
      WITH SYNONYMS = ('overdue document count', 'documents past review')
      COMMENT = 'Count of documents with a missed review date.',

    OPS.TOTAL_GAP_DOCUMENTS               AS MAX(OPS.DOCUMENTS_WITH_GAP_DETECTED)
      WITH SYNONYMS = ('gap document count', 'documents with knowledge gaps')
      COMMENT = 'Count of documents flagged with a knowledge gap.',

    OPS.TOTAL_UNUSED_DOCUMENTS            AS MAX(OPS.UNUSED_DOCUMENTS)
      WITH SYNONYMS = ('unused document count', 'zero-hit document count', 'dead content count')
      COMMENT = 'Count of documents with zero query hits.'
  )

  AI_SQL_GENERATION
    'When asked about trends, group by REPORTING_MONTH and order chronologically.
     When asked about resolution rates or satisfaction, use OVERALL_RESOLUTION_RATE_PCT and OVERALL_SATISFACTION metrics.
     Protocol health and compliance gap metrics are snapshot values — do not SUM them across months; use the pre-defined MAX-based metrics.
     When comparing organisation types, always include ORGANISATION_TYPE as a dimension.
     Fine exposure amounts are in USD; format with currency notation in output where possible.
     For knowledge gap analysis, combine TOTAL_KNOWLEDGE_GAP_QUERIES with TOTAL_GAP_DOCUMENTS for full context.';
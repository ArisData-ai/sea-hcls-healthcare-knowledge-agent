-- DDL for curated transient base tables for the Healthcare Knowledge Agent
-- Co-authored with CoCo
-- =============================================================================
-- SECTION 1 : CURATED TRANSIENT BASE TABLES
-- Dependency order:
--   CURATED_TBL_STAFF_ROLES                 (no deps)
--   CURATED_TBL_DOCUMENTS                   (no deps)
--   CURATED_TBL_CLINICAL_PROTOCOLS          (no deps)
--   CURATED_TBL_REGULATORY_REQUIREMENTS     (no deps)
--   CURATED_TBL_COMPLIANCE_FINDINGS         (depends on REGULATORY_REQUIREMENTS)
--   CURATED_TBL_CONTENT_REVIEW_SCHEDULE     (depends on CLINICAL_PROTOCOLS)
--   CURATED_TBL_KNOWLEDGE_QUERIES           (depends on STAFF_ROLES, DOCUMENTS)
-- =============================================================================

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

-- ----------------------------------------------------------------------------
-- 1.1  CURATED_TBL_STAFF_ROLES
--      Reference table for all personas who interact with the Knowledge Agent.
--      Correlates with agent personas: Care Teams, Compliance Officers,
--      Operations Staff (as shown in the architecture diagram).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE CURATED_TBL_STAFF_ROLES (
    ROLE_ID             NUMBER          NOT NULL AUTOINCREMENT PRIMARY KEY,
    ROLE_CODE           VARCHAR(30)     NOT NULL UNIQUE,
    ROLE_DISPLAY_NAME   VARCHAR(80)     NOT NULL,
    PERSONA_CATEGORY    VARCHAR(40)     NOT NULL,   -- Clinical / Compliance / Operational / Executive
    ORG_TYPE            VARCHAR(60)     NOT NULL,   -- Health System / Payer / Pharma / Academic Medical
    AVG_QUERIES_PER_DAY NUMBER(5,1),
    TYPICAL_CONTENT_DOMAIN VARCHAR(120),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
DATA_RETENTION_TIME_IN_DAYS = 0;

-- ----------------------------------------------------------------------------
-- 1.2  CURATED_TBL_DOCUMENTS
--      Master registry of every document ingested into the knowledge base.
--      Primary bridge between the unstructured RAG pipeline (KA_DOC_RAW,
--      KA_DOC_CHUNKS) and the structured analytics layer.
--      DOC_REF_KEY must match the source_doc_id stored in KA_DOC_METADATA.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE CURATED_TBL_DOCUMENTS (
    DOC_ID              NUMBER          NOT NULL AUTOINCREMENT PRIMARY KEY,
    DOC_REF_KEY         VARCHAR(100)    NOT NULL UNIQUE, -- FK to KA_DOC_METADATA.source_doc_id
    DOC_TITLE           VARCHAR(300)    NOT NULL,
    DOC_TYPE            VARCHAR(60)     NOT NULL,   -- Clinical Protocol / Regulatory Guidance /
                                                    -- SOP / Policy / Research Archive
    CONTENT_DOMAIN      VARCHAR(80)     NOT NULL,   -- Clinical / Regulatory / Operational / Research
    SOURCE_SYSTEM       VARCHAR(80),                -- PolicyStat / SharePoint / PolicyTech
    OWNING_DEPARTMENT   VARCHAR(100),
    ORG_TYPE_TARGET     VARCHAR(60),                -- Health System / Payer / Pharma
    VERSION_LABEL       VARCHAR(20),
    STATUS              VARCHAR(30)     NOT NULL,   -- Active / Archived / Under Review / Pending Approval
    PUBLISHED_DATE      DATE,
    LAST_REVIEWED_DATE  DATE,
    NEXT_REVIEW_DATE    DATE,
    WORD_COUNT          NUMBER(7),
    CHUNK_COUNT         NUMBER(5),
    INGESTED_AT         TIMESTAMP_NTZ,
    LAST_UPDATED_AT     TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
DATA_RETENTION_TIME_IN_DAYS = 0;

-- ----------------------------------------------------------------------------
-- 1.3  CURATED_TBL_CLINICAL_PROTOCOLS
--      Tracks every clinical protocol in the knowledge base: version lifecycle,
--      evidence grade, clinical owner, and operational coverage.
--      Used to answer questions like "How many ICU protocols are overdue?"
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE CURATED_TBL_CLINICAL_PROTOCOLS (
    PROTOCOL_ID             NUMBER          NOT NULL AUTOINCREMENT PRIMARY KEY,
    PROTOCOL_CODE           VARCHAR(30)     NOT NULL UNIQUE,
    PROTOCOL_NAME           VARCHAR(300)    NOT NULL,
    CLINICAL_CATEGORY       VARCHAR(80)     NOT NULL,   -- ICU / Emergency / Surgical / Pharmacy /
                                                        -- Oncology / Infection Control / Radiology
    APPLICABLE_CARE_SETTING VARCHAR(80),                -- Inpatient / Outpatient / ED / ICU / All
    OWNING_SPECIALTY        VARCHAR(80),
    EVIDENCE_GRADE          CHAR(2),                    -- A / B / C / D / Expert Opinion
    CURRENT_VERSION         VARCHAR(20)     NOT NULL,
    VERSION_EFFECTIVE_DATE  DATE,
    PRIOR_VERSION           VARCHAR(20),
    STATUS                  VARCHAR(30)     NOT NULL,   -- Active / Retired / Draft / Under Review
    COMPLIANCE_RISK_LEVEL   VARCHAR(20),                -- High / Medium / Low
    REGULATORY_STANDARD     VARCHAR(80),                -- Joint Commission / CMS / State / Internal
    LAST_REVIEWED_DATE      DATE,
    NEXT_REVIEW_DUE_DATE    DATE,
    TOTAL_REVISIONS         NUMBER(4)       DEFAULT 0,
    AVERAGE_ADHERENCE_PCT   NUMBER(5,2),
    LINKED_DOC_REF_KEY      VARCHAR(100),   -- FK to CURATED_TBL_DOCUMENTS.DOC_REF_KEY
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
DATA_RETENTION_TIME_IN_DAYS = 0;

-- ----------------------------------------------------------------------------
-- 1.4  CURATED_TBL_REGULATORY_REQUIREMENTS
--      Canonical list of regulatory requirements the organisation must satisfy.
--      Covers HIPAA, CMS, Joint Commission, FDA, State requirements.
--      Compliance findings reference rows from this table.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE CURATED_TBL_REGULATORY_REQUIREMENTS (
    REQUIREMENT_ID      NUMBER          NOT NULL AUTOINCREMENT PRIMARY KEY,
    REQUIREMENT_CODE    VARCHAR(40)     NOT NULL UNIQUE,
    REGULATION_BODY     VARCHAR(80)     NOT NULL,   -- CMS / Joint Commission / HIPAA / FDA / State
    REGULATION_NAME     VARCHAR(200)    NOT NULL,
    REQUIREMENT_TITLE   VARCHAR(300)    NOT NULL,
    REQUIREMENT_CATEGORY VARCHAR(80)   NOT NULL,    -- Privacy / Safety / Quality / Documentation /
                                                    -- Billing / Clinical
    APPLICABLE_ORG_TYPE VARCHAR(80),                -- Health System / Payer / Pharma / All
    JURISDICTION        VARCHAR(80),                -- Federal / State / International
    ENFORCEMENT_LEVEL   VARCHAR(20),                -- Mandatory / Conditional / Advisory
    PENALTY_RANGE_USD   VARCHAR(60),
    REVIEW_FREQUENCY    VARCHAR(40),                -- Annual / Biannual / Continuous / Event-Driven
    EFFECTIVE_DATE      DATE,
    LAST_UPDATED_DATE   DATE,
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
DATA_RETENTION_TIME_IN_DAYS = 0;

-- ----------------------------------------------------------------------------
-- 1.5  CURATED_TBL_COMPLIANCE_FINDINGS
--      Audit and self-assessment findings mapped to specific requirements.
--      Depends on CURATED_TBL_REGULATORY_REQUIREMENTS.
--      Enables "How many open high-severity HIPAA findings?" style queries.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE CURATED_TBL_COMPLIANCE_FINDINGS (
    FINDING_ID              NUMBER          NOT NULL AUTOINCREMENT PRIMARY KEY,
    REQUIREMENT_ID          NUMBER          NOT NULL,   -- FK to CURATED_TBL_REGULATORY_REQUIREMENTS
    FINDING_DATE            DATE            NOT NULL,
    FINDING_SOURCE          VARCHAR(60),                -- Internal Audit / External Audit /
                                                        -- Self-Assessment / Incident Report
    FINDING_TYPE            VARCHAR(60)     NOT NULL,   -- Non-Conformance / Observation /
                                                        -- Minor Gap / Major Gap / Critical
    SEVERITY                VARCHAR(20)     NOT NULL,   -- Critical / High / Medium / Low
    FINDING_DESCRIPTION     VARCHAR(500),
    AFFECTED_DEPARTMENT     VARCHAR(100),
    REMEDIATION_OWNER       VARCHAR(100),
    REMEDIATION_DUE_DATE    DATE,
    REMEDIATION_STATUS      VARCHAR(30)     NOT NULL,   -- Open / In Progress / Resolved / Accepted Risk
    RESOLVED_DATE           DATE,
    ESTIMATED_FINE_EXPOSURE NUMBER(12,2),
    RESOLUTION_NOTES        VARCHAR(300),
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT FK_FINDING_REQ FOREIGN KEY (REQUIREMENT_ID)
        REFERENCES CURATED_TBL_REGULATORY_REQUIREMENTS (REQUIREMENT_ID)
)
DATA_RETENTION_TIME_IN_DAYS = 0;

-- ----------------------------------------------------------------------------
-- 1.6  CURATED_TBL_CONTENT_REVIEW_SCHEDULE
--      Tracks scheduled and completed reviews for clinical protocols.
--      Depends on CURATED_TBL_CLINICAL_PROTOCOLS.
--      Supports "Which protocols are overdue for review?" queries.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE CURATED_TBL_CONTENT_REVIEW_SCHEDULE (
    REVIEW_ID           NUMBER          NOT NULL AUTOINCREMENT PRIMARY KEY,
    PROTOCOL_ID         NUMBER          NOT NULL,   -- FK to CURATED_TBL_CLINICAL_PROTOCOLS
    SCHEDULED_DATE      DATE            NOT NULL,
    REVIEW_TYPE         VARCHAR(60),                -- Periodic / Triggered / Post-Incident / Regulatory
    ASSIGNED_REVIEWER   VARCHAR(120),
    REVIEWER_SPECIALTY  VARCHAR(80),
    STATUS              VARCHAR(30)     NOT NULL,   -- Scheduled / In Review / Completed / Overdue / Cancelled
    ACTUAL_COMPLETION_DATE DATE,
    DAYS_OVERDUE        NUMBER(9),      -- Computed at query/load time: DATEDIFF('day', SCHEDULED_DATE, CURRENT_DATE()) when STATUS = 'Overdue'
    OUTCOME             VARCHAR(60),                -- No Change / Minor Update / Major Revision / Retired
    OUTCOME_NOTES       VARCHAR(300),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT FK_REVIEW_PROTOCOL FOREIGN KEY (PROTOCOL_ID)
        REFERENCES CURATED_TBL_CLINICAL_PROTOCOLS (PROTOCOL_ID)
)
DATA_RETENTION_TIME_IN_DAYS = 0;

-- ----------------------------------------------------------------------------
-- 1.7  CURATED_TBL_KNOWLEDGE_QUERIES
--      Captures every query submitted to the Knowledge Agent, its resolution
--      path, and outcome. Depends on CURATED_TBL_STAFF_ROLES and
--      CURATED_TBL_DOCUMENTS (resolved_doc_ref_key is nullable FK).
--      Powers "How quickly are care teams getting answers?" metrics.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE CURATED_TBL_KNOWLEDGE_QUERIES (
    QUERY_ID                NUMBER          NOT NULL AUTOINCREMENT PRIMARY KEY,
    QUERY_DATE              DATE            NOT NULL,
    QUERY_TIMESTAMP         TIMESTAMP_NTZ   NOT NULL,
    ROLE_CODE               VARCHAR(30)     NOT NULL,   -- FK to CURATED_TBL_STAFF_ROLES
    ORG_TYPE                VARCHAR(60),
    QUERY_CATEGORY          VARCHAR(80),                -- Clinical / Regulatory / Operational / Research
    QUERY_TOPIC             VARCHAR(200),
    RESOLUTION_CHANNEL      VARCHAR(60),                -- Cortex Search / Manual Lookup / Escalation / Unresolved
    TIME_TO_RESOLUTION_MIN  NUMBER(7,1),
    RESOLVED_DOC_REF_KEY    VARCHAR(100),               -- nullable FK to CURATED_TBL_DOCUMENTS
    ANSWER_CONFIDENCE       VARCHAR(20),                -- High / Medium / Low / Not Found
    WAS_KNOWLEDGE_GAP       BOOLEAN         DEFAULT FALSE,
    SATISFACTION_SCORE      NUMBER(2)       CHECK (SATISFACTION_SCORE BETWEEN 1 AND 5),
    ESCALATED_FLAG          BOOLEAN         DEFAULT FALSE,
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
DATA_RETENTION_TIME_IN_DAYS = 0;
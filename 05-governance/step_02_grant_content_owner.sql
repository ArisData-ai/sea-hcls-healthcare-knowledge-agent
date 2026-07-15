-- Grant database/schema usage and table-level privileges to ROLE_HK_CONTENT_OWNER.
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- ROLE_HK_CONTENT_OWNER grants
-- Persona: Content/protocol owners who manage documents and submit review decisions.
-- Best practice: SECURITYADMIN manages privilege grants.
--------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

-- Database and schema usage
GRANT USAGE ON DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS TO ROLE ROLE_HK_CONTENT_OWNER;
GRANT USAGE ON SCHEMA DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE TO ROLE ROLE_HK_CONTENT_OWNER;

-- HITL_TBL_REVIEW_DECISIONS: content owners record their review decisions
GRANT SELECT, INSERT ON TABLE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.HITL_TBL_REVIEW_DECISIONS TO ROLE ROLE_HK_CONTENT_OWNER;

-- HITL_TBL_REVIEW_QUEUE: content owners view and update status on their own items
GRANT SELECT, UPDATE ON TABLE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.HITL_TBL_REVIEW_QUEUE TO ROLE ROLE_HK_CONTENT_OWNER;

-- CURATED_TBL_DOCUMENTS: content owners read and update document metadata
GRANT SELECT, UPDATE ON TABLE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.CURATED_TBL_DOCUMENTS TO ROLE ROLE_HK_CONTENT_OWNER;

SHOW GRANTS TO ROLE ROLE_HK_CONTENT_OWNER;
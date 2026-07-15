-- Grant privileges to ROLE_HK_CLINICIAN_VIEWER and ROLE_HK_EXEC_VIEWER leaf roles.
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- ROLE_HK_CLINICIAN_VIEWER grants
-- Persona: Care team / query submitters — read-only content access for
--          KA_RESOLVE_QUERY execution. No HITL table access whatsoever.
-- Best practice: SECURITYADMIN manages privilege grants.
--------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

-- Database and schema usage
GRANT USAGE ON DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS TO ROLE ROLE_HK_CLINICIAN_VIEWER;
GRANT USAGE ON SCHEMA DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE TO ROLE ROLE_HK_CLINICIAN_VIEWER;

-- Content access for query resolution (approved documents only, enforced at procedure level)
GRANT SELECT ON TABLE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.CURATED_TBL_DOCUMENTS TO ROLE ROLE_HK_CLINICIAN_VIEWER;

--------------------------------------------------------------------------------
-- ROLE_HK_EXEC_VIEWER grants
-- Persona: CDO / executives — dashboard-level visibility on coverage,
--          compliance, and the semantic view. No content-level or HITL access.
--------------------------------------------------------------------------------

-- Database and schema usage
GRANT USAGE ON DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS TO ROLE ROLE_HK_EXEC_VIEWER;
GRANT USAGE ON SCHEMA DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE TO ROLE ROLE_HK_EXEC_VIEWER;

-- Semantic view for Conversational Panel
GRANT SELECT ON VIEW DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.SV_HEALTHCARE_KNOWLEDGE_OPS TO ROLE ROLE_HK_EXEC_VIEWER;

-- Compliance and coverage summary views
GRANT SELECT ON VIEW DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.CURATED_VW_COMPLIANCE_GAP_SUMMARY TO ROLE ROLE_HK_EXEC_VIEWER;

-- Grant minimal read-only access to ROLE_HK_CORTEX_AGENT_ANALYST for the Conversational Panel.
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- ROLE_HK_CORTEX_AGENT_ANALYST grants
-- Persona: The Cortex Agent's Analyst tool — strictly read-only, single object.
-- CRITICAL: This role must NEVER receive a write grant (INSERT/UPDATE/DELETE)
--           on anything. It backs the read-only Conversational Panel. Any PR or
--           script that adds a write grant to this role is a governance incident.
-- Best practice: SECURITYADMIN manages privilege grants.
--------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

-- Schema usage (required to resolve the semantic view)
GRANT USAGE ON DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;
GRANT USAGE ON SCHEMA DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;

-- SELECT on the semantic view — the only data grant this role will ever have
GRANT SELECT ON VIEW DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.SV_HEALTHCARE_KNOWLEDGE_OPS TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;

SHOW GRANTS TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;
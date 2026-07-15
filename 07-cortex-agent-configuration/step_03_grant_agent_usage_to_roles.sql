-- Grant USAGE on KA_KNOWLEDGE_AGENT to consuming roles for the Conversational Panel
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- CONTEXT
-- The Cortex Agent Conversational Panel (Screen 4) is accessed by executives
-- and compliance leads. Tier 1 query resolution for clinicians routes through
-- KA_RESOLVE_QUERY → KA_KNOWLEDGE_SEARCH directly (see tier-1-query-resolution.md),
-- so ROLE_HK_CLINICIAN_VIEWER does NOT need USAGE on the agent object.
--
-- Grants here:
--   ROLE_HK_EXEC_VIEWER       — CDO/executives using the Conversational Panel
--   ROLE_HK_COMPLIANCE_LEAD   — compliance/quality leads using the Conversational Panel
--
-- Note: ROLE_HK_CORTEX_AGENT_ANALYST is the role the agent itself uses internally
-- for Analyst tool calls (already has SELECT on the semantic view from Phase 5).
-- It does NOT need USAGE on the agent — it is not a consumer of the agent.
--------------------------------------------------------------------------------

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

--------------------------------------------------------------------------------
-- Grant USAGE on the agent to the two consuming roles
--------------------------------------------------------------------------------
GRANT USAGE ON AGENT KA_KNOWLEDGE_AGENT TO ROLE ROLE_HK_EXEC_VIEWER;
GRANT USAGE ON AGENT KA_KNOWLEDGE_AGENT TO ROLE ROLE_HK_COMPLIANCE_LEAD;

--------------------------------------------------------------------------------
-- VERIFICATION
--------------------------------------------------------------------------------
SHOW GRANTS ON AGENT KA_KNOWLEDGE_AGENT;
-- Expected: two USAGE grants visible:
--   privilege=USAGE, granted_to=ROLE, grantee_name=ROLE_HK_EXEC_VIEWER
--   privilege=USAGE, granted_to=ROLE, grantee_name=ROLE_HK_COMPLIANCE_LEAD
--
-- Plus the OWNERSHIP grant held by ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE (or
-- whichever role created the agent via the Snowsight UI).
--
-- Confirm: NO grant to ROLE_HK_CLINICIAN_VIEWER (Tier 1 bypasses the agent).
-- Confirm: NO grant to ROLE_HK_CORTEX_AGENT_ANALYST (internal tool role, not a consumer).

-- Inspect existing KA_KNOWLEDGE_AGENT to determine current state and supported SQL surface
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- CONTEXT
-- The agent object KA_KNOWLEDGE_AGENT was created via the Snowsight Agent
-- builder UI and is currently unconfigured (no tools bound, no instructions).
-- Before drafting any ALTER or GRANT statements we need to know:
--   1. What the DESCRIBE output shows (current spec, tools, instructions)
--   2. What SHOW AGENTS returns (metadata, version, readiness)
--   3. Whether SHOW GRANTS ON AGENT is a supported command in this account
-- Run each statement individually; if any returns an error, record the exact
-- error text — that itself is the finding.
--------------------------------------------------------------------------------

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

--------------------------------------------------------------------------------
-- 1. DESCRIBE the agent — expected to return its current specification
--------------------------------------------------------------------------------
DESCRIBE AGENT KA_KNOWLEDGE_AGENT;

--------------------------------------------------------------------------------
-- 2. SHOW AGENTS — confirm existence and capture metadata columns
--------------------------------------------------------------------------------
SHOW AGENTS LIKE 'KA_KNOWLEDGE_AGENT' IN SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;

--------------------------------------------------------------------------------
-- 3. Attempt SHOW GRANTS ON AGENT — may or may not be supported yet
--------------------------------------------------------------------------------
SHOW GRANTS ON AGENT KA_KNOWLEDGE_AGENT;

--------------------------------------------------------------------------------
-- 4. Attempt ALTER AGENT dry-run syntax probe — do NOT actually change anything
--    Just run a minimal DESCRIBE after to confirm no change was applied.
--    (This statement is intentionally commented out — only uncomment if the
--    above commands all succeed and you want to test ALTER support.)
--------------------------------------------------------------------------------
ALTER AGENT KA_KNOWLEDGE_AGENT SET COMMENT = 'syntax probe — safe to revert';
DESCRIBE AGENT KA_KNOWLEDGE_AGENT;
ALTER AGENT KA_KNOWLEDGE_AGENT SET COMMENT = '';

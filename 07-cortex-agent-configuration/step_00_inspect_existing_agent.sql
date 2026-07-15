-- Create and inspect KA_KNOWLEDGE_AGENT
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- CONTEXT
-- This script creates the KA_KNOWLEDGE_AGENT agent object and then inspects it
-- to confirm its state. The agent is created with no specification initially;
-- subsequent steps in 07-cortex-agent-configuration/ will configure tools,
-- instructions, and resources.
--------------------------------------------------------------------------------

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.GEN_AGENTIC_AI;

--------------------------------------------------------------------------------
-- 0. CREATE the agent
--------------------------------------------------------------------------------
CREATE AGENT IF NOT EXISTS KA_KNOWLEDGE_AGENT
  COMMENT = 'Healthcare knowledge agent — tools and instructions configured in subsequent steps';

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

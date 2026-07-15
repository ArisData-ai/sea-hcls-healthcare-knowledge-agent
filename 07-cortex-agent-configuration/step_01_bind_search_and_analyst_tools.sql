-- Bind KA_KNOWLEDGE_SEARCH (Cortex Search) and SV_HEALTHCARE_KNOWLEDGE_OPS (Cortex Analyst) as tools on KA_KNOWLEDGE_AGENT
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- CONTEXT
-- This is the first configuration step for the existing KA_KNOWLEDGE_AGENT.
-- ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION replaces the entire
-- specification, so we must include everything the agent needs in one statement:
--   Tool 1: Cortex Search over KA_KNOWLEDGE_SEARCH (unstructured content)
--   Tool 2: Cortex Analyst over SV_HEALTHCARE_KNOWLEDGE_OPS (structured metrics)
-- Instructions are kept minimal here — step_02 will set the full tool-selection
-- instructions. We include a placeholder orchestration instruction so the agent
-- is functional between steps.
--
-- IMPORTANT: ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION is a full
-- replacement. Any field not included is removed.
--------------------------------------------------------------------------------

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;

USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB.GEN_AGENTIC_AI;

ALTER AGENT KA_KNOWLEDGE_AGENT
    MODIFY LIVE VERSION SET SPECIFICATION =
$$
models:
  orchestration: auto

tools:
  - tool_spec:
      type: "cortex_search"
      name: "KnowledgeSearch"
      description: "Searches clinical, regulatory, and operational document content in the healthcare knowledge base. Use this tool when the user asks what a policy, protocol, or regulation says, or wants an answer sourced from document content."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "KnowledgeOpsAnalyst"
      description: "Queries structured metrics about the knowledge base itself — protocol review status, compliance exposure, resolution rates, coverage trends, and overdue items. Use this tool when the user asks about the state or health of the knowledge base as a system."

tool_resources:
  KnowledgeSearch:
    name: "DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.KA_KNOWLEDGE_SEARCH"
    max_results: "5"
  KnowledgeOpsAnalyst:
    semantic_view: "DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.SV_HEALTHCARE_KNOWLEDGE_OPS"
$$;

--------------------------------------------------------------------------------
-- VERIFICATION
--------------------------------------------------------------------------------
DESCRIBE AGENT KA_KNOWLEDGE_AGENT;
-- Expected: specification output shows both tools (KnowledgeSearch type
-- cortex_search, KnowledgeOpsAnalyst type cortex_analyst_text_to_sql) and
-- their corresponding tool_resources pointing to the correct FQN objects.

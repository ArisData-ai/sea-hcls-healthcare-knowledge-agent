-- Set tool-selection instructions on KA_KNOWLEDGE_AGENT to route content questions to Search and metrics questions to Analyst
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- CONTEXT
-- Step_01 bound both tools. This step adds the full orchestration and response
-- instructions that tell the agent how to choose between them. Because
-- ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION is a full replacement,
-- this statement re-includes the complete tool definitions from step_01 plus
-- the new instructions block.
--
-- The tool-selection instruction text is drawn from tier2-structured-analytics.md
-- and distinguishes:
--   Search  → clinical/regulatory/operational CONTENT questions
--   Analyst → knowledge-base HEALTH/metrics questions
--------------------------------------------------------------------------------

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

ALTER AGENT KA_KNOWLEDGE_AGENT
    MODIFY LIVE VERSION SET SPECIFICATION =
$$
models:
  orchestration: auto

instructions:
  response: "Provide clear, concise answers grounded in the retrieved evidence. Cite the source document or metric used. If the answer cannot be determined from available data, say so explicitly rather than speculating."
  orchestration: "If the user is asking what a policy or protocol says, or wants an answer sourced from document content — such as protocol steps, policy language, regulation text, or operational procedures — use the KnowledgeSearch tool. If the user is asking about the state of the knowledge base itself — counts, trends, overdue items, compliance exposure, resolution rates, coverage metrics — use the KnowledgeOpsAnalyst tool. Never use the KnowledgeOpsAnalyst tool to answer a content question, and never use the KnowledgeSearch tool to answer a metrics question. When the question is ambiguous (for example, 'why does finding the right answer take so long'), prefer the KnowledgeOpsAnalyst tool — it is built to answer questions about the system's own performance."
  sample_questions:
    - question: "What is the current sepsis protocol?"
    - question: "Which protocols are overdue for review?"
    - question: "What is our open compliance fine exposure?"
    - question: "How is agent self-resolution trending over the past 6 months?"

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
-- Expected: specification now includes:
--   1. instructions.response — grounding and citation guidance
--   2. instructions.orchestration — the full tool-selection routing logic
--   3. instructions.sample_questions — four sample questions
--   4. tools — both KnowledgeSearch and KnowledgeOpsAnalyst (unchanged)
--   5. tool_resources — both FQN references (unchanged)
--
-- The Snowsight Agent readiness checklist should now tick "Configure instructions"
-- as complete.

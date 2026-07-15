-- Grant additional privileges to ROLE_HK_COMPLIANCE_LEAD for escalation visibility and reassignment.
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- ROLE_HK_COMPLIANCE_LEAD additional grants
-- Persona: Quality/compliance leads who oversee escalations and reassign work.
-- Note: This role already inherits all ROLE_HK_CONTENT_OWNER grants via the
--       role hierarchy established in step_01.
-- Best practice: SECURITYADMIN manages privilege grants.
--------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

-- Escalation visibility
GRANT SELECT ON VIEW DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.HITL_VW_ESCALATIONS TO ROLE ROLE_HK_COMPLIANCE_LEAD;

-- Compliance gap summary for protocol oversight
GRANT SELECT ON VIEW DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.CURATED_VW_COMPLIANCE_GAP_SUMMARY TO ROLE ROLE_HK_COMPLIANCE_LEAD;

-- Reassignment: UPDATE on HITL_TBL_REVIEW_QUEUE is already inherited from
-- ROLE_HK_CONTENT_OWNER (which has SELECT, UPDATE on the full table).
-- The compliance lead uses the inherited UPDATE to change ASSIGNED_OWNER on any
-- row (row access policy in step_06 grants them full-table visibility).
-- No additional table grant needed here.

SHOW GRANTS TO ROLE ROLE_HK_CONTENT_OWNER;
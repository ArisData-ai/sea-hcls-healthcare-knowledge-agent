-- Create and apply row access policy to scope review queue visibility by ownership and role.
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- HITL_RAP_OWNER_SCOPED — Row Access Policy for HITL_TBL_REVIEW_QUEUE
--
-- Logic:
--   - ROLE_HK_ADMIN and ROLE_HK_COMPLIANCE_LEAD see ALL rows (full oversight)
--   - Other roles see only:
--       (a) rows assigned to them (ASSIGNED_OWNER = CURRENT_USER()), OR
--       (b) unassigned rows that are NOT escalated (browsable open queue)
--
-- This ensures content owners can browse unassigned work and see their own
-- items, but cannot see escalated items belonging to someone else.
--------------------------------------------------------------------------------

-- Best practice: SYSADMIN owns the schema objects and can create/apply
-- row access policies on tables it owns. No need for ACCOUNTADMIN.
USE ROLE SYSADMIN;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;

CREATE OR REPLACE ROW ACCESS POLICY DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.HITL_RAP_OWNER_SCOPED
    AS (assigned_owner VARCHAR, escalated_flag BOOLEAN) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('ROLE_HK_ADMIN', 'ROLE_HK_COMPLIANCE_LEAD')
        OR assigned_owner = CURRENT_USER()
        OR (assigned_owner IS NULL AND escalated_flag = FALSE);

--------------------------------------------------------------------------------
-- Apply the policy to HITL_TBL_REVIEW_QUEUE
--------------------------------------------------------------------------------

ALTER TABLE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.HITL_TBL_REVIEW_QUEUE
    ADD ROW ACCESS POLICY DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.HITL_RAP_OWNER_SCOPED
    ON (ASSIGNED_OWNER, ESCALATED_FLAG);

-- Create the six functional RBAC roles for the Healthcare Knowledge Agent and establish the role hierarchy.
-- Co-authored with CoCo

--------------------------------------------------------------------------------
-- 1. Create all six functional roles
--    Best practice: USERADMIN is the designated role for creating custom roles.
--    SECURITYADMIN inherits USERADMIN, so it can also be used here.
--------------------------------------------------------------------------------

USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS ROLE_HK_ADMIN;
CREATE ROLE IF NOT EXISTS ROLE_HK_CONTENT_OWNER;
CREATE ROLE IF NOT EXISTS ROLE_HK_COMPLIANCE_LEAD;
CREATE ROLE IF NOT EXISTS ROLE_HK_CLINICIAN_VIEWER;
CREATE ROLE IF NOT EXISTS ROLE_HK_CORTEX_AGENT_ANALYST;
CREATE ROLE IF NOT EXISTS ROLE_HK_EXEC_VIEWER;

--------------------------------------------------------------------------------
-- 2. Establish role hierarchy
--    Best practice: SECURITYADMIN manages role grants and hierarchy.
--    Application hierarchy: CONTENT_OWNER -> COMPLIANCE_LEAD -> ADMIN
--------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

GRANT ROLE ROLE_HK_CONTENT_OWNER TO ROLE ROLE_HK_COMPLIANCE_LEAD;
GRANT ROLE ROLE_HK_COMPLIANCE_LEAD TO ROLE ROLE_HK_ADMIN;

--------------------------------------------------------------------------------
-- 3. Roll up custom roles to SYSADMIN
--    Best practice: All custom roles should ultimately roll up to SYSADMIN
--    so that SYSADMIN can manage objects owned by these roles, and
--    ACCOUNTADMIN (which inherits SYSADMIN) retains full visibility.
--------------------------------------------------------------------------------

GRANT ROLE ROLE_HK_ADMIN TO ROLE SYSADMIN;
GRANT ROLE ROLE_HK_CLINICIAN_VIEWER TO ROLE SYSADMIN;
GRANT ROLE ROLE_HK_CORTEX_AGENT_ANALYST TO ROLE SYSADMIN;
GRANT ROLE ROLE_HK_EXEC_VIEWER TO ROLE SYSADMIN;

--------------------------------------------------------------------------------
-- 4. Grant warehouse usage to all six roles
--    Best practice: ACCOUNTADMIN or the warehouse owner grants USAGE.
--    Using ACCOUNTADMIN here since it owns/controls the warehouse.
--------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

GRANT USAGE ON WAREHOUSE WH_HCLS_XS TO ROLE ROLE_HK_ADMIN;
GRANT USAGE ON WAREHOUSE WH_HCLS_XS TO ROLE ROLE_HK_CONTENT_OWNER;
GRANT USAGE ON WAREHOUSE WH_HCLS_XS TO ROLE ROLE_HK_COMPLIANCE_LEAD;
GRANT USAGE ON WAREHOUSE WH_HCLS_XS TO ROLE ROLE_HK_CLINICIAN_VIEWER;
GRANT USAGE ON WAREHOUSE WH_HCLS_XS TO ROLE ROLE_HK_CORTEX_AGENT_ANALYST;
GRANT USAGE ON WAREHOUSE WH_HCLS_XS TO ROLE ROLE_HK_EXEC_VIEWER;
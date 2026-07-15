-- =============================================================================
-- SECTION 2 : DML — SYNTHETIC DATA POPULATION
-- Load order must respect FK dependencies:
--   STAFF_ROLES → DOCUMENTS → CLINICAL_PROTOCOLS → REGULATORY_REQUIREMENTS
--   → COMPLIANCE_FINDINGS (needs REGULATORY_REQUIREMENTS)
--   → CONTENT_REVIEW_SCHEDULE (needs CLINICAL_PROTOCOLS)
--   → KNOWLEDGE_QUERIES (needs STAFF_ROLES, DOCUMENTS)
-- =============================================================================

USE ROLE ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE;
USE DATABASE DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS;
USE SCHEMA SCHEMA_HEALTHCARE_KNOWLEDGE;
USE WAREHOUSE WH_HCLS_XS;

-- ----------------------------------------------------------------------------
-- 2.1  STAFF_ROLES
-- ----------------------------------------------------------------------------
INSERT INTO CURATED_TBL_STAFF_ROLES
    (ROLE_CODE, ROLE_DISPLAY_NAME, PERSONA_CATEGORY, ORG_TYPE,
     AVG_QUERIES_PER_DAY, TYPICAL_CONTENT_DOMAIN)
VALUES
    ('CLIN_INF',     'Clinical Informatics Specialist',      'Clinical',    'Health System',    12.4, 'Clinical Protocols, Care Guidelines, Order Sets'),
    ('ICU_NURSE',    'ICU Charge Nurse',                     'Clinical',    'Health System',    18.7, 'ICU Protocols, Medication Guidelines, Sepsis Pathways'),
    ('ED_PHYSICIAN', 'Emergency Department Physician',       'Clinical',    'Health System',    22.1, 'Emergency Protocols, Trauma Guidelines, Triage SOPs'),
    ('PHARM_CLIN',   'Clinical Pharmacist',                  'Clinical',    'Health System',    14.3, 'Drug Protocols, Formulary Policies, Dosing Guidelines'),
    ('COMP_ANAL',    'Compliance Analyst',                   'Compliance',  'Payer',            9.8,  'HIPAA Regulations, CMS Requirements, Audit Guidelines'),
    ('REG_AFF',      'Regulatory Affairs Manager',           'Compliance',  'Pharma',           7.2,  'FDA Guidance, Clinical Trial Regulations, Submission Requirements'),
    ('QUAL_MGR',     'Quality Manager',                      'Compliance',  'Health System',    8.5,  'Joint Commission Standards, Quality Metrics, Accreditation'),
    ('OPS_COORD',    'Operations Coordinator',               'Operational', 'Health System',    6.3,  'Operational SOPs, Administrative Policies, Onboarding Docs'),
    ('ADMIN_STAFF',  'Administrative Staff',                 'Operational', 'Payer',            4.1,  'HR Policies, Process Documentation, Reference Guides'),
    ('IT_ANALYST',   'Health IT Analyst',                    'Operational', 'Health System',    5.7,  'System SOPs, Data Governance Policies, Integration Guides'),
    ('EXEC_CMO',     'Chief Medical Officer',                'Executive',   'Health System',    3.2,  'Executive Summaries, Strategic Protocols, Governance Reports'),
    ('EXEC_CCO',     'Chief Compliance Officer',             'Executive',   'Payer',            2.8,  'Regulatory Summaries, Risk Reports, Board Governance Docs'),
    ('RES_COORD',    'Clinical Research Coordinator',        'Clinical',    'Pharma',           11.5, 'Trial Protocols, Research SOPs, Regulatory Submissions'),
    ('ONCO_NP',      'Oncology Nurse Practitioner',          'Clinical',    'Health System',    16.2, 'Oncology Protocols, Chemotherapy Guidelines, Symptom Management'),
    ('CASE_MGR',     'Case Manager',                         'Operational', 'Health System',    8.9,  'Discharge Protocols, Care Coordination SOPs, Payer Requirements');

-- ----------------------------------------------------------------------------
-- 2.2  DOCUMENTS
--      DOC_REF_KEY values are aligned with the synthetic corpus ingested into
--      the RAG pipeline (KA_DOC_METADATA.source_doc_id).
-- ----------------------------------------------------------------------------
INSERT INTO CURATED_TBL_DOCUMENTS
    (DOC_REF_KEY, DOC_TITLE, DOC_TYPE, CONTENT_DOMAIN, SOURCE_SYSTEM,
     OWNING_DEPARTMENT, ORG_TYPE_TARGET, VERSION_LABEL, STATUS,
     PUBLISHED_DATE, LAST_REVIEWED_DATE, NEXT_REVIEW_DATE,
     WORD_COUNT, CHUNK_COUNT, INGESTED_AT)
VALUES
    ('DOC-001', 'Sepsis Recognition and Management Protocol — ICU',                        'Clinical Protocol',    'Clinical',    'PolicyStat',  'Critical Care',     'Health System', 'v4.2', 'Active',        '2024-01-15', '2024-09-10', '2025-01-15', 3840, 28, '2025-11-01 08:12:00'),
    ('DOC-002', 'Ventilator-Associated Pneumonia Prevention Bundle',                       'Clinical Protocol',    'Clinical',    'PolicyStat',  'Pulmonology',       'Health System', 'v3.0', 'Active',        '2023-07-01', '2024-07-05', '2025-07-01', 2910, 21, '2025-11-01 08:15:00'),
    ('DOC-003', 'HIPAA Privacy Rule — Minimum Necessary Standard Guidance',                'Regulatory Guidance',  'Regulatory',  'SharePoint',  'Compliance',        'Payer',         'v2.1', 'Active',        '2023-03-20', '2024-11-30', '2025-09-20', 1750, 13, '2025-11-01 08:18:00'),
    ('DOC-004', 'CMS Prior Authorization Turnaround Requirements — MA Plans',              'Regulatory Guidance',  'Regulatory',  'SharePoint',  'Compliance',        'Payer',         'v1.4', 'Active',        '2024-04-01', '2024-10-15', '2025-10-01', 2100, 16, '2025-11-01 08:21:00'),
    ('DOC-005', 'Emergency Department Triage and Rapid Assessment SOP',                    'SOP',                  'Clinical',    'PolicyStat',  'Emergency Medicine','Health System', 'v5.1', 'Active',        '2023-11-10', '2024-08-22', '2025-11-10', 4200, 31, '2025-11-01 08:24:00'),
    ('DOC-006', 'Medication Reconciliation Policy — Admission and Discharge',              'Policy',               'Clinical',    'PolicyStat',  'Pharmacy',          'Health System', 'v2.8', 'Active',        '2024-02-14', '2024-12-01', '2025-08-14', 1980, 15, '2025-11-01 08:27:00'),
    ('DOC-007', 'Phase II Oncology Clinical Trial Protocol — Solid Tumors',                'Research Archive',     'Research',    'PolicyTech',  'Oncology Research', 'Pharma',        'v1.0', 'Active',        '2022-06-01', '2023-12-10', '2024-06-01', 8700, 64, '2025-11-01 08:30:00'),
    ('DOC-008', 'Joint Commission NPSG.01.01.01 — Patient Identification Requirements',   'Regulatory Guidance',  'Regulatory',  'SharePoint',  'Quality',           'Health System', 'v6.0', 'Active',        '2024-01-01', '2024-06-30', '2025-01-01', 1420, 11, '2025-11-01 08:33:00'),
    ('DOC-009', 'New Employee Clinical Onboarding Handbook — Nursing Staff',               'SOP',                  'Operational', 'PolicyTech',  'Human Resources',   'Health System', 'v3.3', 'Active',        '2023-09-01', '2024-09-01', '2025-09-01', 5100, 38, '2025-11-01 08:36:00'),
    ('DOC-010', 'Hand Hygiene Compliance and Audit Protocol',                              'Clinical Protocol',    'Clinical',    'PolicyStat',  'Infection Control', 'Health System', 'v4.0', 'Active',        '2023-05-15', '2024-05-14', '2025-05-15', 2250, 17, '2025-11-01 08:39:00'),
    ('DOC-011', 'FDA IND Application Requirements — Phase I/II Submissions',               'Regulatory Guidance',  'Regulatory',  'SharePoint',  'Regulatory Affairs','Pharma',        'v2.0', 'Active',        '2023-12-01', '2024-11-01', '2025-12-01', 3300, 24, '2025-11-01 08:42:00'),
    ('DOC-012', 'Payer Claims Adjudication Policy — Medical Necessity Review',             'Policy',               'Regulatory',  'PolicyTech',  'Claims Operations', 'Payer',         'v1.9', 'Active',        '2024-03-10', '2024-09-30', '2025-03-10', 2640, 19, '2025-11-01 08:45:00'),
    ('DOC-013', 'Discharge Planning and Care Transitions SOP',                             'SOP',                  'Operational', 'PolicyStat',  'Case Management',   'Health System', 'v2.4', 'Active',        '2023-10-20', '2024-10-18', '2025-10-20', 3100, 23, '2025-11-01 08:48:00'),
    ('DOC-014', 'Chemotherapy Administration Safety Protocol — Inpatient',                 'Clinical Protocol',    'Clinical',    'PolicyStat',  'Oncology',          'Health System', 'v3.7', 'Active',        '2024-05-01', '2024-11-15', '2025-05-01', 4800, 35, '2025-11-01 08:51:00'),
    ('DOC-015', 'Remote Work Data Access and Security Policy — Payer Operations',          'Policy',               'Operational', 'SharePoint',  'IT Security',       'Payer',         'v1.2', 'Active',        '2023-08-15', '2024-08-12', '2025-08-15', 1640, 12, '2025-11-01 08:54:00'),
    ('DOC-016', 'Anticoagulation Therapy Monitoring Protocol',                             'Clinical Protocol',    'Clinical',    'PolicyStat',  'Pharmacy',          'Health System', 'v2.5', 'Active',        '2024-06-10', '2024-12-08', '2025-06-10', 2760, 20, '2025-11-01 08:57:00'),
    ('DOC-017', 'HEDIS Measure Specifications — Preventive Care Quality Reporting',        'Regulatory Guidance',  'Regulatory',  'SharePoint',  'Quality Analytics', 'Payer',         'v2024.1', 'Active',    '2024-01-05', '2024-07-01', '2025-01-05', 3900, 29, '2025-11-01 09:00:00'),
    ('DOC-018', 'Surgical Site Infection Prevention Bundle — Perioperative',               'Clinical Protocol',    'Clinical',    'PolicyStat',  'Surgical Services', 'Health System', 'v3.1', 'Under Review',  '2023-04-10', '2023-10-05', '2024-04-10', 3350, 25, '2025-11-01 09:03:00'),
    ('DOC-019', 'Clinical Trial Data Integrity and GCP Compliance Policy',                 'Policy',               'Research',    'PolicyTech',  'Clinical Research', 'Pharma',        'v1.6', 'Active',        '2023-07-20', '2024-07-18', '2025-07-20', 2490, 18, '2025-11-01 09:06:00'),
    ('DOC-020', 'Stroke Care Pathway — Acute Ischemic Stroke Protocol',                    'Clinical Protocol',    'Clinical',    'PolicyStat',  'Neurology',         'Health System', 'v4.5', 'Active',        '2024-03-01', '2024-09-01', '2025-03-01', 4100, 30, '2025-11-01 09:09:00'),
    ('DOC-021', 'Employee Grievance and Workplace Conduct Policy',                         'Policy',               'Operational', 'PolicyTech',  'Human Resources',   'Health System', 'v2.0', 'Archived',      '2021-02-01', '2022-02-01', '2023-02-01', 1900, 14, '2025-11-01 09:12:00'),
    ('DOC-022', 'Radiology Contrast Agent Administration and Safety Protocol',             'Clinical Protocol',    'Clinical',    'PolicyStat',  'Radiology',         'Health System', 'v2.3', 'Active',        '2023-06-15', '2024-06-12', '2025-06-15', 2800, 21, '2025-11-01 09:15:00'),
    ('DOC-023', 'State Medicaid Prior Authorization — Behavioral Health Requirements',     'Regulatory Guidance',  'Regulatory',  'SharePoint',  'Compliance',        'Payer',         'v1.1', 'Active',        '2024-07-01', '2024-11-20', '2025-07-01', 1860, 14, '2025-11-01 09:18:00');

-- ----------------------------------------------------------------------------
-- 2.3  CLINICAL_PROTOCOLS
-- ----------------------------------------------------------------------------
INSERT INTO CURATED_TBL_CLINICAL_PROTOCOLS
    (PROTOCOL_CODE, PROTOCOL_NAME, CLINICAL_CATEGORY, APPLICABLE_CARE_SETTING,
     OWNING_SPECIALTY, EVIDENCE_GRADE, CURRENT_VERSION, VERSION_EFFECTIVE_DATE,
     PRIOR_VERSION, STATUS, COMPLIANCE_RISK_LEVEL, REGULATORY_STANDARD,
     LAST_REVIEWED_DATE, NEXT_REVIEW_DUE_DATE, TOTAL_REVISIONS,
     AVERAGE_ADHERENCE_PCT, LINKED_DOC_REF_KEY)
VALUES
    ('PROT-ICU-001',  'Sepsis Bundle — Early Recognition and 3-Hour Management',   'ICU',              'ICU',        'Critical Care',    'A',  'v4.2', '2024-01-15', 'v4.1', 'Active',        'High',   'CMS SEP-1',            '2024-09-10', '2025-01-15',  9,  91.4, 'DOC-001'),
    ('PROT-ICU-002',  'Ventilator-Associated Pneumonia Prevention Bundle',          'ICU',              'ICU',        'Pulmonology',      'A',  'v3.0', '2023-07-01', 'v2.9', 'Active',        'High',   'Joint Commission',     '2024-07-05', '2025-07-01',  6,  88.7, 'DOC-002'),
    ('PROT-ED-001',   'ED Triage and Rapid Medical Assessment Protocol',             'Emergency',        'ED',         'Emergency Med',    'B',  'v5.1', '2023-11-10', 'v5.0', 'Active',        'High',   'Joint Commission',     '2024-08-22', '2025-11-10', 12,  94.2, 'DOC-005'),
    ('PROT-PHARM-001','Medication Reconciliation — Admission, Transfer, Discharge', 'Pharmacy',         'All',        'Pharmacy',         'A',  'v2.8', '2024-02-14', 'v2.7', 'Active',        'High',   'NPSG.03.06.01',        '2024-12-01', '2025-08-14',  5,  87.3, 'DOC-006'),
    ('PROT-INF-001',  'Hand Hygiene Compliance Program',                            'Infection Control','All',        'Infection Control','A',  'v4.0', '2023-05-15', 'v3.9', 'Active',        'Medium', 'CDC / Joint Commission','2024-05-14', '2025-05-15',  8,  82.1, 'DOC-010'),
    ('PROT-ONCO-001', 'Inpatient Chemotherapy Administration Safety Protocol',      'Oncology',         'Inpatient',  'Oncology',         'A',  'v3.7', '2024-05-01', 'v3.6', 'Active',        'High',   'ASCO/ONS Standards',   '2024-11-15', '2025-05-01',  7,  96.8, 'DOC-014'),
    ('PROT-ONCO-002', 'Oncology Symptom Management and Supportive Care Guidelines', 'Oncology',         'All',        'Oncology',         'B',  'v2.2', '2023-12-01', 'v2.1', 'Active',        'Medium', 'NCCN Guidelines',      '2024-06-10', '2024-12-01',  4,  78.5, NULL),
    ('PROT-NEUR-001', 'Acute Ischemic Stroke — Door-to-Needle Protocol',            'Neurology',        'ED/Inpatient','Neurology',       'A',  'v4.5', '2024-03-01', 'v4.4', 'Active',        'High',   'AHA/ASA Guidelines',   '2024-09-01', '2025-03-01', 11,  93.1, 'DOC-020'),
    ('PROT-SURG-001', 'Surgical Site Infection Prevention — Perioperative Bundle',  'Surgical',         'OR/Inpatient','Surgical Services','A',  'v3.1', '2023-04-10', 'v3.0', 'Under Review',  'High',   'CDC/NHSN SCIP',        '2023-10-05', '2024-04-10',  6,  84.9, 'DOC-018'),
    ('PROT-RAD-001',  'Contrast Agent Administration and Adverse Reaction Protocol', 'Radiology',        'All',        'Radiology',        'B',  'v2.3', '2023-06-15', 'v2.2', 'Active',        'Medium', 'ACR Guidelines',       '2024-06-12', '2025-06-15',  4,  90.3, 'DOC-022'),
    ('PROT-PHARM-002','Anticoagulation Therapy Monitoring and Adjustment Protocol', 'Pharmacy',         'All',        'Pharmacy/Hematology','A', 'v2.5', '2024-06-10', 'v2.4', 'Active',       'High',   'ACCP Guidelines',      '2024-12-08', '2025-06-10',  5,  89.6, 'DOC-016'),
    ('PROT-INF-002',  'CLABSI Prevention Bundle — Central Line Insertion',          'Infection Control','ICU',        'Infection Control','A',  'v3.5', '2024-04-20', 'v3.4', 'Active',        'High',   'CDC/Joint Commission', '2024-10-20', '2025-04-20',  7,  86.4, NULL),
    ('PROT-OB-001',   'Obstetric Hemorrhage Prevention and Management Protocol',    'Obstetrics',       'Labor & Delivery','OB/GYN',      'A',  'v2.0', '2023-09-15', 'v1.9', 'Active',        'High',   'AWHONN / ACOG',        '2024-09-12', '2025-09-15',  3,  91.8, NULL),
    ('PROT-PEDI-001', 'Pediatric Fever Assessment and Antibiotic Stewardship',      'Pediatrics',       'Pediatric Units','Pediatrics',   'B',  'v1.8', '2023-11-01', 'v1.7', 'Active',        'Medium', 'AAP Guidelines',       '2024-11-01', '2025-11-01',  3,  77.2, NULL),
    ('PROT-PSYCH-001','Inpatient Psychiatric Patient Safety and Seclusion Protocol','Behavioral Health','Psych Units','Psychiatry',       'C',  'v3.2', '2024-07-01', 'v3.1', 'Active',        'High',   'CMS CoP / State',      '2024-11-30', '2025-07-01',  8,  85.0, NULL);

-- ----------------------------------------------------------------------------
-- 2.4  REGULATORY_REQUIREMENTS
-- ----------------------------------------------------------------------------
INSERT INTO CURATED_TBL_REGULATORY_REQUIREMENTS
    (REQUIREMENT_CODE, REGULATION_BODY, REGULATION_NAME,
     REQUIREMENT_TITLE, REQUIREMENT_CATEGORY, APPLICABLE_ORG_TYPE,
     JURISDICTION, ENFORCEMENT_LEVEL, PENALTY_RANGE_USD,
     REVIEW_FREQUENCY, EFFECTIVE_DATE, LAST_UPDATED_DATE)
VALUES
    ('HIPAA-164-514',  'HIPAA',             'HIPAA Privacy Rule',                              'Minimum Necessary Standard — PHI Access',              'Privacy',       'Payer',         'Federal',       'Mandatory',   '$100 – $50,000 per violation',     'Annual',         '2003-04-14', '2024-01-01'),
    ('HIPAA-164-308',  'HIPAA',             'HIPAA Security Rule',                             'Administrative Safeguards for ePHI',                   'Privacy',       'Health System', 'Federal',       'Mandatory',   '$100 – $50,000 per violation',     'Annual',         '2005-04-20', '2024-01-01'),
    ('CMS-SEP1',       'CMS',               'Medicare Inpatient Quality Reporting',            'Sepsis Bundle Compliance (SEP-1)',                     'Quality',       'Health System', 'Federal',       'Mandatory',   'Payment adjustment up to 2%',      'Continuous',     '2015-10-01', '2024-04-01'),
    ('CMS-MA-PA',      'CMS',               'Medicare Advantage Regulations',                  'Prior Authorization Turnaround — 72hr Urgent Standard', 'Clinical',     'Payer',         'Federal',       'Mandatory',   '$10,000 per day non-compliance',   'Continuous',     '2024-01-01', '2024-04-01'),
    ('JC-NPSG-01',     'Joint Commission',  'National Patient Safety Goals',                   'Patient Identification — Two Identifiers Required',    'Safety',        'Health System', 'Accreditation', 'Mandatory',   'Accreditation Risk',               'Annual',         '2024-01-01', '2024-01-01'),
    ('JC-NPSG-07',     'Joint Commission',  'National Patient Safety Goals',                   'Healthcare-Associated Infection Reduction',             'Safety',        'Health System', 'Accreditation', 'Mandatory',   'Accreditation Risk',               'Annual',         '2024-01-01', '2024-01-01'),
    ('FDA-21CFR312',   'FDA',               '21 CFR Part 312 — IND Regulations',               'IND Application and Clinical Trial Conduct',           'Documentation', 'Pharma',        'Federal',       'Mandatory',   'Clinical hold / criminal penalty',  'Event-Driven',  '1987-06-20', '2024-03-01'),
    ('FDA-GCP-E6',     'FDA',               'ICH E6 Good Clinical Practice',                   'Data Integrity and Source Documentation',              'Documentation', 'Pharma',        'Federal',       'Mandatory',   'Warning letter / debarment',       'Continuous',     '2018-03-01', '2023-11-01'),
    ('HEDIS-2024',     'NCQA',              'HEDIS Measure Specifications 2024',               'Preventive Care and Chronic Disease Management Rates', 'Quality',       'Payer',         'Federal',       'Conditional', 'Star rating impact',               'Annual',         '2024-01-01', '2024-01-01'),
    ('STATE-MEDI-BH',  'State',             'State Medicaid — Behavioral Health Regulations',  'Prior Authorization — Behavioral Health Services',     'Clinical',      'Payer',         'State',         'Mandatory',   'Contract termination risk',        'Annual',         '2024-07-01', '2024-07-01'),
    ('JC-PC-05',       'Joint Commission',  'Perinatal Care Standards',                        'Obstetric Hemorrhage Risk Assessment and Response',    'Safety',        'Health System', 'Accreditation', 'Mandatory',   'Accreditation Risk',               'Annual',         '2023-01-01', '2024-01-01'),
    ('CMS-COP-482',    'CMS',               'Conditions of Participation — Hospitals',         'Patient Rights and Psychiatric Patient Restraint',     'Safety',        'Health System', 'Federal',       'Mandatory',   'Medicare termination risk',        'Continuous',     '2019-11-29', '2023-09-01');

-- ----------------------------------------------------------------------------
-- 2.5  COMPLIANCE_FINDINGS
--      Depends on CURATED_TBL_REGULATORY_REQUIREMENTS (requirement IDs 1–12)
-- ----------------------------------------------------------------------------
INSERT INTO CURATED_TBL_COMPLIANCE_FINDINGS
    (REQUIREMENT_ID, FINDING_DATE, FINDING_SOURCE, FINDING_TYPE,
     SEVERITY, FINDING_DESCRIPTION, AFFECTED_DEPARTMENT,
     REMEDIATION_OWNER, REMEDIATION_DUE_DATE, REMEDIATION_STATUS,
     RESOLVED_DATE, ESTIMATED_FINE_EXPOSURE, RESOLUTION_NOTES)
VALUES
    (1,  '2025-01-14', 'Internal Audit',    'Minor Gap',       'Low',      'Business associate subcontractor agreement missing annual attestation.',                                           'Legal / Vendor Mgmt',    'Chief Privacy Officer',    '2025-03-31', 'In Progress', NULL,         5000.00,    NULL),
    (1,  '2024-09-05', 'External Audit',    'Non-Conformance', 'Medium',   'PHI shared with analytics vendor without data use amendment in place.',                                            'Data Analytics',         'Compliance Director',      '2024-11-30', 'Resolved',    '2024-11-18', 25000.00,   'DUA executed; vendor re-trained'),
    (2,  '2025-02-20', 'Self-Assessment',   'Observation',     'Low',      'Audit log review cadence not meeting quarterly requirement for EHR system.',                                       'Health IT',              'CISO',                     '2025-04-30', 'In Progress', NULL,         10000.00,   NULL),
    (3,  '2024-12-10', 'Internal Audit',    'Non-Conformance', 'High',     'SEP-1 bundle completion rate below CMS threshold in Q3 — 71% vs 85% target.',                                    'Critical Care',          'CMO',                      '2025-02-28', 'In Progress', NULL,         0.00,       'Payment adj. risk estimated 1.2%'),
    (3,  '2024-03-18', 'External Audit',    'Major Gap',       'Critical', 'Sepsis 3-hour bundle not initiated within required window in 18% of qualifying cases.',                           'Emergency Medicine',     'ED Medical Director',      '2024-07-01', 'Resolved',    '2024-06-28', 0.00,       'ED protocol retrained; alert added'),
    (4,  '2025-01-30', 'Incident Report',   'Non-Conformance', 'High',     'Prior authorization for urgent procedure not processed within CMS 72-hour standard in 43 member cases.',           'Utilization Management', 'VP Operations',            '2025-03-15', 'In Progress', NULL,         430000.00,  NULL),
    (5,  '2024-11-05', 'External Audit',    'Observation',     'Low',      'Wristband printing delay causing single-identifier workaround in ED.',                                            'Emergency Services',     'Patient Safety Officer',   '2025-01-31', 'Resolved',    '2025-01-15', 0.00,       'New wristband station installed in ED'),
    (6,  '2025-02-28', 'Internal Audit',    'Minor Gap',       'Medium',   'Hand hygiene observation compliance at 68% in surgical prep — below 80% target.',                                 'Surgical Services',      'Infection Preventionist',  '2025-04-15', 'Scheduled',   NULL,         0.00,       NULL),
    (7,  '2024-10-22', 'Self-Assessment',   'Observation',     'Medium',   'IND safety report submission timeline missed by 5 days in one adverse event case.',                               'Pharmacovigilance',      'VP Regulatory Affairs',    '2024-12-31', 'Resolved',    '2024-12-10', 0.00,       'Process revised; SOP updated'),
    (8,  '2024-08-14', 'External Audit',    'Non-Conformance', 'High',     'Source data verification gap found in Phase II trial — 12% of records lacked original documentation.',           'Clinical Data Mgmt',     'Head of Data Integrity',   '2024-12-31', 'Resolved',    '2024-11-30', 0.00,       'Retrospective SDV completed; audit trail corrected'),
    (9,  '2025-01-07', 'Internal Audit',    'Observation',     'Low',      'Breast cancer screening HEDIS measure 3 points below benchmark — documentation gaps identified.',                 'Quality Analytics',      'Quality Director',         '2025-06-30', 'In Progress', NULL,         0.00,       'Star rating impact if not resolved'),
    (10, '2024-12-20', 'External Audit',    'Non-Conformance', 'Medium',   'Behavioral health PA turnaround averages 6.2 days vs 5-day State Medicaid standard.',                            'Utilization Management', 'Medical Director',         '2025-03-31', 'In Progress', NULL,         0.00,       NULL),
    (11, '2024-07-30', 'Internal Audit',    'Minor Gap',       'Low',      'Obstetric hemorrhage risk scoring not documented for 11% of admitted labor patients.',                            'Labor and Delivery',     'Chief Nursing Officer',    '2024-10-31', 'Resolved',    '2024-10-20', 0.00,       'Risk scoring integrated into admission workflow'),
    (12, '2025-03-01', 'Self-Assessment',   'Non-Conformance', 'High',     'Seclusion documentation missing physician co-signature in 22% of sampled events — CMS CoP violation.',          'Behavioral Health',      'Psychiatry Medical Dir.',  '2025-05-01', 'Open',        NULL,         0.00,       'Medicare CoP risk; corrective plan filed'),
    (4,  '2024-06-18', 'External Audit',    'Non-Conformance', 'Critical', 'Prior auth denials issued without required clinical review documentation — 310 member cases Q1.',                'Claims Operations',      'Chief Medical Officer',    '2024-09-30', 'Resolved',    '2024-09-25', 3100000.00, 'Settlement reached; process overhauled');

-- ----------------------------------------------------------------------------
-- 2.6  CONTENT_REVIEW_SCHEDULE
--      Depends on CURATED_TBL_CLINICAL_PROTOCOLS (protocol IDs 1–15)
-- ----------------------------------------------------------------------------
INSERT INTO CURATED_TBL_CONTENT_REVIEW_SCHEDULE
    (PROTOCOL_ID, SCHEDULED_DATE, REVIEW_TYPE, ASSIGNED_REVIEWER,
     REVIEWER_SPECIALTY, STATUS, ACTUAL_COMPLETION_DATE, OUTCOME, OUTCOME_NOTES)
VALUES
    (1,  '2025-01-15', 'Periodic',      'Dr. Sarah Chen',            'Critical Care',    'Completed',  '2025-01-12', 'Minor Update',   'Updated vasopressor thresholds per surviving sepsis campaign 2024'),
    (2,  '2025-07-01', 'Periodic',      'Dr. James Okafor',          'Pulmonology',      'Scheduled',   NULL,         NULL,             NULL),
    (3,  '2025-11-10', 'Periodic',      'Dr. Maria Reyes',           'Emergency Med',    'Scheduled',   NULL,         NULL,             NULL),
    (4,  '2025-08-14', 'Periodic',      'PharmD Lucas Patel',        'Pharmacy',         'Scheduled',   NULL,         NULL,             NULL),
    (5,  '2024-05-14', 'Periodic',      'Dr. Amara Nwosu',           'Infection Control','Completed',  '2024-05-10', 'No Change',      'CDC guidance unchanged; protocol confirmed current'),
    (5,  '2025-05-15', 'Periodic',      'Dr. Amara Nwosu',           'Infection Control','Scheduled',   NULL,         NULL,             NULL),
    (6,  '2025-05-01', 'Periodic',      'Dr. Elena Kim',             'Oncology',         'Scheduled',   NULL,         NULL,             NULL),
    (7,  '2024-12-01', 'Periodic',      'Dr. Ravi Sharma',           'Oncology',         'Overdue',     NULL,         NULL,             NULL),
    (8,  '2025-03-01', 'Periodic',      'Dr. Thomas Wright',         'Neurology',        'Scheduled',   NULL,         NULL,             NULL),
    (9,  '2024-04-10', 'Periodic',      'Dr. Priya Mehta',           'Surgical Services','Overdue',     NULL,         NULL,             'Under regulatory review; pending external advisory panel'),
    (9,  '2025-04-15', 'Post-Incident', 'Dr. Priya Mehta',           'Surgical Services','Scheduled',   NULL,         NULL,             NULL),
    (10, '2025-06-15', 'Periodic',      'Dr. Omar Hassan',           'Radiology',        'Scheduled',   NULL,         NULL,             NULL),
    (11, '2025-06-10', 'Periodic',      'PharmD Diana Torres',       'Pharmacy/Hematology','Scheduled', NULL,         NULL,             NULL),
    (12, '2025-04-20', 'Periodic',      'Dr. Amara Nwosu',           'Infection Control','Scheduled',   NULL,         NULL,             NULL),
    (13, '2025-09-15', 'Periodic',      'Dr. Fatima Osei',           'OB/GYN',           'Scheduled',   NULL,         NULL,             NULL),
    (14, '2024-11-01', 'Periodic',      'Dr. Kenji Yamamoto',        'Pediatrics',       'Completed',  '2024-10-28', 'Minor Update',   'AAP 2024 fever algorithm incorporated'),
    (15, '2025-07-01', 'Periodic',      'Dr. Amanda Brooks',         'Psychiatry',       'Scheduled',   NULL,         NULL,             NULL),
    (1,  '2023-09-15', 'Triggered',     'Dr. Sarah Chen',            'Critical Care',    'Completed',  '2023-09-18', 'Major Revision', 'Surviving Sepsis Campaign 2023 update incorporated'),
    (3,  '2024-08-22', 'Periodic',      'Dr. Maria Reyes',           'Emergency Med',    'Completed',  '2024-08-19', 'No Change',      'Annual review complete; triage criteria validated');

-- ----------------------------------------------------------------------------
-- 2.7  KNOWLEDGE_QUERIES
--      Represents 6 months of query volume across all personas and org types.
-- ----------------------------------------------------------------------------
INSERT INTO CURATED_TBL_KNOWLEDGE_QUERIES
    (QUERY_DATE, QUERY_TIMESTAMP, ROLE_CODE, ORG_TYPE, QUERY_CATEGORY,
     QUERY_TOPIC, RESOLUTION_CHANNEL, TIME_TO_RESOLUTION_MIN,
     RESOLVED_DOC_REF_KEY, ANSWER_CONFIDENCE, WAS_KNOWLEDGE_GAP,
     SATISFACTION_SCORE, ESCALATED_FLAG)
VALUES
-- December 2024
('2024-12-02', '2024-12-02 08:14:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Sepsis 3-hour bundle criteria',                   'Cortex Search', 0.8,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2024-12-02', '2024-12-02 09:30:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'HIPAA minimum necessary PHI disclosure rules',     'Cortex Search', 1.2,  'DOC-003', 'High',     FALSE, 5, FALSE),
('2024-12-03', '2024-12-03 10:05:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'Stroke door-to-needle time requirements',           'Cortex Search', 0.6,  'DOC-020', 'High',     FALSE, 5, FALSE),
('2024-12-03', '2024-12-03 11:45:00', 'ADMIN_STAFF',  'Payer',         'Operational', 'New employee onboarding checklist steps',           'Cortex Search', 2.1,  'DOC-009', 'Medium',   FALSE, 4, FALSE),
('2024-12-04', '2024-12-04 07:58:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Anticoagulation INR target ranges for A-fib',      'Cortex Search', 1.5,  'DOC-016', 'High',     FALSE, 5, FALSE),
('2024-12-05', '2024-12-05 14:22:00', 'REG_AFF',      'Pharma',        'Regulatory',  'IND safety reporting timeline requirements',        'Cortex Search', 1.8,  'DOC-011', 'High',     FALSE, 5, FALSE),
('2024-12-06', '2024-12-06 09:10:00', 'QUAL_MGR',     'Health System', 'Regulatory',  'NPSG patient identification two-identifier rule',  'Cortex Search', 0.9,  'DOC-008', 'High',     FALSE, 5, FALSE),
('2024-12-09', '2024-12-09 13:40:00', 'ONCO_NP',      'Health System', 'Clinical',    'Chemotherapy vesicant extravasation management',   'Manual Lookup',  42.0, NULL,      'Low',      TRUE,  2, TRUE),
('2024-12-10', '2024-12-10 08:50:00', 'ICU_NURSE',    'Health System', 'Clinical',    'CLABSI bundle dressing change frequency',          'Cortex Search', 1.1,  'DOC-001', 'Medium',   FALSE, 4, FALSE),
('2024-12-11', '2024-12-11 10:15:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'CMS prior authorization 72-hour urgent standard',  'Cortex Search', 1.4,  'DOC-004', 'High',     FALSE, 5, FALSE),
('2024-12-12', '2024-12-12 15:30:00', 'OPS_COORD',    'Health System', 'Operational', 'Discharge planning timeline requirements',          'Cortex Search', 2.3,  'DOC-013', 'High',     FALSE, 4, FALSE),
('2024-12-13', '2024-12-13 07:45:00', 'RES_COORD',    'Pharma',        'Research',    'GCP source document verification requirements',     'Cortex Search', 2.0,  'DOC-019', 'High',     FALSE, 5, FALSE),
('2024-12-16', '2024-12-16 09:25:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'Contrast allergy premedication protocol',          'Cortex Search', 0.7,  'DOC-022', 'High',     FALSE, 5, FALSE),
('2024-12-17', '2024-12-17 11:00:00', 'CASE_MGR',     'Health System', 'Operational', 'SNF readmission criteria and documentation',       'Manual Lookup',  35.0, NULL,      'Low',      TRUE,  2, TRUE),
('2024-12-18', '2024-12-18 14:05:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Medication reconciliation required at discharge',   'Cortex Search', 1.6,  'DOC-006', 'High',     FALSE, 5, FALSE),
('2024-12-19', '2024-12-19 08:30:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'HEDIS breast cancer screening documentation needs', 'Cortex Search', 1.9,  'DOC-017', 'High',     FALSE, 4, FALSE),
('2024-12-20', '2024-12-20 10:40:00', 'CLIN_INF',     'Health System', 'Clinical',    'VAP bundle component compliance verification',     'Cortex Search', 1.3,  'DOC-002', 'High',     FALSE, 5, FALSE),
('2024-12-23', '2024-12-23 09:00:00', 'REG_AFF',      'Pharma',        'Research',    'Phase II trial protocol deviation reporting',       'Cortex Search', 2.2,  'DOC-007', 'Medium',   FALSE, 4, FALSE),
-- January 2025
('2025-01-06', '2025-01-06 08:10:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Updated sepsis vasopressor thresholds',            'Cortex Search', 0.9,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2025-01-07', '2025-01-07 09:45:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'State Medicaid behavioral health PA requirements',  'Cortex Search', 1.5,  'DOC-023', 'High',     FALSE, 5, FALSE),
('2025-01-08', '2025-01-08 11:20:00', 'QUAL_MGR',     'Health System', 'Regulatory',  'Joint Commission hand hygiene observation targets', 'Cortex Search', 1.0,  'DOC-010', 'High',     FALSE, 5, FALSE),
('2025-01-09', '2025-01-09 14:00:00', 'ONCO_NP',      'Health System', 'Clinical',    'Inpatient chemo double-check verification steps',   'Cortex Search', 1.2,  'DOC-014', 'High',     FALSE, 5, FALSE),
('2025-01-10', '2025-01-10 07:50:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'tPA eligibility exclusion criteria for stroke',    'Cortex Search', 0.8,  'DOC-020', 'High',     FALSE, 5, FALSE),
('2025-01-13', '2025-01-13 10:30:00', 'ADMIN_STAFF',  'Payer',         'Operational', 'Remote work data access security requirements',     'Cortex Search', 2.5,  'DOC-015', 'High',     FALSE, 4, FALSE),
('2025-01-14', '2025-01-14 09:15:00', 'CLIN_INF',     'Health System', 'Clinical',    'Sepsis screening trigger criteria in ED',          'Cortex Search', 1.1,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2025-01-15', '2025-01-15 13:45:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'Claims adjudication medical necessity criteria',    'Cortex Search', 1.7,  'DOC-012', 'High',     FALSE, 4, FALSE),
('2025-01-16', '2025-01-16 08:35:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Prone positioning protocol for ARDS',              'Unresolved',     NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-01-17', '2025-01-17 10:05:00', 'REG_AFF',      'Pharma',        'Regulatory',  'FDA SUSAR reporting definition and timeline',      'Cortex Search', 1.4,  'DOC-011', 'High',     FALSE, 5, FALSE),
('2025-01-20', '2025-01-20 09:00:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Heparin drip titration protocol',                  'Cortex Search', 1.0,  'DOC-016', 'High',     FALSE, 5, FALSE),
('2025-01-21', '2025-01-21 11:30:00', 'RES_COORD',    'Pharma',        'Research',    'Eligibility criteria for solid tumor trial',       'Cortex Search', 2.8,  'DOC-007', 'High',     FALSE, 5, FALSE),
-- February 2025
('2025-02-03', '2025-02-03 08:20:00', 'ICU_NURSE',    'Health System', 'Clinical',    'CLABSI prevention — catheter site care frequency', 'Cortex Search', 0.9,  'DOC-001', 'Medium',   FALSE, 4, FALSE),
('2025-02-04', '2025-02-04 09:55:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'HIPAA breach notification 60-day rule',            'Cortex Search', 1.3,  'DOC-003', 'High',     FALSE, 5, FALSE),
('2025-02-05', '2025-02-05 10:40:00', 'QUAL_MGR',     'Health System', 'Regulatory',  'SSI prevention perioperative antibiotic timing',   'Cortex Search', 1.1,  'DOC-018', 'Medium',   FALSE, 3, FALSE),
('2025-02-06', '2025-02-06 07:30:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'Trauma activation criteria — Level 1 vs Level 2',  'Unresolved',    NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-02-10', '2025-02-10 14:20:00', 'CASE_MGR',     'Health System', 'Operational', 'Home health discharge criteria and referral SOP',  'Cortex Search', 2.6,  'DOC-013', 'High',     FALSE, 4, FALSE),
('2025-02-11', '2025-02-11 09:05:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Warfarin reversal protocol for emergent surgery',  'Cortex Search', 1.4,  'DOC-016', 'High',     FALSE, 5, FALSE),
('2025-02-12', '2025-02-12 11:15:00', 'ONCO_NP',      'Health System', 'Clinical',    'Ondansetron dosing for chemo-induced nausea',      'Cortex Search', 0.8,  'DOC-014', 'High',     FALSE, 5, FALSE),
('2025-02-13', '2025-02-13 13:50:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'HEDIS colorectal cancer screening measure specs',   'Cortex Search', 1.6,  'DOC-017', 'High',     FALSE, 5, FALSE),
('2025-02-14', '2025-02-14 08:45:00', 'REG_AFF',      'Pharma',        'Regulatory',  'ICH E6 R2 essential document requirements',        'Cortex Search', 2.1,  'DOC-019', 'High',     FALSE, 5, FALSE),
('2025-02-18', '2025-02-18 10:20:00', 'OPS_COORD',    'Health System', 'Operational', 'Hand hygiene observer certification requirements',  'Cortex Search', 1.8,  'DOC-010', 'Medium',   FALSE, 3, FALSE),
('2025-02-19', '2025-02-19 09:35:00', 'CLIN_INF',     'Health System', 'Clinical',    'VAP bundle — HOB elevation degree requirement',    'Cortex Search', 1.0,  'DOC-002', 'High',     FALSE, 5, FALSE),
('2025-02-20', '2025-02-20 11:50:00', 'EXEC_CMO',     'Health System', 'Clinical',    'Summary of overdue protocol reviews',              'Manual Lookup',  28.0, NULL,      'Low',      FALSE, 3, FALSE),
('2025-02-21', '2025-02-21 14:30:00', 'IT_ANALYST',   'Health System', 'Operational', 'ePHI audit log retention requirements HIPAA',      'Cortex Search', 1.5,  'DOC-003', 'High',     FALSE, 5, FALSE),
-- March 2025
('2025-03-03', '2025-03-03 08:00:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Sepsis lactate repeat measurement timing',         'Cortex Search', 0.7,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2025-03-04', '2025-03-04 09:30:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'MA plan prior auth denial letter requirements',    'Cortex Search', 1.2,  'DOC-004', 'High',     FALSE, 5, FALSE),
('2025-03-05', '2025-03-05 10:10:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'Rapid sequence intubation drug dosing',            'Unresolved',    NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-03-06', '2025-03-06 11:45:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Vancomycin AUC-guided dosing protocol',            'Manual Lookup',  52.0, NULL,      'Low',      TRUE,  2, TRUE),
('2025-03-07', '2025-03-07 07:55:00', 'ONCO_NP',      'Health System', 'Clinical',    'CAR-T cell therapy eligibility screening criteria', 'Unresolved',   NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-03-10', '2025-03-10 09:20:00', 'QUAL_MGR',     'Health System', 'Regulatory',  'Fall prevention NPSG documentation requirements',  'Cortex Search', 1.4,  'DOC-008', 'Medium',   FALSE, 4, FALSE),
('2025-03-11', '2025-03-11 13:00:00', 'REG_AFF',      'Pharma',        'Regulatory',  'FDA Phase II dose modification criteria documentation', 'Cortex Search', 2.4, 'DOC-007', 'High',  FALSE, 5, FALSE),
('2025-03-12', '2025-03-12 10:30:00', 'CASE_MGR',     'Health System', 'Operational', 'Readmission risk screening tool documentation',    'Cortex Search', 1.9,  'DOC-013', 'Medium',   FALSE, 3, FALSE),
('2025-03-13', '2025-03-13 08:40:00', 'ADMIN_STAFF',  'Payer',         'Operational', 'Claims appeals process and member notification',   'Cortex Search', 2.2,  'DOC-012', 'High',     FALSE, 4, FALSE),
('2025-03-14', '2025-03-14 14:10:00', 'CLIN_INF',     'Health System', 'Clinical',    'Stroke tPA administration checklist steps',        'Cortex Search', 0.9,  'DOC-020', 'High',     FALSE, 5, FALSE),
('2025-03-17', '2025-03-17 09:00:00', 'RES_COORD',    'Pharma',        'Research',    'Trial subject withdrawal documentation requirements', 'Cortex Search', 2.0, 'DOC-019', 'High',   FALSE, 5, FALSE),
('2025-03-18', '2025-03-18 11:20:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'State Medicaid BH PA turnaround documentation',   'Cortex Search', 1.5,  'DOC-023', 'High',     FALSE, 4, FALSE),
('2025-03-19', '2025-03-19 10:00:00', 'EXEC_CCO',     'Payer',         'Regulatory',  'Summary of open high-severity compliance findings', 'Manual Lookup', 35.0, NULL,      'Low',      FALSE, 3, FALSE),
('2025-03-20', '2025-03-20 08:25:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Enoxaparin renal dose adjustment protocol',        'Cortex Search', 1.1,  'DOC-016', 'High',     FALSE, 5, FALSE),
-- April 2025
('2025-04-01', '2025-04-01 08:05:00', 'ICU_NURSE',    'Health System', 'Clinical',    'ARDS lung protective ventilation settings',        'Unresolved',    NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-04-02', '2025-04-02 09:40:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'HIPAA penalty tiers for willful neglect',          'Cortex Search', 1.3,  'DOC-003', 'High',     FALSE, 5, FALSE),
('2025-04-03', '2025-04-03 10:15:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'Tension pneumothorax emergent decompression SOP',  'Unresolved',    NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-04-04', '2025-04-04 11:00:00', 'QUAL_MGR',     'Health System', 'Regulatory',  'SSI rate benchmark targets Joint Commission',      'Cortex Search', 1.6,  'DOC-018', 'Medium',   FALSE, 3, FALSE),
('2025-04-07', '2025-04-07 08:30:00', 'REG_AFF',      'Pharma',        'Regulatory',  'Informed consent revision notification requirements','Cortex Search', 2.3, 'DOC-011', 'High',     FALSE, 5, FALSE),
('2025-04-08', '2025-04-08 10:45:00', 'ONCO_NP',      'Health System', 'Clinical',    'G-CSF prophylaxis threshold by chemo regimen',     'Manual Lookup',  38.0, NULL,      'Low',      TRUE,  2, TRUE),
('2025-04-09', '2025-04-09 09:15:00', 'CLIN_INF',     'Health System', 'Clinical',    'CAUTI prevention bundle component verification',   'Cortex Search', 1.4,  'DOC-010', 'Medium',   FALSE, 4, FALSE),
('2025-04-10', '2025-04-10 13:30:00', 'CASE_MGR',     'Health System', 'Operational', 'Palliative care consultation trigger criteria',    'Manual Lookup',  44.0, NULL,      'Low',      TRUE,  2, TRUE),
('2025-04-11', '2025-04-11 08:10:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Insulin drip protocol sliding scale adjustments',  'Cortex Search', 0.9,  'DOC-006', 'Medium',   FALSE, 4, FALSE),
('2025-04-14', '2025-04-14 09:50:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'HEDIS well-child visits measure documentation',    'Cortex Search', 1.7,  'DOC-017', 'High',     FALSE, 5, FALSE),
('2025-04-15', '2025-04-15 11:25:00', 'RES_COORD',    'Pharma',        'Research',    'Protocol deviation reporting to IRB timeline',     'Cortex Search', 2.1,  'DOC-019', 'High',     FALSE, 5, FALSE),
('2025-04-16', '2025-04-16 14:00:00', 'OPS_COORD',    'Health System', 'Operational', 'New staff badge access provisioning SOP',          'Cortex Search', 2.4,  'DOC-009', 'Medium',   FALSE, 3, FALSE),
('2025-04-17', '2025-04-17 08:20:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'Sepsis antibiotic selection and timing',           'Cortex Search', 0.6,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2025-04-22', '2025-04-22 10:05:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Daily awakening and breathing trial bundle',       'Cortex Search', 1.0,  'DOC-002', 'High',     FALSE, 5, FALSE),
-- May 2025
('2025-05-01', '2025-05-01 07:45:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Medication reconciliation high-alert drug classes', 'Cortex Search', 1.5, 'DOC-006', 'High',     FALSE, 5, FALSE),
('2025-05-02', '2025-05-02 09:10:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'CMS MA prior auth exceptions for emergencies',    'Cortex Search', 1.2,  'DOC-004', 'High',     FALSE, 5, FALSE),
('2025-05-05', '2025-05-05 10:40:00', 'CLIN_INF',     'Health System', 'Clinical',    'Sepsis protocol update distribution to nursing',   'Cortex Search', 1.0,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2025-05-06', '2025-05-06 11:30:00', 'ONCO_NP',      'Health System', 'Clinical',    'Neutropenic fever antibiotic protocol',            'Cortex Search', 0.9,  'DOC-014', 'High',     FALSE, 5, FALSE),
('2025-05-07', '2025-05-07 08:00:00', 'REG_AFF',      'Pharma',        'Research',    'Annual report IND requirements and format',        'Cortex Search', 2.5,  'DOC-011', 'High',     FALSE, 5, FALSE),
('2025-05-08', '2025-05-08 13:15:00', 'CASE_MGR',     'Health System', 'Operational', 'Discharge summary completion timeline requirement', 'Cortex Search', 1.8, 'DOC-013', 'High',     FALSE, 4, FALSE),
('2025-05-09', '2025-05-09 09:30:00', 'QUAL_MGR',     'Health System', 'Regulatory',  'Obstetric hemorrhage mortality review process',    'Cortex Search', 2.0,  'DOC-008', 'Medium',   FALSE, 4, FALSE),
('2025-05-12', '2025-05-12 10:00:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Delirium assessment and CAM-ICU scoring',         'Unresolved',    NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-05-13', '2025-05-13 11:45:00', 'ADMIN_STAFF',  'Payer',         'Operational', 'Vendor contract renewal approval process',         'Manual Lookup',  30.0, NULL,      'Low',      TRUE,  2, TRUE),
('2025-05-14', '2025-05-14 08:25:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'STEMI activation criteria and door-to-balloon',   'Unresolved',    NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-05-15', '2025-05-15 14:00:00', 'IT_ANALYST',   'Health System', 'Operational', 'Snowflake data access audit log SOP',              'Cortex Search', 1.9,  'DOC-015', 'Medium',   FALSE, 4, FALSE),
('2025-05-16', '2025-05-16 09:00:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'HIPAA security training frequency requirements',   'Cortex Search', 1.3,  'DOC-003', 'High',     FALSE, 5, FALSE),
('2025-05-19', '2025-05-19 10:30:00', 'RES_COORD',    'Pharma',        'Research',    'Screen failure documentation and eligibility log', 'Cortex Search', 2.3, 'DOC-007', 'High',     FALSE, 5, FALSE),
-- June 2025
('2025-06-02', '2025-06-02 08:10:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Sepsis fluid resuscitation volume guidance',       'Cortex Search', 0.8,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2025-06-03', '2025-06-03 09:45:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'State Medicaid BH documentation audit readiness',  'Cortex Search', 1.6,  'DOC-023', 'High',     FALSE, 5, FALSE),
('2025-06-04', '2025-06-04 10:00:00', 'ED_PHYSICIAN', 'Health System', 'Clinical',    'Septic shock vasopressor escalation sequence',     'Cortex Search', 0.7,  'DOC-001', 'High',     FALSE, 5, FALSE),
('2025-06-05', '2025-06-05 11:30:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Renal dose adjustment reference for antibiotics',  'Unresolved',    NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-06-06', '2025-06-06 13:00:00', 'QUAL_MGR',     'Health System', 'Regulatory',  'Annual hand hygiene compliance reporting format',  'Cortex Search', 1.1,  'DOC-010', 'High',     FALSE, 5, FALSE),
('2025-06-09', '2025-06-09 08:30:00', 'ONCO_NP',      'Health System', 'Clinical',    'Chimeric antigen receptor T-cell toxicity protocol', 'Unresolved', NULL, NULL,      'Not Found', TRUE,  1, TRUE),
('2025-06-10', '2025-06-10 09:15:00', 'REG_AFF',      'Pharma',        'Regulatory',  'Electronic trial master file requirements FDA',    'Cortex Search', 2.0,  'DOC-011', 'High',     FALSE, 5, FALSE),
('2025-06-11', '2025-06-11 10:45:00', 'CLIN_INF',     'Health System', 'Clinical',    'Fall risk screening Morse Fall Scale thresholds',  'Manual Lookup',  26.0, NULL,      'Low',      TRUE,  3, FALSE),
('2025-06-12', '2025-06-12 08:00:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'Behavioral health parity documentation MHPAEA',   'Cortex Search', 1.7,  'DOC-012', 'Medium',   FALSE, 4, FALSE),
('2025-06-13', '2025-06-13 14:20:00', 'EXEC_CMO',     'Health System', 'Clinical',    'Protocol adherence rates by department summary',   'Manual Lookup',  40.0, NULL,      'Low',      FALSE, 3, FALSE),
('2025-06-16', '2025-06-16 09:00:00', 'CASE_MGR',     'Health System', 'Operational', 'LACE+ index documentation for discharge planning', 'Cortex Search', 2.2, 'DOC-013', 'High',     FALSE, 5, FALSE),
('2025-06-17', '2025-06-17 10:30:00', 'RES_COORD',    'Pharma',        'Research',    'Randomization procedure and kit assignment SOP',   'Cortex Search', 1.9,  'DOC-007', 'High',     FALSE, 5, FALSE),
('2025-06-18', '2025-06-18 11:00:00', 'PHARM_CLIN',   'Health System', 'Clinical',    'Antimicrobial stewardship program criteria',       'Cortex Search', 1.4,  'DOC-006', 'Medium',   FALSE, 4, FALSE),
('2025-06-19', '2025-06-19 08:45:00', 'ICU_NURSE',    'Health System', 'Clinical',    'Sedation depth assessment RASS scale thresholds',  'Cortex Search', 0.9, 'DOC-002', 'High',     FALSE, 5, FALSE),
('2025-06-20', '2025-06-20 13:30:00', 'COMP_ANAL',    'Payer',         'Regulatory',  'CMS 2025 MA prior auth transparency requirements', 'Cortex Search', 1.5,  'DOC-004', 'High',     FALSE, 5, FALSE);
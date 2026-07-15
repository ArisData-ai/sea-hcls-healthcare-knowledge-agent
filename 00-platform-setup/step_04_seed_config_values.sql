-- Seed KA_CONFIG with initial runtime configuration values using MERGE (idempotent)
-- Co-authored with CoCo

USE ROLE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_ROLE;
USE WAREHOUSE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_WH;
USE DATABASE SEA_HEALTHCARE_KNOWLEDGE_AGENT_OWNER_DB;
USE SCHEMA CONFIG;

MERGE INTO KA_CONFIG AS target
USING (
    SELECT column1 AS CONFIG_KEY, column2 AS CONFIG_VALUE, column3 AS DESCRIPTION
    FROM VALUES
        ('chunk_size_chars',           '1800',                    'Target characters per document chunk'),
        ('chunk_overlap_chars',        '300',                     'Character overlap between adjacent chunks'),
        ('search_target_lag',          '1 hour',                  'Cortex Search Service refresh lag'),
        ('tier1_confidence_threshold', '0.78',                    'Minimum relevance score for an instant answer'),
        ('tier1_gap_signal_threshold', '0.65',                    'Below this, treat as no relevant match'),
        ('escalation_age_days',        '14',                      'Days an open queue item may sit before auto-escalation'),
        ('gap_queue_sweep_schedule',   'USING CRON 0 6 * * * UTC', 'Schedule for TASK_REFRESH_GAP_QUEUE')
) AS source
ON target.CONFIG_KEY = source.CONFIG_KEY
WHEN MATCHED THEN UPDATE SET
    CONFIG_VALUE = source.CONFIG_VALUE,
    DESCRIPTION  = source.DESCRIPTION,
    UPDATED_AT   = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION, UPDATED_AT)
    VALUES (source.CONFIG_KEY, source.CONFIG_VALUE, source.DESCRIPTION, CURRENT_TIMESTAMP());

-- Verification: confirm all seven keys present with correct values, no duplicates
SELECT * FROM KA_CONFIG ORDER BY CONFIG_KEY;
SELECT CONFIG_KEY, COUNT(*) AS cnt FROM KA_CONFIG GROUP BY CONFIG_KEY HAVING cnt > 1;
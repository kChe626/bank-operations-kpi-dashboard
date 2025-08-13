-- Row count
SELECT COUNT(*) AS row_count FROM bank_cleaned_operational;

-- Spot check a few rows
SELECT * FROM bank_cleaned_operational LIMIT 5;

-- Nulls on key fields
SELECT
  SUM(contact IS NULL) AS null_contact,
  SUM(`date` IS NULL) AS null_date_text,
  SUM(call_seconds IS NULL) AS null_call_seconds
FROM bank_cleaned_operational;

-- Add a parsed date column
ALTER TABLE bank_cleaned_operational
ADD COLUMN date_parsed DATE NULL;

-- Parse 'M/D/YYYY' or 'MM/DD/YYYY'
UPDATE bank_cleaned_operational
SET date_parsed = STR_TO_DATE(`date`, '%c/%e/%Y');

-- Check
SELECT
  COUNT(*) AS total_rows,
  SUM(date_parsed IS NULL) AS failed_parse
FROM bank_cleaned_operational;

-- dates and clean flags
CREATE VIEW v_ops_base AS
SELECT
    b.*,
    parsed_date AS date_final,
    DATE_FORMAT(parsed_date, '%Y-%m') AS ym,
    YEARWEEK(parsed_date, 3) AS yw,
    CASE 
        WHEN b.deposit = 'yes' OR b.converted = 1 THEN 1 
        ELSE 0 
    END AS converted_i,
    b.is_repeat_contact AS is_repeat_contact_i,
    b.is_followup AS is_followup_i,
    b.had_prior_contact AS had_prior_contact_i,
    b.call_seconds AS call_seconds_n
FROM (
    SELECT 
        b.*,
        COALESCE(
            STR_TO_DATE(b.`date`, '%c/%e/%Y'),
            STR_TO_DATE(CONCAT(b.day, '-', b.month, '-', b.contact_year), '%e-%b-%Y')
        ) AS parsed_date
    FROM bank_cleaned_operational b
) b;

-- checks
SELECT COUNT(*) total_rows FROM v_ops_base;
SELECT SUM(date_final IS NULL) AS null_dates FROM v_ops_base;
SELECT ym, COUNT(*) FROM v_ops_base WHERE date_final IS NOT NULL GROUP BY ym ORDER BY ym;

-- Monthly KPI overview 
CREATE VIEW v_kpi_overview_monthly AS
SELECT
    ym,
    COUNT(*) AS total_contacts,
    SUM(converted_i) AS conversions,
    ROUND(
        100 * SUM(converted_i) / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate_pct,
    ROUND(AVG(call_seconds_n), 1) AS avg_call_seconds,
    ROUND(100 * AVG(is_repeat_contact_i), 2) AS repeat_contact_rate_pct,
    ROUND(100 * AVG(is_followup_i), 2) AS followup_rate_pct,
    ROUND(100 * AVG(had_prior_contact_i), 2) AS prior_contact_share_pct
FROM
    v_ops_base
WHERE
    date_final IS NOT NULL
GROUP BY
    ym
ORDER BY
    ym;

-- checks 
SELECT * FROM v_kpi_overview_monthly ORDER BY ym;

-- Weekly KPI overview
CREATE VIEW v_kpi_overview_weekly AS
SELECT
    yw,
    COUNT(*) AS total_contacts,
    SUM(converted_i) AS conversions,
    ROUND(
        100 * SUM(converted_i) / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate_pct,
    ROUND(AVG(call_seconds_n), 1) AS avg_call_seconds,
    ROUND(100 * AVG(is_repeat_contact_i), 2) AS repeat_contact_rate_pct,
    ROUND(100 * AVG(is_followup_i), 2) AS followup_rate_pct,
    ROUND(100 * AVG(had_prior_contact_i), 2) AS prior_contact_share_pct
FROM
    v_ops_base
WHERE
    date_final IS NOT NULL
GROUP BY
    yw
ORDER BY
    yw;
    
-- checks
SELECT * FROM v_kpi_overview_weekly ORDER BY yw;

-- Age band by month
CREATE VIEW v_seg_ageband_monthly AS
SELECT
    ym,
    age_band,
    COUNT(*) AS total_contacts,
    SUM(converted_i) AS conversions,
    ROUND(
        100 * SUM(converted_i) / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate_pct,
    ROUND(AVG(call_seconds_n), 1) AS avg_call_seconds
FROM
    v_ops_base
WHERE
    date_final IS NOT NULL
GROUP BY
    ym,
    age_band
ORDER BY
    ym,
    age_band;

-- check
SELECT * FROM  v_seg_ageband_monthly;

-- Job by month
CREATE VIEW v_seg_job_monthly AS
SELECT
    ym,
    job,
    COUNT(*) AS total_contacts,
    SUM(converted_i) AS conversions,
    ROUND(
        100 * SUM(converted_i) / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate_pct,
    ROUND(AVG(call_seconds_n), 1) AS avg_call_seconds
FROM
    v_ops_base
WHERE
    date_final IS NOT NULL
GROUP BY
    ym,
    job
ORDER BY
    ym,
    job;

-- check
SELECT * FROM  v_seg_job_monthly;

-- Channel/Contact‑type KPIs
CREATE VIEW v_kpi_contact_channel_monthly AS
SELECT
    ym,
    COALESCE(contact, 'unknown') AS contact_channel,
    COUNT(*) AS total_contacts,
    SUM(converted_i) AS conversions,
    ROUND(
        100 * SUM(converted_i) / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate_pct,
    ROUND(AVG(call_seconds_n), 1) AS avg_call_seconds
FROM
    v_ops_base
WHERE
    date_final IS NOT NULL
GROUP BY
    ym,
    COALESCE(contact, 'unknown')
ORDER BY
    ym,
    contact_channel;

-- check 
SELECT * FROM v_kpi_contact_channel_monthly;

-- Any NULL ym left?
SELECT SUM(ym IS NULL) AS ym_nulls FROM v_ops_base;

-- Do month text and computed ym line up?
SELECT 
    month, 
    ym, 
    COUNT(*) AS `rows`
FROM v_ops_base
GROUP BY month, ym
ORDER BY ym, month;

-- check range
SELECT
  MIN(call_seconds_n) AS min_secs,
  MAX(call_seconds_n) AS max_secs,
  ROUND(AVG(call_seconds_n),1) AS avg_secs
FROM v_ops_base;

-- Exporting CSV
SELECT * FROM v_kpi_overview_monthly;
SELECT * FROM v_kpi_overview_weekly;
SELECT * FROM v_seg_ageband_monthly;
SELECT * FROM v_kpi_contact_channel_monthly;
SELECT * FROM v_kpi_overview_monthly;


/* ============================================================
   SECTION 1 — TABLE CREATION
   ============================================================ */

CREATE TABLE accounts (
    account_id       VARCHAR(20) PRIMARY KEY,
    account_name     VARCHAR(100),
    industry         VARCHAR(50),
    country          VARCHAR(10),
    signup_date      DATE,
    referral_source  VARCHAR(50),
    plan_tier        VARCHAR(20),
    seats            INTEGER,
    is_trial         BOOLEAN,
    churn_flag       BOOLEAN
);

CREATE TABLE subscriptions (
    subscription_id    VARCHAR(20) PRIMARY KEY,
    account_id          VARCHAR(20) REFERENCES accounts(account_id),
    start_date          DATE,
    end_date            DATE,            -- NULL = subscription still active
    plan_tier           VARCHAR(20),
    seats               INTEGER,
    mrr_amount          NUMERIC,
    arr_amount          NUMERIC,
    is_trial            BOOLEAN,
    upgrade_flag        BOOLEAN,
    downgrade_flag      BOOLEAN,
    churn_flag          BOOLEAN,
    billing_frequency   VARCHAR(20),
    auto_renew_flag     BOOLEAN
);

CREATE TABLE churn_events (
    churn_event_id            VARCHAR(20) PRIMARY KEY,
    account_id                 VARCHAR(20) REFERENCES accounts(account_id),
    churn_date                 DATE,
    reason_code                VARCHAR(50),
    refund_amount_usd          NUMERIC,
    preceding_upgrade_flag     BOOLEAN,
    preceding_downgrade_flag   BOOLEAN,
    is_reactivation            BOOLEAN,
    feedback_text              TEXT      -- NULL = no feedback left
);

CREATE TABLE feature_usage (
    usage_id              VARCHAR(20) PRIMARY KEY,
    subscription_id        VARCHAR(20) REFERENCES subscriptions(subscription_id),
    usage_date              DATE,
    feature_name             VARCHAR(100),
    usage_count               INTEGER,
    usage_duration_secs        INTEGER,
    error_count                  INTEGER,
    is_beta_feature                BOOLEAN
);

CREATE TABLE support_tickets (
    ticket_id                      VARCHAR(20) PRIMARY KEY,
    account_id                      VARCHAR(20) REFERENCES accounts(account_id),
    submitted_at                     TIMESTAMP,
    closed_at                         TIMESTAMP,
    resolution_time_hours              NUMERIC,
    priority                            VARCHAR(20),
    first_response_time_minutes          INTEGER,
    satisfaction_score                    NUMERIC,  -- NULL = customer did not respond
    escalation_flag                        BOOLEAN
);


/* ============================================================
   SECTION 2 — DATA QUALITY CHECK
   ============================================================ */

SELECT
    churn_flag,
    COUNT(*)                                     AS total,
    COUNT(*) FILTER (WHERE end_date IS NULL)     AS null_end_date,
    COUNT(*) FILTER (WHERE end_date IS NOT NULL) AS has_end_date
FROM subscriptions
GROUP BY churn_flag;


/* ============================================================
   SECTION 3 — CLEANED VIEWS
   ============================================================ */

-- View 1: Subscriptions with nulls handled + derived duration
CREATE OR REPLACE VIEW v_subscriptions_clean AS
SELECT
    subscription_id,
    account_id,
    start_date,
    COALESCE(end_date, CURRENT_DATE)                AS end_date,
    plan_tier,
    seats,
    mrr_amount,
    arr_amount,
    is_trial,
    upgrade_flag,
    downgrade_flag,
    churn_flag,
    billing_frequency,
    auto_renew_flag,
    (COALESCE(end_date, CURRENT_DATE) - start_date)  AS duration_days,
    CASE WHEN end_date IS NULL
        THEN 'Active'
        ELSE 'Cancelled'
    END                                               AS subscription_status
FROM subscriptions;

-- View 2: Support tickets with nulls handled
CREATE OR REPLACE VIEW v_support_clean AS
SELECT
    ticket_id,
    account_id,
    submitted_at,
    closed_at,
    resolution_time_hours,
    priority,
    first_response_time_minutes,
    COALESCE(satisfaction_score, 0)   AS satisfaction_score,
    CASE WHEN satisfaction_score IS NULL
        THEN 'No Response'
        ELSE 'Responded'
    END                                AS survey_status,
    escalation_flag
FROM support_tickets;

-- View 3: Master view joining accounts + cleaned subscriptions
CREATE OR REPLACE VIEW v_master AS
SELECT
    a.account_id,
    a.account_name,
    a.industry,
    a.country,
    a.signup_date,
    a.referral_source,
    a.plan_tier                          AS account_plan_tier,
    a.seats                              AS account_seats,
    a.is_trial                           AS account_is_trial,
    a.churn_flag                         AS account_churn_flag,
    s.subscription_id,
    s.mrr_amount,
    s.arr_amount,
    s.duration_days,
    s.subscription_status,
    s.billing_frequency,
    s.upgrade_flag,
    s.downgrade_flag,
    (CURRENT_DATE - a.signup_date)       AS account_age_days
FROM accounts a
LEFT JOIN v_subscriptions_clean s ON a.account_id = s.account_id;


/* ============================================================
   QUERY 1 — OVERALL CHURN RATE & REVENUE AT RISK
   ============================================================

-- 1A: Account-level churn rate
SELECT
    COUNT(*)                                        AS total_accounts,
    COUNT(*) FILTER (WHERE churn_flag = TRUE)       AS churned_accounts,
    COUNT(*) FILTER (WHERE churn_flag = FALSE)      AS active_accounts,
    ROUND(
        COUNT(*) FILTER (WHERE churn_flag = TRUE) * 100.0
        / COUNT(*), 2
    )                                                AS churn_rate_pct
FROM accounts;

-- 1B: MRR / ARR at risk
SELECT
    ROUND(SUM(mrr_amount), 2)                                       AS total_mrr,
    ROUND(SUM(mrr_amount) FILTER (WHERE churn_flag = TRUE), 2)      AS churned_mrr,
    ROUND(SUM(mrr_amount) FILTER (WHERE churn_flag = FALSE), 2)     AS active_mrr,
    ROUND(
        SUM(mrr_amount) FILTER (WHERE churn_flag = TRUE) * 100.0
        / SUM(mrr_amount), 2
    )                                                                AS mrr_churn_rate_pct
FROM v_subscriptions_clean;

-- 1C: Actual ARR lost (precise figure vs. MRR x 12 approximation)
SELECT
    ROUND(SUM(arr_amount) FILTER (WHERE churn_flag = TRUE), 2)  AS actual_arr_lost,
    ROUND(SUM(arr_amount) FILTER (WHERE churn_flag = FALSE), 2) AS active_arr,
    ROUND(SUM(arr_amount), 2)                                   AS total_arr
FROM v_subscriptions_clean;


/* ============================================================
   QUERY 2 — CHURN BY PLAN TIER & INDUSTRY
   ============================================================

-- 2A: Churn rate by plan tier
SELECT
    a.plan_tier,
    COUNT(*)                                                AS total_accounts,
    COUNT(*) FILTER (WHERE a.churn_flag = TRUE)             AS churned_accounts,
    COUNT(*) FILTER (WHERE a.churn_flag = FALSE)            AS active_accounts,
    ROUND(
        COUNT(*) FILTER (WHERE a.churn_flag = TRUE) * 100.0
        / COUNT(*), 2
    )                                                        AS churn_rate_pct,
    ROUND(
        SUM(s.mrr_amount) FILTER (WHERE a.churn_flag = TRUE), 2
    )                                                        AS churned_mrr
FROM accounts a
JOIN v_subscriptions_clean s ON a.account_id = s.account_id
GROUP BY a.plan_tier
ORDER BY churn_rate_pct DESC;

-- 2B: Churn rate by industry
SELECT
    a.industry,
    COUNT(*)                                                AS total_accounts,
    COUNT(*) FILTER (WHERE a.churn_flag = TRUE)             AS churned_accounts,
    COUNT(*) FILTER (WHERE a.churn_flag = FALSE)            AS active_accounts,
    ROUND(
        COUNT(*) FILTER (WHERE a.churn_flag = TRUE) * 100.0
        / COUNT(*), 2
    )                                                        AS churn_rate_pct,
    ROUND(
        SUM(s.mrr_amount) FILTER (WHERE a.churn_flag = TRUE), 2
    )                                                        AS churned_mrr
FROM accounts a
JOIN v_subscriptions_clean s ON a.account_id = s.account_id
GROUP BY a.industry
ORDER BY churn_rate_pct DESC;

/* ============================================================
   QUERY 3 — REVENUE AT RISK BY INDUSTRY
   ============================================================

WITH revenue_summary AS (
    SELECT
        a.industry,
        COUNT(DISTINCT a.account_id)                            AS total_accounts,
        COUNT(DISTINCT a.account_id)
            FILTER (WHERE a.churn_flag = TRUE)                  AS churned_accounts,
        ROUND(SUM(s.mrr_amount), 2)                             AS total_mrr,
        ROUND(SUM(s.mrr_amount)
            FILTER (WHERE a.churn_flag = TRUE), 2)              AS churned_mrr,
        ROUND(SUM(s.mrr_amount)
            FILTER (WHERE a.churn_flag = FALSE), 2)             AS active_mrr,
        ROUND(AVG(s.mrr_amount), 2)                             AS avg_mrr_per_account,
        ROUND(SUM(ce.refund_amount_usd), 2)                     AS total_refunds
    FROM accounts a
    JOIN v_subscriptions_clean s    ON a.account_id = s.account_id
    LEFT JOIN churn_events ce       ON a.account_id = ce.account_id
    GROUP BY a.industry
),
final AS (
    SELECT
        *,
        ROUND(churned_mrr * 100.0 / NULLIF(total_mrr, 0), 2)   AS mrr_churn_rate_pct,
        ROUND(churned_mrr * 12, 2)                              AS arr_at_risk
    FROM revenue_summary
)
SELECT
    industry,
    total_accounts,
    churned_accounts,
    total_mrr,
    churned_mrr,
    active_mrr,
    avg_mrr_per_account,
    total_refunds,
    mrr_churn_rate_pct,
    arr_at_risk
FROM final
ORDER BY arr_at_risk DESC;


/* ============================================================
   QUERY 4 — MONTHLY COHORT RETENTION ANALYSIS
   ============================================================
WITH cohort_base AS (
    SELECT
        a.account_id,
        a.industry,
        a.plan_tier,
        DATE_TRUNC('month', a.signup_date)              AS signup_month,
        a.churn_flag,
        s.mrr_amount,
        s.arr_amount
    FROM accounts a
    JOIN v_subscriptions_clean s ON a.account_id = s.account_id
),
cohort_summary AS (
    SELECT
        TO_CHAR(signup_month, 'YYYY-MM')                AS cohort_month,
        COUNT(DISTINCT account_id)                      AS total_accounts,
        COUNT(DISTINCT account_id)
            FILTER (WHERE churn_flag = TRUE)            AS churned_accounts,
        COUNT(DISTINCT account_id)
            FILTER (WHERE churn_flag = FALSE)           AS active_accounts,
        ROUND(SUM(mrr_amount), 2)                       AS total_mrr,
        ROUND(SUM(mrr_amount)
            FILTER (WHERE churn_flag = TRUE), 2)        AS churned_mrr,
        ROUND(AVG(mrr_amount), 2)                       AS avg_mrr
    FROM cohort_base
    GROUP BY signup_month
),
cohort_rates AS (
    SELECT
        *,
        ROUND(churned_accounts * 100.0 / NULLIF(total_accounts, 0), 2) AS churn_rate_pct,
        ROUND(active_accounts * 100.0 / NULLIF(total_accounts, 0), 2)  AS retention_rate_pct,
        ROUND(churned_mrr * 100.0 / NULLIF(total_mrr, 0), 2)           AS mrr_churn_rate_pct
    FROM cohort_summary
)
SELECT
    cohort_month,
    total_accounts,
    churned_accounts,
    active_accounts,
    churn_rate_pct,
    retention_rate_pct,
    total_mrr,
    churned_mrr,
    avg_mrr,
    mrr_churn_rate_pct
FROM cohort_rates
ORDER BY cohort_month;


/* ============================================================
   QUERY 5 — HIGH-RISK ACTIVE ACCOUNT SCORING
   ============================================================

WITH account_metrics AS (
    SELECT
        a.account_id,
        a.account_name,
        a.industry,
        a.plan_tier,
        a.signup_date,
        (CURRENT_DATE - a.signup_date)               AS account_age_days,
        ROUND(SUM(s.mrr_amount), 2)                  AS total_mrr,
        COUNT(DISTINCT st.ticket_id)                 AS ticket_count,
        ROUND(AVG(COALESCE(st.satisfaction_score, 0)), 2) AS avg_satisfaction,
        COUNT(DISTINCT st.ticket_id)
            FILTER (WHERE st.escalation_flag = TRUE) AS escalated_tickets,
        MAX(CASE WHEN s.downgrade_flag = TRUE
            THEN 1 ELSE 0 END)                       AS has_downgraded,
        COUNT(DISTINCT fu.feature_name)              AS features_used
    FROM accounts a
    JOIN v_subscriptions_clean s     ON a.account_id = s.account_id
    LEFT JOIN v_support_clean st     ON a.account_id = st.account_id
    LEFT JOIN feature_usage fu       ON s.subscription_id = fu.subscription_id
    WHERE a.churn_flag = FALSE        -- only score active accounts
    GROUP BY
        a.account_id, a.account_name, a.industry,
        a.plan_tier, a.signup_date
),
risk_scored AS (
    SELECT
        *,
        -- Weighted risk score: ticket volume, low satisfaction,
        -- escalations, downgrade history, and low feature adoption
        -- all push the score up
        ROUND((
            (ticket_count * 0.25) +
            ((5 - avg_satisfaction) * 2.0) +
            (escalated_tickets * 1.5) +
            (has_downgraded * 3.0) +
            (CASE WHEN features_used < 3 THEN 2.0 ELSE 0 END)
        ), 2)                                        AS risk_score,
        RANK() OVER (
            PARTITION BY industry
            ORDER BY (
                (ticket_count * 0.25) +
                ((5 - avg_satisfaction) * 2.0) +
                (escalated_tickets * 1.5) +
                (has_downgraded * 3.0) +
                (CASE WHEN features_used < 3 THEN 2.0 ELSE 0 END)
            ) DESC
        )                                             AS rank_in_industry,
        RANK() OVER (
            ORDER BY (
                (ticket_count * 0.25) +
                ((5 - avg_satisfaction) * 2.0) +
                (escalated_tickets * 1.5) +
                (has_downgraded * 3.0) +
                (CASE WHEN features_used < 3 THEN 2.0 ELSE 0 END)
            ) DESC
        )                                             AS overall_rank
    FROM account_metrics
),
risk_category AS (
    SELECT
        *,
        CASE
            WHEN risk_score >= 12 THEN 'Critical Risk'
            WHEN risk_score >= 10 THEN 'High Risk'
            WHEN risk_score >= 7  THEN 'Medium Risk'
            ELSE                       'Low Risk'
        END                                           AS risk_category
    FROM risk_scored
)
SELECT
    overall_rank,
    account_id,
    account_name,
    industry,
    plan_tier,
    total_mrr,
    ticket_count,
    avg_satisfaction,
    escalated_tickets,
    features_used,
    has_downgraded,
    risk_score,
    risk_category,
    rank_in_industry
FROM risk_category
ORDER BY overall_rank
LIMIT 20;

# SaaS Customer Churn Analysis
### End-to-End Analytics Project | Python · PostgreSQL · SQL

**Author:** Divya Korey  
**Tools:** Python (Pandas, NumPy, Matplotlib, Seaborn) · PostgreSQL · pgAdmin  
**Dataset:** RavenStack synthetic SaaS dataset — 5 tables, 32,600+ rows  

---

## Business Problem

RavenStack, a B2B SaaS company, is losing customers at an alarming rate. Leadership needs to understand:

- **Who** is churning and from which segments?
- **Why** are customers leaving?
- **How much revenue** is at risk?
- **Which active accounts** are most likely to churn next?

This project answers all four questions using a full analytics pipeline — from raw data to actionable business recommendations.

---

## Project Structure

```
├── 01_EDA_and_Cleaning.ipynb     # Data cleaning + exploratory analysis (Python)
├── 02_SQL_Analysis.sql           # 5 business queries (PostgreSQL)
├── images/                       # All charts generated from the analysis
│   ├── churn_overall.png
│   ├── churn_by_plan.png
│   ├── churn_by_industry.png
│   ├── churn_reasons.png
│   ├── mrr_at_risk.png
│   └── tickets_vs_churn.png
└── README.md
```

---

## Dataset Overview

| Table | Rows | Description |
|---|---|---|
| accounts | 500 | Customer accounts with churn flag |
| subscriptions | 5,000 | MRR, ARR, plan tier, upgrade/downgrade history |
| churn_events | 600 | Churn date, reason code, refund amount |
| feature_usage | 25,000 | Feature-level product usage per subscription |
| support_tickets | 2,000 | Ticket count, satisfaction scores, escalations |

All tables connect via `account_id`. Data cleaned and analyzed using both **Python (Pandas)** and **PostgreSQL** — demonstrating end-to-end proficiency across both tools.

---

## Key Findings

### 1. Overall Churn Rate — 3x Above Industry Benchmark

![Overall Churn](images/churn_overall.png)

| Metric | Value |
|---|---|
| Total Accounts | 500 |
| Churned Accounts | 110 |
| Account Churn Rate | **22.0%** |
| Industry Benchmark | 5–7% |
| Total MRR | $11.4M |
| MRR Lost to Churn | **$1.18M/month** |
| ARR Lost to Churn | **$14.1M annually** |

> RavenStack's 22% churn rate is 3x above the SaaS industry average of 5–7%. At $1.18M in MRR lost every month, the business is leaving $14.1M in annual revenue on the table.

---

### 2. Churn is Equal Across All Plan Tiers — Pricing is Not the Problem

![Churn by Plan](images/churn_by_plan.png)

Churn is nearly identical across Basic (22.0%), Pro (21.9%), and Enterprise (22.1%) plans. This rules out price sensitivity as the root cause and points to a **product-level issue** — confirmed by "features" being the #1 churn reason.

---

### 3. DevTools Segment is the Highest Risk

![Churn by Industry](images/churn_by_industry.png)

| Industry | Churn Rate | Churned MRR |
|---|---|---|
| DevTools | **29.62%** | **$619,317** |
| FinTech | 23.45% | $545,717 |
| HealthTech | 22.13% | $456,128 |
| Cybersecurity | 17.86% | $451,232 |
| EdTech | **17.96%** | $282,851 |

> DevTools is the highest risk segment — highest churn rate, highest churned MRR, and the largest customer base. EdTech is the most stable segment with the strongest retention.

---

### 4. Product Feature Gaps Drive Churn — Not Price

![Churn Reasons](images/churn_reasons.png)

| Reason | Events |
|---|---|
| Features | 114 |
| Support | 104 |
| Budget | 104 |
| Unknown | 95 |
| Competitor | 92 |
| Pricing | 91 |

> "Features" is the #1 churn reason with 114 events — nearly tied with support and budget. Combined with equal churn across all plan tiers, this strongly suggests the product is missing capabilities that competitors offer.

---

### 5. $41.5M in Annual Revenue at Risk Across All Segments

![MRR at Risk](images/mrr_at_risk.png)

| Industry | ARR at Risk |
|---|---|
| DevTools | $12,836,544 |
| FinTech | $9,737,808 |
| Cybersecurity | $8,499,972 |
| HealthTech | $6,256,860 |
| EdTech | $4,152,216 |
| **Total** | **$41,483,400** |

---

### 6. Support Ticket Volume Alone Does Not Predict Churn

![Tickets vs Churn](images/tickets_vs_churn.png)

Churned and active accounts have virtually identical average support ticket counts (3.9 vs 4.0). This tells us that **ticket volume is not a reliable churn signal** — but ticket escalation and satisfaction scores are (used in the risk scoring model in Query 5).

---

## SQL Analysis — 5 Business Queries

All queries run in PostgreSQL against the `ravenstack_churn` database. Full script in `02_SQL_Analysis.sql`.

| Query | Concept | Business Question |
|---|---|---|
| Q1 | Aggregation, FILTER | What is the overall churn rate and MRR at risk? |
| Q2 | GROUP BY, JOIN | Which plan tiers and industries churn most? |
| Q3 | CTEs, LEFT JOIN, NULLIF | How much ARR is at risk by industry? |
| Q4 | DATE_TRUNC, CTEs | Which signup cohorts retain best? |
| Q5 | Window Functions, RANK() | Which active accounts are highest risk right now? |

### Query 5 highlight — High Risk Account Scoring

Built a multi-signal weighted risk scoring model using CTEs and window functions. Signals used:

```
ticket_count × 0.25         → support burden
(5 - avg_satisfaction) × 2  → unhappiness signal
escalated_tickets × 1.5     → serious complaint signal
has_downgraded × 3.0        → strongest churn predictor
features_used < 3 → 2.0     → low product adoption
```

**Result:** Identified 20 Critical Risk active accounts representing **$6.9M combined monthly MRR** (~$82.9M annualized). 17 of 20 had a prior plan downgrade — the single strongest early-warning signal found in the data.

---

## Cohort Analysis Highlights

Monthly cohort retention analysis (Query 4) revealed significant variance:

| Cohort | Churn Rate | MRR Lost |
|---|---|---|
| Feb 2023 (worst) | 38.89% | $149,749 |
| Aug 2023 (best) | 18.75% | $66,718 |

> The Feb 2023 cohort churned at more than double the rate of the Aug 2023 cohort. Investigating what drove better onboarding and retention in Aug 2023 could meaningfully improve future acquisition strategy.

---

## Business Recommendations

| Priority | Action | Impact |
|---|---|---|
| 1 | Invest in product — features is #1 churn reason | Addresses root cause |
| 2 | Launch DevTools retention program immediately | $12.8M ARR at risk |
| 3 | Monitor plan downgrades as early churn warning | 85% of critical risk accounts downgraded |
| 4 | Investigate Feb 2023 cohort failure | Identify onboarding gaps |
| 5 | Expand EdTech acquisition — most stable segment | Highest retention + highest avg MRR |

---

## Future Enhancements

- **Machine Learning Churn Prediction Model** — Random Forest classifier (AUC: 0.927) trained on engineered features from all 5 tables to predict which active accounts will churn next *(in progress)*
- **Power BI Dashboard** — Interactive churn KPI dashboard with segment filtering and risk tier breakdown
- **Cohort retention heatmap** — Visual matrix of retention rates across all signup cohorts

---

## Technical Skills Demonstrated

| Skill | Where used |
|---|---|
| Python (Pandas, NumPy) | Data cleaning, EDA, feature engineering |
| Matplotlib / Seaborn | 6 business charts |
| PostgreSQL | 5 tables, 3 views, 5 analysis queries |
| CTEs | Queries 3, 4, 5 |
| Window Functions (RANK) | Query 5 — risk scoring |
| Complex JOINs | Queries 3, 5 — 3-table joins |
| COALESCE / NULLIF | Null handling and divide-by-zero protection |
| Business Storytelling | README, cohort analysis, risk recommendations |

---

*Dataset: RavenStack synthetic SaaS dataset*

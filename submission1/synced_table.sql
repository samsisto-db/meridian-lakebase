-- Query against synced Unity Catalog table (gold_customer_position → lb_customer_position)
-- Demonstrates governed UC data served at low latency from Lakebase Postgres

SELECT 
    customer_id,
    tier,
    risk_band,
    total_balance_usd,
    balance_at_risk_usd,
    revenue_at_risk_usd,
    attrition_risk_score
FROM meridian_bank.lb_customer_position
WHERE risk_band = 'critical'
ORDER BY balance_at_risk_usd DESC
LIMIT 5;

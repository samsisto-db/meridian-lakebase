-- Domain question: Which critical-risk customers have the highest revenue at stake,
-- and what is the model's recommended next best action?
-- Joins synced customer position data with NBA recommendations in Lakebase.

SELECT 
    cp.customer_id,
    cp.tier,
    cp.risk_band,
    cp.total_balance_usd,
    cp.balance_at_risk_usd,
    cp.revenue_at_risk_usd,
    cp.attrition_risk_score,
    nba.recommended_action,
    nba.recommended_offer_product_id,
    nba.recommended_rate_apy,
    nba.predicted_retained_usd,
    nba.predicted_net_value_usd
FROM meridian_bank.lb_customer_position cp
JOIN meridian_bank.lb_nba_recommendations nba 
    ON cp.customer_id = nba.customer_id
WHERE cp.risk_band = 'critical'
ORDER BY cp.revenue_at_risk_usd DESC
LIMIT 10;

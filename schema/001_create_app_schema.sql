-- Meridian Lakebase: app schema creation
-- Applied to Lakebase Postgres (main branch)

CREATE SCHEMA IF NOT EXISTS app;

-- ============================================================================
-- Synced read-only mirrors (Delta → Lakebase)
-- ============================================================================

CREATE TABLE IF NOT EXISTS app.customer_position (
    customer_id TEXT PRIMARY KEY,
    tier TEXT NOT NULL CHECK (tier IN ('mass', 'mass_affluent', 'affluent', 'private')),
    tenure_years INTEGER,
    home_metro TEXT,
    customer_lat DOUBLE PRECISION,
    customer_lng DOUBLE PRECISION,
    profile_summary TEXT,
    attrition_risk_score DOUBLE PRECISION,
    balance_outflow_30d_usd DOUBLE PRECISION,
    churn_signal_score DOUBLE PRECISION,
    total_balance_usd DOUBLE PRECISION,
    deposit_balance_usd DOUBLE PRECISION,
    affected_deposit_balance_usd DOUBLE PRECISION,
    min_days_to_maturity INTEGER,
    product_count INTEGER,
    balance_at_risk_usd DOUBLE PRECISION,
    revenue_at_risk_usd DOUBLE PRECISION,
    risk_band TEXT NOT NULL CHECK (risk_band IN ('critical', 'elevated', 'watch', 'healthy'))
);

CREATE TABLE IF NOT EXISTS app.open_atrisk (
    customer_id TEXT PRIMARY KEY,
    attrition_risk_score DOUBLE PRECISION,
    balance_at_risk_usd DOUBLE PRECISION,
    revenue_at_risk_usd DOUBLE PRECISION,
    atrisk_product_id TEXT,
    atrisk_balance_usd DOUBLE PRECISION,
    days_to_maturity INTEGER,
    current_rate_apy DOUBLE PRECISION,
    candidate_cross_sell_product_id TEXT
);

CREATE TABLE IF NOT EXISTS app.nba_recommendations (
    customer_id TEXT PRIMARY KEY,
    recommended_action TEXT NOT NULL CHECK (recommended_action IN ('retention_offer', 'cross_sell', 'rm_outreach')),
    recommended_offer_product_id TEXT,
    recommended_rate_apy DOUBLE PRECISION,
    predicted_retained_usd DOUBLE PRECISION,
    predicted_net_value_usd DOUBLE PRECISION,
    action_ranking JSONB NOT NULL DEFAULT '[]',
    scored_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS app.products (
    product_id TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    product_type TEXT,
    segment TEXT,
    rate_apy DOUBLE PRECISION,
    min_balance_usd DOUBLE PRECISION,
    description TEXT,  -- Lakebase Search target (hybrid text/vector)
    is_active BOOLEAN
);

-- ============================================================================
-- Writable operational table (app writes here, reverse-synced to UC)
-- ============================================================================

CREATE TABLE IF NOT EXISTS app.rm_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id TEXT NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('retention_offer', 'cross_sell', 'rm_outreach')),
    offered_product_id TEXT,
    rate_apy DOUBLE PRECISION,
    drafted_note TEXT,
    predicted_retained_usd DOUBLE PRECISION,
    status TEXT NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed', 'approved', 'executed', 'overridden')),
    approved_by TEXT,
    audit_trail JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMPTZ
);

-- Indexes for operational queries
CREATE INDEX IF NOT EXISTS idx_customer_position_risk ON app.customer_position (risk_band, balance_at_risk_usd DESC);
CREATE INDEX IF NOT EXISTS idx_rm_actions_customer ON app.rm_actions (customer_id, created_at DESC);

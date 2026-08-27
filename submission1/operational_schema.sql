-- Meridian Lakebase: Full Operational Schema
-- Domain: Customer Retention & Next-Best-Action
-- All tables under schema: meridian_bank (synced) + app (writable)
-- Shows table relationships via FOREIGN KEY constraints

-- ============================================================================
-- Schema creation
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS meridian_bank;
CREATE SCHEMA IF NOT EXISTS app;

-- ============================================================================
-- Synced read-only tables (Delta → Lakebase via Synced Tables)
-- ============================================================================

CREATE TABLE IF NOT EXISTS meridian_bank.lb_customer_position (
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

CREATE TABLE IF NOT EXISTS meridian_bank.lb_open_atrisk (
    customer_id TEXT PRIMARY KEY
        REFERENCES meridian_bank.lb_customer_position(customer_id),
    attrition_risk_score DOUBLE PRECISION,
    balance_at_risk_usd DOUBLE PRECISION,
    revenue_at_risk_usd DOUBLE PRECISION,
    atrisk_product_id TEXT,
    atrisk_balance_usd DOUBLE PRECISION,
    days_to_maturity INTEGER,
    current_rate_apy DOUBLE PRECISION,
    candidate_cross_sell_product_id TEXT
);

CREATE TABLE IF NOT EXISTS meridian_bank.lb_nba_recommendations (
    customer_id TEXT PRIMARY KEY
        REFERENCES meridian_bank.lb_customer_position(customer_id),
    recommended_action TEXT NOT NULL CHECK (recommended_action IN ('retention_offer', 'cross_sell', 'rm_outreach')),
    recommended_offer_product_id TEXT,
    recommended_rate_apy DOUBLE PRECISION,
    predicted_retained_usd DOUBLE PRECISION,
    predicted_net_value_usd DOUBLE PRECISION,
    action_ranking JSONB NOT NULL DEFAULT '[]',
    scored_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS meridian_bank.products (
    product_id TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    product_type TEXT,
    segment TEXT,
    rate_apy DOUBLE PRECISION,
    min_balance_usd DOUBLE PRECISION,
    description TEXT,  -- Lakebase Search target (tsvector + GIN index)
    is_active BOOLEAN DEFAULT TRUE,
    -- Generated column for full-text search
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(product_name, '') || ' ' || coalesce(description, ''))
    ) STORED
);

-- GIN index for full-text search
CREATE INDEX IF NOT EXISTS idx_products_search
    ON meridian_bank.products USING GIN (search_vector);

-- ============================================================================
-- Writable operational table (app writes, reverse-synced to UC via CDF)
-- ============================================================================

CREATE TABLE IF NOT EXISTS app.rm_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id TEXT NOT NULL
        REFERENCES meridian_bank.lb_customer_position(customer_id),
    action_type TEXT NOT NULL CHECK (action_type IN ('retention_offer', 'cross_sell', 'rm_outreach')),
    offered_product_id TEXT
        REFERENCES meridian_bank.products(product_id),
    rate_apy DOUBLE PRECISION,
    drafted_note TEXT,
    predicted_retained_usd DOUBLE PRECISION,
    status TEXT NOT NULL DEFAULT 'proposed'
        CHECK (status IN ('proposed', 'approved', 'executed', 'overridden')),
    approved_by TEXT,
    audit_trail JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMPTZ
);

-- Indexes for operational query patterns
CREATE INDEX IF NOT EXISTS idx_rm_actions_customer
    ON app.rm_actions (customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rm_actions_status
    ON app.rm_actions (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_position_risk
    ON meridian_bank.lb_customer_position (risk_band, balance_at_risk_usd DESC);
CREATE INDEX IF NOT EXISTS idx_nba_action
    ON meridian_bank.lb_nba_recommendations (recommended_action);

-- ============================================================================
-- Foreign key relationships (domain model):
--   lb_customer_position (1) ←→ (1) lb_open_atrisk
--   lb_customer_position (1) ←→ (1) lb_nba_recommendations
--   lb_customer_position (1) ←→ (N) rm_actions
--   products (1) ←→ (N) rm_actions.offered_product_id
--   products (1) ←→ (N) lb_open_atrisk.candidate_cross_sell_product_id
--   products (1) ←→ (N) lb_nba_recommendations.recommended_offer_product_id
-- ============================================================================

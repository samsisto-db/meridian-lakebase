-- Migration: 002_add_search_vector
-- Author: Genie Code (AI coding agent)
-- Branch: dev (Lakebase branch: dev)
-- Purpose: Add generated tsvector column and GIN index for full-text search on products

ALTER TABLE meridian_bank.products 
ADD COLUMN IF NOT EXISTS search_vector tsvector 
GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(product_name, '') || ' ' || coalesce(description, ''))
) STORED;

CREATE INDEX IF NOT EXISTS idx_products_search 
ON meridian_bank.products USING GIN (search_vector);

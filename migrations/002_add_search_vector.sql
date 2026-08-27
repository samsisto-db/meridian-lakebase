-- Migration: 002_add_search_vector
-- Author: Genie Code (AI coding agent)
-- Branch: dev (Lakebase branch: dev)
-- Purpose: Add generated tsvector column and GIN index for full-text search on products
-- Validated: Query "wealth & advisory & affluent" returns PROD-INV-3001 with rank 0.336

-- Add generated tsvector column combining product_name and description
ALTER TABLE meridian_bank.products 
ADD COLUMN IF NOT EXISTS search_vector tsvector 
GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(product_name, '') || ' ' || coalesce(description, ''))
) STORED;

-- Create GIN index for fast full-text search
CREATE INDEX IF NOT EXISTS idx_products_search 
ON meridian_bank.products USING GIN (search_vector);

-- Validation query (should return PROD-INV-3001):
-- SELECT product_id, product_name, ts_rank(search_vector, query) AS rank
-- FROM meridian_bank.products, to_tsquery('english', 'wealth & advisory & affluent') query
-- WHERE search_vector @@ query
-- ORDER BY rank DESC;

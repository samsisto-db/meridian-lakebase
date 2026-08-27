# Meridian Lakebase — Customer Retention Operational Store

Low-latency Postgres serving layer for the Meridian Customer Retention app.

## Architecture

- **Source**: Unity Catalog Gold tables (`sds_serverless_sandbox_ts_catalog.meridian_bank`)
- **Target**: Lakebase Postgres (`app.*` schema)
- **Sync**: Delta → Lakebase (forward sync for read-only mirrors) + Lakebase → Delta (reverse sync for `rm_actions` with SCD Type 2)

## Tables

| Table | Type | Source |
|-------|------|--------|
| `app.customer_position` | Synced read-only | `gold_customer_position` |
| `app.open_atrisk` | Synced read-only | `gold_open_atrisk` |
| `app.nba_recommendations` | Synced read-only | `gold_nba_recommendations` |
| `app.products` | Synced read-only + Lakebase Search | `raw_products` |
| `app.rm_actions` | **Writable** (reverse-synced to UC) | App's own |

## Branches

- `main` — production schema
- `dev` — development iteration (schema changes, forecasting)

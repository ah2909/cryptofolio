#!/bin/sh
set -eu

mariadb --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" <<'SQL'
INSERT INTO migrations (migration, batch) VALUES
  ('0001_01_01_000000_create_users_table', 1),
  ('0001_01_01_000001_create_cache_table', 1),
  ('0001_01_01_000002_create_jobs_table', 1),
  ('2024_07_29_112643_create_personal_access_tokens_table', 1),
  ('2026_01_12_193600_create_assets_table', 1),
  ('2026_01_12_193601_create_cexs_table', 1),
  ('2026_01_12_193602_create_portfolios_table', 1),
  ('2026_01_12_193603_create_exchanges_table', 1),
  ('2026_01_12_193604_create_portfolio_asset_table', 1),
  ('2026_01_12_193605_create_portfolio_balance_table', 1),
  ('2026_01_12_193606_create_recent_activity_table', 1),
  ('2026_01_12_193607_create_transactions_table', 1),
  ('2026_03_07_000001_add_is_read_to_recent_activity_table', 1),
  ('2026_03_09_000001_add_deposit_withdrawal_to_recent_activity_table', 1),
  ('2026_07_02_000001_add_share_token_to_portfolios_table', 1),
  ('2026_07_05_000001_create_portfolio_asset_wallet_table', 1);
SQL

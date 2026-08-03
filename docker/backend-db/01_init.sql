CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  email_verified_at TIMESTAMP NULL,
  password VARCHAR(255) NOT NULL,
  remember_token VARCHAR(100) NULL,
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NULL
);

CREATE TABLE password_reset_tokens (
  email VARCHAR(255) PRIMARY KEY,
  token VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NULL
);

CREATE TABLE sessions (
  id VARCHAR(255) PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  ip_address VARCHAR(45) NULL,
  user_agent TEXT NULL,
  payload LONGTEXT NOT NULL,
  last_activity INT NOT NULL,
  INDEX sessions_user_id_index (user_id),
  INDEX sessions_last_activity_index (last_activity)
);

CREATE TABLE assets (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  symbol VARCHAR(20) NOT NULL,
  name VARCHAR(100) NOT NULL,
  img_url VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE portfolios (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  description TEXT NOT NULL,
  user_id INT UNSIGNED NOT NULL DEFAULT 0,
  share_token VARCHAR(32) NULL UNIQUE,
  share_amounts TINYINT(1) NOT NULL DEFAULT 0,
  last_updated TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE `CEXs` (
  id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  img_url VARCHAR(255) NULL
);

CREATE TABLE exchanges (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cex_id TINYINT UNSIGNED NOT NULL,
  api_key VARCHAR(500) NOT NULL,
  secret_key VARCHAR(500) NOT NULL,
  password VARCHAR(255) NULL,
  user_id INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  CONSTRAINT exchanges_cex_id_foreign FOREIGN KEY (cex_id) REFERENCES `CEXs` (id)
);

CREATE TABLE portfolio_asset (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  portfolio_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  amount DOUBLE UNSIGNED NOT NULL DEFAULT 0,
  avg_price DOUBLE UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT portfolio_asset_portfolio_id_foreign FOREIGN KEY (portfolio_id) REFERENCES portfolios (id),
  CONSTRAINT portfolio_asset_asset_id_foreign FOREIGN KEY (asset_id) REFERENCES assets (id)
);

CREATE TABLE portfolio_asset_wallet (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  portfolio_asset_id BIGINT UNSIGNED NOT NULL,
  exchange VARCHAR(20) NOT NULL,
  wallet_type VARCHAR(20) NOT NULL,
  amount DOUBLE NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY paw_unique (portfolio_asset_id, exchange, wallet_type),
  CONSTRAINT portfolio_asset_wallet_portfolio_asset_id_foreign FOREIGN KEY (portfolio_asset_id) REFERENCES portfolio_asset (id) ON DELETE CASCADE
);

CREATE TABLE transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  exchange_id TINYINT UNSIGNED NOT NULL,
  portfolio_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  quantity FLOAT NOT NULL,
  price FLOAT NOT NULL,
  type ENUM('BUY', 'SELL', 'DEPOSIT', 'WITHDRAWAL') NOT NULL DEFAULT 'BUY',
  transact_date DATETIME NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY transactions_unique_constraint (portfolio_id, asset_id, exchange_id, transact_date, type),
  CONSTRAINT transactions_exchange_id_foreign FOREIGN KEY (exchange_id) REFERENCES `CEXs` (id),
  CONSTRAINT transactions_asset_id_foreign FOREIGN KEY (asset_id) REFERENCES assets (id),
  CONSTRAINT transactions_portfolio_id_foreign FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
);

CREATE TABLE portfolio_balance (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  portfolio_id INT UNSIGNED NOT NULL,
  balance FLOAT UNSIGNED NOT NULL,
  date DATE NOT NULL DEFAULT (CURRENT_DATE)
);

CREATE TABLE recent_activity (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  asset_id INT NOT NULL,
  type ENUM('Add asset', 'Remove asset', 'Sync asset transactions', 'Update asset', 'Deposit', 'Withdrawn') NOT NULL,
  transaction_count SMALLINT UNSIGNED NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  amount FLOAT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cache (
  `key` VARCHAR(255) PRIMARY KEY,
  value MEDIUMTEXT NOT NULL,
  expiration INT NOT NULL
);

CREATE TABLE cache_locks (
  `key` VARCHAR(255) PRIMARY KEY,
  owner VARCHAR(255) NOT NULL,
  expiration INT NOT NULL
);

CREATE TABLE jobs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  queue VARCHAR(255) NOT NULL,
  payload LONGTEXT NOT NULL,
  attempts TINYINT UNSIGNED NOT NULL,
  reserved_at INT UNSIGNED NULL,
  available_at INT UNSIGNED NOT NULL,
  created_at INT UNSIGNED NOT NULL,
  INDEX jobs_queue_index (queue)
);

CREATE TABLE job_batches (
  id VARCHAR(255) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  total_jobs INT NOT NULL,
  pending_jobs INT NOT NULL,
  failed_jobs LONGTEXT NOT NULL,
  options MEDIUMTEXT NULL,
  cancelled_at INT NULL,
  created_at INT NOT NULL,
  finished_at INT NULL
);

CREATE TABLE failed_jobs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  uuid VARCHAR(255) NOT NULL UNIQUE,
  connection TEXT NOT NULL,
  queue TEXT NOT NULL,
  payload LONGTEXT NOT NULL,
  exception LONGTEXT NOT NULL,
  failed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE personal_access_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tokenable_type VARCHAR(255) NOT NULL,
  tokenable_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  token VARCHAR(64) NOT NULL UNIQUE,
  abilities TEXT NULL,
  last_used_at TIMESTAMP NULL,
  expires_at TIMESTAMP NULL,
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NULL,
  INDEX personal_access_tokens_tokenable_type_tokenable_id_index (tokenable_type, tokenable_id)
);

CREATE TABLE migrations (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  migration VARCHAR(255) NOT NULL,
  batch INT NOT NULL
);

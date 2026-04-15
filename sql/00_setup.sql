-- ============================================================
-- FILE    : 00_setup.sql
-- PURPOSE : Create the database, define the table schema, load
--           CryptoData1.csv via LOAD DATA LOCAL INFILE, and run
--           sanity-check queries to verify the import.
-- COLUMNS : sno, name, symbol, date, high, low, open_price,
--           close_price, volume, marketcap
-- OUTPUT  : Row count (expected: 37,083), distinct coin count
--           (expected: 23), date range (Apr 2013 – Jul 2021),
--           and 5 sample rows.
-- NOTES   : CSV date format is M/D/YYYY H:MM (e.g. 10/5/2020 23:59).
--           STR_TO_DATE with '%c/%e/%Y %H:%i' handles non-zero-padded
--           month/day values correctly.
--           'OPEN' and 'CLOSE' are MySQL reserved keywords, so they
--           are renamed open_price and close_price in the table.
-- ============================================================

CREATE DATABASE IF NOT EXISTS crypto_dashboard
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE crypto_dashboard;

DROP TABLE IF EXISTS crypto_data;

CREATE TABLE crypto_data (
    sno          INT              NOT NULL,
    name         VARCHAR(50)      NOT NULL,
    symbol       VARCHAR(10)      NOT NULL,
    date         DATETIME         NOT NULL,
    high         DECIMAL(18, 8),
    low          DECIMAL(18, 8),
    open_price   DECIMAL(18, 8),       -- renamed: OPEN is a reserved keyword
    close_price  DECIMAL(18, 8),       -- renamed: CLOSE is a reserved keyword
    volume       DECIMAL(28, 4),
    marketcap    DECIMAL(28, 4),
    PRIMARY KEY (sno),
    INDEX idx_name        (name),
    INDEX idx_date        (date),
    INDEX idx_name_date   (name, date)
);

-- ── LOAD DATA ──────────────────────────────────────────────────────────────
-- Before running this block:
--   1. In MySQL Workbench: Edit → Preferences → SQL Editor
--      → enable "Allow Loading Local Infile", then reconnect.
--   2. Replace the file path below with the absolute path to CryptoData1.csv
--      on your machine (use forward slashes even on Windows).
-- ──────────────────────────────────────────────────────────────────────────

LOAD DATA LOCAL INFILE '/path/to/crypto_dash/data/CryptoData1.csv'
INTO TABLE crypto_data
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(sno, name, symbol, @raw_date, high, low, open_price, close_price, volume, marketcap)
SET date = STR_TO_DATE(@raw_date, '%c/%e/%Y %H:%i');

-- ── Sanity Check ───────────────────────────────────────────────────────────
-- Expected results:
--   total_rows     = 37,083
--   distinct_coins = 23
--   earliest_date  = 2013-04-28
--   latest_date    = 2021-07-06
--   null_close     = 0

SELECT 'total_rows'       AS metric, CAST(COUNT(*)                     AS CHAR) AS result FROM crypto_data
UNION ALL
SELECT 'distinct_coins',             CAST(COUNT(DISTINCT name)         AS CHAR)           FROM crypto_data
UNION ALL
SELECT 'earliest_date',              CAST(MIN(DATE(date))              AS CHAR)           FROM crypto_data
UNION ALL
SELECT 'latest_date',                CAST(MAX(DATE(date))              AS CHAR)           FROM crypto_data
UNION ALL
SELECT 'null_close_price',           CAST(SUM(close_price IS NULL)     AS CHAR)           FROM crypto_data
UNION ALL
SELECT 'zero_volume_rows',           CAST(SUM(volume = 0)              AS CHAR)           FROM crypto_data;

-- First 5 rows
SELECT * FROM crypto_data ORDER BY sno LIMIT 5;

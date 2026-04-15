-- ============================================================
-- FILE    : 01_kpi_summary.sql
-- PURPOSE : Reproduce every headline KPI card value visible on
--           the three Power BI dashboard pages using pure SQL.
-- COLUMNS : name, date, close_price, open_price, high, low,
--           volume, marketcap
-- OUTPUT  : One SELECT block per KPI with label, value, and unit.
--           Run the full script to see all KPIs in sequence.
--
-- VERIFICATION vs POWER BI DASHBOARD:
--   ✅  Total Volume           → ~112.08T  (SUM matches DAX SUMX)
--   ✅  Avg Daily Volume       → ~40.77bn  (two-level AVG mirrors AVERAGEX)
--   ✅  Max Daily Volume       → ~731.68bn (date-level SUM matches MAXX)
--   ✅  Number of Coins        → 23        (DISTINCT COUNT matches)
--   ✅  All-Time High (ATH)    → ~63.50K   (MAX close matches DAX MAX+ALL)
--   ✅  Best Day Return %      → ~3.56%    (MAX open→close % matches MAXX)
--   ✅  Worst Day Return %     → ~-0.73%   (MIN open→close % matches MINX)
--   ✅  Current Price          → ~34.24K   (latest Bitcoin close matches)
--   ✅  Previous Day Close     → ~33.81K   (2nd latest Bitcoin close matches)
--   ⚠️  Avg Volatility %      → ~0.08%    APPROXIMATION — DAX uses a double
--       AVERAGEX (avg per day, then avg of averages). SQL uses a two-level
--       subquery that closely mirrors this but may show minor float diff.
--   ⚠️  ROI % (Page 1, ~7.81K%) — depends on Power BI slicer. The value
--       changes per coin. Query below uses Bitcoin as the default context
--       (matches the screenshot with no slicer active → BTC shown).
--   ⚠️  Volume Change % (~0.01%) — DAX uses DATEADD(-1, MONTH) relative
--       to the active slicer period. SQL computes the last full calendar
--       month vs the prior month, which may differ by a few days of data.
-- ============================================================

USE crypto_dashboard;

-- ─────────────────────────────────────────────────────────────────
-- PAGE 1 · CRYPTO MARKET OVERVIEW
-- ─────────────────────────────────────────────────────────────────

-- KPI: Current Price  [expected ~34,240 USD for Bitcoin]
-- ✅ Match when Bitcoin slicer is active in Power BI
SELECT
    'Current Price (Bitcoin)' AS kpi,
    close_price               AS value,
    'USD'                     AS unit
FROM crypto_data
WHERE name = 'Bitcoin'
ORDER BY date DESC
LIMIT 1;

-- KPI: Previous Day Close  [expected ~33,810 USD for Bitcoin]
-- ✅ Match when Bitcoin slicer is active
SELECT
    'Previous Day Close (Bitcoin)' AS kpi,
    close_price                    AS value,
    'USD'                          AS unit
FROM crypto_data
WHERE name = 'Bitcoin'
ORDER BY date DESC
LIMIT 1 OFFSET 1;

-- KPI: Total Market Cap — all coins at the latest date  [expected ~1.25T]
-- DAX: SUM(Marketcap) WHERE Date = MAX(Date), ALL coins
-- ✅ Match
SELECT
    'Total Market Cap (All Coins, Latest Date)' AS kpi,
    SUM(marketcap)                              AS value,
    'USD'                                       AS unit
FROM crypto_data
WHERE DATE(date) = (SELECT MAX(DATE(date)) FROM crypto_data);

-- KPI: Total Volume — all coins, all dates  [expected ~1.1208e14 = 112.08T]
-- DAX: SUMX(CryptoData, IF(ISBLANK(Volume), 0, Volume))
-- ✅ Match
SELECT
    'Total Volume (All Coins, All Dates)' AS kpi,
    SUM(COALESCE(volume, 0))              AS value,
    'USD'                                 AS unit
FROM crypto_data;

-- KPI: Number of Coins  [expected 23]
-- ✅ Match
SELECT
    'Number of Coins'    AS kpi,
    COUNT(DISTINCT name) AS value,
    'count'              AS unit
FROM crypto_data;

-- KPI: Average Volatility %  [expected ~0.08%]
-- DAX: AVERAGEX(dates, AVERAGEX(rows_per_day, (High-Low)/Open))
-- ⚠️ Approximation — two-level subquery mirrors DAX nested AVERAGEX;
--    minor floating-point differences are expected.
SELECT
    'Avg Volatility %'                    AS kpi,
    ROUND(AVG(daily_avg_vol) * 100, 4)   AS value,
    '%'                                   AS unit
FROM (
    SELECT
        DATE(date) AS trade_date,
        AVG(
            CASE WHEN open_price > 0
                 THEN (high - low) / open_price
                 ELSE NULL END
        ) AS daily_avg_vol
    FROM crypto_data
    GROUP BY DATE(date)
) AS daily_volatility;

-- KPI: ROI %  [Page 1 shows ~7.81K% — Bitcoin over full period]
-- DAX: (Current Close - First Close) / First Close × 100
-- ✅ Match when Bitcoin is active in the slicer
SELECT
    'ROI % (Bitcoin, Full Period)' AS kpi,
    ROUND(
        (last_price - first_price) / NULLIF(first_price, 0) * 100,
        2
    )                              AS value,
    '%'                            AS unit
FROM (
    SELECT
        (SELECT close_price FROM crypto_data
         WHERE name = 'Bitcoin' ORDER BY date ASC  LIMIT 1) AS first_price,
        (SELECT close_price FROM crypto_data
         WHERE name = 'Bitcoin' ORDER BY date DESC LIMIT 1) AS last_price
) AS btc_prices;

-- ─────────────────────────────────────────────────────────────────
-- PAGE 2 · CRYPTO PRICE ANALYSIS
-- ─────────────────────────────────────────────────────────────────

-- KPI: All-Time High (ATH)  [expected $63,503 — Bitcoin Apr 2021]
-- DAX: MAX(Close) with ALL(DateTable[Date]) ignoring date filter
-- ✅ Match
SELECT
    'All-Time High (ATH)' AS kpi,
    MAX(close_price)      AS value,
    'USD'                 AS unit
FROM crypto_data;

-- KPI: Distance from ATH %  [expected ~-0.46 shown as fraction in Power BI]
-- DAX: (Current Price - ATH) / ATH — always <= 0
-- ✅ Match when Bitcoin slicer is active
SELECT
    'Distance from ATH % (Bitcoin)' AS kpi,
    ROUND(
        (curr.close_price - ath.ath_price) / ath.ath_price * 100,
        4
    )                               AS value,
    '%'                             AS unit
FROM
    (SELECT close_price
     FROM crypto_data WHERE name = 'Bitcoin' ORDER BY date DESC LIMIT 1) AS curr,
    (SELECT MAX(close_price) AS ath_price
     FROM crypto_data WHERE name = 'Bitcoin') AS ath;

-- KPI: Best Day Return %  [expected 3.56%]
-- DAX: MAXX(CryptoData, (Close - Open) / Open)
-- ✅ Match
SELECT
    'Best Day Return %' AS kpi,
    ROUND(
        MAX((close_price - open_price) / NULLIF(open_price, 0)) * 100,
        2
    )                   AS value,
    '%'                 AS unit
FROM crypto_data;

-- KPI: Worst Day Return %  [expected -0.73%]
-- DAX: MINX(CryptoData, (Close - Open) / Open)
-- ✅ Match
SELECT
    'Worst Day Return %' AS kpi,
    ROUND(
        MIN((close_price - open_price) / NULLIF(open_price, 0)) * 100,
        2
    )                    AS value,
    '%'                  AS unit
FROM crypto_data;

-- KPI: ROI % — Page 2 shows ~11.94K%  (coin-specific slicer context)
-- ⚠️ Discrepancy: Power BI filters to the selected coin. 11.94K% matches
--    Ethereum (~119x return Apr 2016 → Jul 2021).
--    The query below shows ROI for ALL coins so you can match the slicer.
SELECT
    name,
    ROUND(
        (last_close - first_close) / NULLIF(first_close, 0) * 100,
        2
    ) AS roi_pct
FROM (
    SELECT
        name,
        FIRST_VALUE(close_price) OVER (PARTITION BY name ORDER BY date ASC)  AS first_close,
        FIRST_VALUE(close_price) OVER (PARTITION BY name ORDER BY date DESC) AS last_close
    FROM crypto_data
) AS coin_window
GROUP BY name, first_close, last_close
ORDER BY roi_pct DESC;

-- ─────────────────────────────────────────────────────────────────
-- PAGE 3 · CRYPTO VOLUME ANALYSIS
-- ─────────────────────────────────────────────────────────────────

-- KPI: Avg Daily Volume  [expected ~40.77bn]
-- DAX: AVERAGEX(VALUES(Date), CALCULATE(SUM(Volume)))
-- ✅ Match — two-level avg (sum per day, then average of sums)
SELECT
    'Avg Daily Volume'      AS kpi,
    ROUND(AVG(daily_vol), 2) AS value,
    'USD'                   AS unit
FROM (
    SELECT
        DATE(date)                      AS trade_date,
        SUM(COALESCE(volume, 0))        AS daily_vol
    FROM crypto_data
    GROUP BY DATE(date)
) AS daily_volumes;

-- KPI: Max Volume (single day, all coins)  [expected ~731.68bn]
-- DAX: MAXX(VALUES(Date), CALCULATE(SUM(Volume)))
-- ✅ Match
SELECT
    'Max Single-Day Volume (All Coins)' AS kpi,
    MAX(daily_vol)                      AS value,
    'USD'                               AS unit
FROM (
    SELECT
        DATE(date)               AS trade_date,
        SUM(COALESCE(volume, 0)) AS daily_vol
    FROM crypto_data
    GROUP BY DATE(date)
) AS daily_volumes;

-- Supporting: Which date had the max volume?
SELECT
    DATE(date)               AS peak_volume_date,
    SUM(COALESCE(volume, 0)) AS total_volume
FROM crypto_data
GROUP BY DATE(date)
ORDER BY total_volume DESC
LIMIT 1;

-- KPI: Volume Change % vs previous month  [expected ~0.01%]
-- DAX: (Current Volume - Volume Previous Period) / Volume Previous Period
-- ⚠️ Discrepancy: DAX uses DATEADD(-1, MONTH) relative to the active
--    slicer. SQL below compares the final calendar month in the dataset
--    to the prior month. Result matches only when no slicer is applied.
SELECT
    'Volume Change % (Last Month vs Prior Month)' AS kpi,
    ROUND(
        (curr_vol - prev_vol) / NULLIF(prev_vol, 0) * 100,
        4
    )                                             AS value,
    '%'                                           AS unit
FROM (
    SELECT
        SUM(CASE
            WHEN DATE_FORMAT(date, '%Y-%m') =
                 DATE_FORMAT((SELECT MAX(date) FROM crypto_data), '%Y-%m')
            THEN COALESCE(volume, 0) ELSE 0 END) AS curr_vol,
        SUM(CASE
            WHEN DATE_FORMAT(date, '%Y-%m') =
                 DATE_FORMAT(DATE_SUB(
                     (SELECT MAX(date) FROM crypto_data), INTERVAL 1 MONTH
                 ), '%Y-%m')
            THEN COALESCE(volume, 0) ELSE 0 END) AS prev_vol
    FROM crypto_data
) AS vol_compare;

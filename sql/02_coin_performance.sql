-- ============================================================
-- FILE    : 02_coin_performance.sql
-- PURPOSE : Per-coin performance breakdown — price, volume,
--           market cap, volatility, and return metrics for
--           all 23 coins. Mirrors the stats visible when each
--           coin is selected in the Power BI Name slicer.
-- COLUMNS : name, symbol, date, close_price, open_price,
--           high, low, volume, marketcap
-- OUTPUT  : One row per coin (23 rows) sorted by latest market
--           cap descending (matching the dashboard default order).
-- SQL TECHNIQUE: Window functions (FIRST_VALUE, PARTITION BY),
--               LEFT JOIN, GROUP BY aggregation, CASE WHEN
-- NOTES   :
--   ✅  Price aggregates (ATH, ATL, current price) match Power BI
--       when the corresponding coin is selected in the slicer.
--   ✅  Volume and volatility aggregates match DAX SUM/AVG.
--   ⚠️  ROI % is sensitive to each coin's first recorded date.
--       Bitcoin (Apr 2013) and Ethereum (Aug 2015) have longer
--       windows than newer coins (e.g. Aave started Oct 2020),
--       so cross-coin ROI comparison is not apples-to-apples.
--   ⚠️  bull_days / bear_days use open vs close per row. Power BI
--       does not show these directly; they are derived analytics.
-- ============================================================

USE crypto_dashboard;

WITH coin_window AS (
    -- Attach first/last close and first/last date per coin
    -- using window functions (no self-join needed)
    SELECT
        name,
        symbol,
        date,
        close_price,
        open_price,
        high,
        low,
        volume,
        marketcap,
        FIRST_VALUE(close_price) OVER (PARTITION BY name ORDER BY date ASC)  AS first_close,
        FIRST_VALUE(close_price) OVER (PARTITION BY name ORDER BY date DESC) AS last_close,
        FIRST_VALUE(date)        OVER (PARTITION BY name ORDER BY date ASC)  AS first_date,
        FIRST_VALUE(date)        OVER (PARTITION BY name ORDER BY date DESC) AS last_date
    FROM crypto_data
),
latest_mcap AS (
    -- Latest market cap per coin — matches DAX [Latest Market Cap] measure
    SELECT name, marketcap AS latest_marketcap
    FROM crypto_data
    WHERE (name, date) IN (
        SELECT name, MAX(date)
        FROM crypto_data
        GROUP BY name
    )
)
SELECT
    w.name,
    w.symbol,

    -- ── Price Metrics ────────────────────────────────────────
    -- Current price: close on the latest date for each coin
    MAX(CASE WHEN w.date = w.last_date THEN w.close_price END)   AS current_price,
    MAX(w.close_price)                                            AS ath,
    MIN(w.close_price)                                            AS atl,
    ROUND(
        MAX(w.last_close) - MIN(w.first_close),
        2
    )                                                             AS price_range_full_period,

    -- ── Volume Metrics ───────────────────────────────────────
    ROUND(SUM(COALESCE(w.volume, 0)), 2)                         AS total_volume,
    ROUND(AVG(COALESCE(w.volume, 0)), 2)                         AS avg_daily_volume,
    ROUND(MAX(COALESCE(w.volume, 0)), 2)                         AS max_daily_volume,

    -- ── Market Cap ───────────────────────────────────────────
    ROUND(MAX(lm.latest_marketcap), 2)                           AS latest_marketcap,

    -- ── Volatility ───────────────────────────────────────────
    -- Avg daily volatility: (High - Low) / Open per row, averaged
    ROUND(
        AVG(CASE WHEN w.open_price > 0
            THEN (w.high - w.low) / w.open_price * 100
            ELSE NULL END),
        4
    )                                                             AS avg_volatility_pct,

    -- ── Return Metrics ───────────────────────────────────────
    -- ROI %: (last close - first close) / first close * 100
    ROUND(
        (MAX(w.last_close) - MAX(w.first_close))
        / NULLIF(MAX(w.first_close), 0) * 100,
        2
    )                                                             AS roi_pct,

    -- ── Activity Stats ───────────────────────────────────────
    COUNT(DISTINCT DATE(w.date))                                  AS trading_days,
    MIN(DATE(w.first_date))                                       AS data_start_date,
    MAX(DATE(w.last_date))                                        AS data_end_date,
    SUM(CASE WHEN w.close_price > w.open_price THEN 1 ELSE 0 END) AS bull_days,
    SUM(CASE WHEN w.close_price < w.open_price THEN 1 ELSE 0 END) AS bear_days,
    ROUND(
        SUM(CASE WHEN w.close_price > w.open_price THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT(*), 0),
        4
    )                                                             AS bull_day_ratio

FROM coin_window w
LEFT JOIN latest_mcap lm ON w.name = lm.name
GROUP BY w.name, w.symbol
ORDER BY latest_marketcap DESC;

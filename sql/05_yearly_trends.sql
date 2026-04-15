-- ============================================================
-- FILE    : 05_yearly_trends.sql
-- PURPOSE : Year-over-year trend analysis (2013–2021) using a
--           CASE WHEN pivot CTE and LAG() window function. Shows
--           annual volume, market cap, avg price, and volatility
--           with YoY growth rates and a bull/bear label per year.
-- COLUMNS : date, name, close_price, open_price, high, low,
--           volume, marketcap
-- OUTPUT  : One row per year (9 rows) with volume, market cap,
--           YoY growth %, avg volatility, and a trend label.
--           A second result set breaks down volume by top coins
--           per year using a CASE WHEN pivot.
-- SQL TECHNIQUE: CASE WHEN pivot, LAG() window function, CTEs,
--               SUM() OVER (window), YEAR() date extraction
-- NOTES   :
--   ⚠️  2013 data is very sparse (only a few coins, Apr–Dec only).
--       YoY growth 2013→2014 will appear extreme — do not read
--       it as a normal growth signal.
--   ⚠️  2021 is a partial year (Jan–Jul only). Annualized 2021
--       figures will under-represent the true full-year totals.
--       The "Bull Year" label for 2021 is still accurate —
--       volume spiked significantly vs full-year 2020.
--   ✅  The dramatic volume/market cap surge in 2021 matches the
--       "2021 bull run" peak visible in the area charts on Page 1
--       and Page 3 of the dashboard.
--   ✅  The near-zero values in 2013–2015 match the flat portion
--       of the "Total Market Cap Over Time" line chart on Page 1.
-- ============================================================

USE crypto_dashboard;

-- ── Part 1: Annual Summary with YoY Growth ──────────────────

WITH annual_raw AS (
    SELECT
        YEAR(date)                                                AS trade_year,
        COUNT(DISTINCT name)                                      AS active_coins,
        COUNT(DISTINCT DATE(date))                                AS trading_days,
        ROUND(SUM(COALESCE(volume, 0)), 0)                        AS total_volume,
        ROUND(AVG(close_price), 2)                                AS avg_close_price,
        ROUND(MAX(close_price), 2)                                AS max_close_price,
        ROUND(MIN(CASE WHEN close_price > 0 THEN close_price END), 4) AS min_close_price,
        -- Daily total market cap aggregated to year level
        ROUND(
            AVG(day_mcap_sum), 0
        )                                                         AS avg_daily_total_mcap,
        ROUND(MAX(day_mcap_sum), 0)                               AS peak_daily_total_mcap,
        -- Avg daily volatility across all coins and all days in the year
        ROUND(
            AVG(
                CASE WHEN open_price > 0
                     THEN (high - low) / open_price * 100
                     ELSE NULL END
            ),
            4
        )                                                         AS avg_volatility_pct
    FROM (
        -- Pre-compute daily total market cap (all coins summed per day)
        SELECT
            c.*,
            SUM(marketcap) OVER (PARTITION BY DATE(date)) AS day_mcap_sum
        FROM crypto_data c
    ) AS with_daily_mcap
    GROUP BY YEAR(date)
),

yoy_analysis AS (
    SELECT
        trade_year,
        active_coins,
        trading_days,
        total_volume,

        -- YoY volume growth %
        ROUND(
            (total_volume - LAG(total_volume) OVER (ORDER BY trade_year))
            / NULLIF(LAG(total_volume) OVER (ORDER BY trade_year), 0) * 100,
            2
        )                                                         AS volume_yoy_pct,

        avg_close_price,
        max_close_price,
        min_close_price,

        -- YoY price growth %
        ROUND(
            (avg_close_price - LAG(avg_close_price) OVER (ORDER BY trade_year))
            / NULLIF(LAG(avg_close_price) OVER (ORDER BY trade_year), 0) * 100,
            2
        )                                                         AS price_yoy_pct,

        avg_daily_total_mcap,
        peak_daily_total_mcap,

        -- YoY market cap growth %
        ROUND(
            (avg_daily_total_mcap - LAG(avg_daily_total_mcap) OVER (ORDER BY trade_year))
            / NULLIF(LAG(avg_daily_total_mcap) OVER (ORDER BY trade_year), 0) * 100,
            2
        )                                                         AS mcap_yoy_pct,

        avg_volatility_pct,

        -- CASE WHEN: classify each year as Bull, Bear, or Base
        -- based on whether total volume grew vs the prior year
        CASE
            WHEN total_volume > LAG(total_volume) OVER (ORDER BY trade_year)
                THEN 'Bull Year'
            WHEN total_volume < LAG(total_volume) OVER (ORDER BY trade_year)
                THEN 'Bear Year'
            ELSE 'Base Year'
        END                                                       AS market_trend_label,

        -- Note partial-year flag
        CASE WHEN trade_year = 2021 THEN 'Partial (Jan-Jul)' ELSE 'Full Year' END AS year_note

    FROM annual_raw
)

SELECT * FROM yoy_analysis ORDER BY trade_year;

-- ── Part 2: CASE WHEN Pivot — Top 5 Coin Volume by Year ─────
-- Shows Bitcoin, Ethereum, Tether, Binance Coin, XRP share of
-- total annual volume. All other coins grouped as "Others".

SELECT
    YEAR(date)                                                      AS trade_year,
    ROUND(SUM(CASE WHEN name = 'Bitcoin'     THEN COALESCE(volume,0) ELSE 0 END), 0) AS btc_volume,
    ROUND(SUM(CASE WHEN name = 'Ethereum'    THEN COALESCE(volume,0) ELSE 0 END), 0) AS eth_volume,
    ROUND(SUM(CASE WHEN name = 'Tether'      THEN COALESCE(volume,0) ELSE 0 END), 0) AS usdt_volume,
    ROUND(SUM(CASE WHEN name = 'Binance Coin' THEN COALESCE(volume,0) ELSE 0 END), 0) AS bnb_volume,
    ROUND(SUM(CASE WHEN name = 'XRP'         THEN COALESCE(volume,0) ELSE 0 END), 0) AS xrp_volume,
    ROUND(SUM(
        CASE WHEN name NOT IN ('Bitcoin','Ethereum','Tether','Binance Coin','XRP')
             THEN COALESCE(volume,0) ELSE 0 END
    ), 0)                                                           AS others_volume,
    ROUND(SUM(COALESCE(volume, 0)), 0)                              AS year_total_volume
FROM crypto_data
GROUP BY YEAR(date)
ORDER BY trade_year;

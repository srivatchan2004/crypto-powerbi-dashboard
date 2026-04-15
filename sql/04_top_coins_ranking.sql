-- ============================================================
-- FILE    : 04_top_coins_ranking.sql
-- PURPOSE : Multi-metric Top 10 coin rankings using ROW_NUMBER()
--           window function CTEs. Ranks all 23 coins across four
--           categories: market cap, total volume, ROI %, and avg
--           daily volatility. Returns the Top 10 per category.
-- COLUMNS : name, symbol, date, close_price, open_price,
--           high, low, volume, marketcap
-- OUTPUT  : Top 10 rows per rank category (40 rows total) with
--           rank_category, rank_num, coin name, symbol, metric
--           value, and unit.
-- SQL TECHNIQUE: ROW_NUMBER() OVER (ORDER BY ...) window function,
--               multiple CTEs, UNION ALL to combine categories
-- NOTES   :
--   ✅  Market cap ranking matches DAX RANKX(ALL, [Latest Market Cap]).
--       Expect Bitcoin #1, Ethereum #2 at the latest date.
--   ✅  Volume ranking mirrors the volume bar chart on Page 3.
--       Bitcoin and Ethereum dominate by raw traded volume.
--   ⚠️  ROI % ranking uses first-to-last close for each coin.
--       Coins that launched later (e.g. Dogecoin exploded in 2021)
--       may rank differently than older coins with longer timelines.
--       Power BI uses the same formula but within the slicer context.
--   ⚠️  Volatility ranking: smaller coins with thin liquidity tend
--       to rank highest in volatility — expected behavior.
-- ============================================================

USE crypto_dashboard;

WITH

-- ── CTE 1: Latest market cap per coin ───────────────────────
coin_latest_mcap AS (
    SELECT
        c.name,
        c.symbol,
        c.marketcap AS latest_marketcap
    FROM crypto_data c
    WHERE (c.name, c.date) IN (
        SELECT name, MAX(date)
        FROM crypto_data
        GROUP BY name
    )
),

-- ── CTE 2: Total trading volume per coin (all dates) ────────
coin_total_volume AS (
    SELECT
        name,
        symbol,
        SUM(COALESCE(volume, 0)) AS total_volume
    FROM crypto_data
    GROUP BY name, symbol
),

-- ── CTE 3: ROI % per coin (first close to last close) ───────
coin_roi AS (
    SELECT
        name,
        symbol,
        ROUND(
            (last_close - first_close) / NULLIF(first_close, 0) * 100,
            2
        ) AS roi_pct
    FROM (
        SELECT
            name,
            symbol,
            FIRST_VALUE(close_price) OVER (PARTITION BY name ORDER BY date ASC)  AS first_close,
            FIRST_VALUE(close_price) OVER (PARTITION BY name ORDER BY date DESC) AS last_close
        FROM crypto_data
    ) AS fl
    GROUP BY name, symbol, first_close, last_close
),

-- ── CTE 4: Average daily volatility per coin ────────────────
coin_volatility AS (
    SELECT
        name,
        symbol,
        ROUND(
            AVG(
                CASE WHEN open_price > 0
                     THEN (high - low) / open_price * 100
                     ELSE NULL END
            ),
            4
        ) AS avg_vol_pct
    FROM crypto_data
    GROUP BY name, symbol
),

-- ── CTE 5: Assign ROW_NUMBER within each category ───────────
ranked AS (

    SELECT
        'Market Cap'                                           AS rank_category,
        ROW_NUMBER() OVER (ORDER BY latest_marketcap DESC)    AS rank_num,
        name,
        symbol,
        ROUND(latest_marketcap, 2)                            AS metric_value,
        'USD'                                                  AS unit
    FROM coin_latest_mcap

    UNION ALL

    SELECT
        'Total Volume',
        ROW_NUMBER() OVER (ORDER BY total_volume DESC),
        name,
        symbol,
        ROUND(total_volume, 2),
        'USD'
    FROM coin_total_volume

    UNION ALL

    SELECT
        'ROI %',
        ROW_NUMBER() OVER (ORDER BY roi_pct DESC),
        name,
        symbol,
        roi_pct,
        '%'
    FROM coin_roi

    UNION ALL

    SELECT
        'Avg Volatility %',
        ROW_NUMBER() OVER (ORDER BY avg_vol_pct DESC),
        name,
        symbol,
        avg_vol_pct,
        '%'
    FROM coin_volatility
)

-- ── Final: Top 10 per category ──────────────────────────────
SELECT
    rank_category,
    rank_num,
    name,
    symbol,
    metric_value,
    unit
FROM ranked
WHERE rank_num <= 10
ORDER BY rank_category, rank_num;

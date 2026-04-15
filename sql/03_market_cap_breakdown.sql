-- ============================================================
-- FILE    : 03_market_cap_breakdown.sql
-- PURPOSE : Coin dominance and market cap composition analysis.
--           Reproduces the donut chart (Page 1), market cap bar
--           chart, and market cap rank visible in the dashboard.
-- COLUMNS : name, symbol, date, marketcap
-- OUTPUT  : One row per coin showing latest market cap, dominance
--           % (share of total market), market cap rank, full-period
--           market cap growth %, and running cumulative share.
-- SQL TECHNIQUE: RANK() window function, CROSS JOIN for totals,
--               CTEs, running SUM with SUM() OVER
-- NOTES   :
--   ✅  Coin dominance % matches the Power BI donut chart.
--       At the latest date (Jul 2021) Bitcoin ~44%, Ethereum ~18%
--       are expected (market conditions at dataset end).
--   ✅  mcap_rank matches DAX RANKX(ALL(Symbol), [Latest Market Cap]).
--   ⚠️  Dashboard Key Insights says "Bitcoin 0.64T, Ethereum 0.27T" —
--       those are SUM of market cap across ALL dates, not point-in-time.
--       The latest_marketcap column below is the Jul 2021 snapshot.
--       See the cumulative_marketcap column for the all-dates sum.
--   ⚠️  mcap_growth_pct compares each coin's first vs last recorded
--       marketcap row. Early coins (Bitcoin 2013) will show extreme
--       growth because their baseline is near-zero.
-- ============================================================

USE crypto_dashboard;

WITH latest_date AS (
    SELECT MAX(DATE(date)) AS max_date FROM crypto_data
),

-- Snapshot: each coin's market cap at the latest date in the dataset
latest_mcap AS (
    SELECT
        c.name,
        c.symbol,
        c.marketcap AS latest_marketcap
    FROM crypto_data c
    INNER JOIN latest_date d ON DATE(c.date) = d.max_date
),

-- Grand total of all coins' market caps at the latest date
total_mcap AS (
    SELECT SUM(latest_marketcap) AS grand_total FROM latest_mcap
),

-- Each coin's earliest recorded market cap (baseline for growth %)
first_mcap AS (
    SELECT name, marketcap AS first_marketcap
    FROM crypto_data
    WHERE (name, date) IN (
        SELECT name, MIN(date)
        FROM crypto_data
        GROUP BY name
    )
),

-- Cumulative (all-dates) sum of market cap per coin
-- This matches the "0.64T Bitcoin, 0.27T Ethereum" numbers in the README
cumulative_mcap AS (
    SELECT name, SUM(marketcap) AS cumulative_marketcap
    FROM crypto_data
    GROUP BY name
)

SELECT
    lm.name,
    lm.symbol,

    -- ── Latest Snapshot (matches Power BI donut chart) ───────
    ROUND(lm.latest_marketcap, 2)                                AS latest_marketcap,

    -- Dominance % — each coin's share of total market at latest date
    -- Matches DAX [Coin Dominance %] = Latest Market Cap / Total Market Cap All
    ROUND(lm.latest_marketcap / tm.grand_total * 100, 4)         AS dominance_pct,

    -- Rank — matches DAX RANKX(ALL(Symbol), [Latest Market Cap], DESC, DENSE)
    RANK() OVER (ORDER BY lm.latest_marketcap DESC)              AS mcap_rank,

    -- ── Growth (first date → latest date) ────────────────────
    ROUND(fm.first_marketcap, 2)                                 AS first_marketcap,
    ROUND(
        (lm.latest_marketcap - fm.first_marketcap)
        / NULLIF(fm.first_marketcap, 0) * 100,
        2
    )                                                            AS mcap_growth_pct,

    -- ── Cumulative total across all dates ────────────────────
    -- Bitcoin 0.64T, Ethereum 0.27T etc. (matches README Key Insights)
    ROUND(cm.cumulative_marketcap, 2)                            AS cumulative_marketcap_all_dates,

    -- Running total — useful for "top N coins cover X% of market" analysis
    ROUND(
        SUM(lm.latest_marketcap) OVER (
            ORDER BY lm.latest_marketcap DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / tm.grand_total * 100,
        2
    )                                                            AS cumulative_dominance_pct,

    tm.grand_total                                               AS total_market_cap_latest_date

FROM latest_mcap lm
CROSS JOIN total_mcap tm
LEFT JOIN first_mcap fm       ON lm.name = fm.name
LEFT JOIN cumulative_mcap cm  ON lm.name = cm.name
ORDER BY lm.latest_marketcap DESC;

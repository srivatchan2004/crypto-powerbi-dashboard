# 📊 Crypto Market Power BI Dashboard

An interactive multi-page Power BI dashboard analyzing cryptocurrency market trends, price movements, and trading volume from **2013 to 2021**, covering 23 coins including Bitcoin, Ethereum, and more.

---

## 🖼️ Dashboard Preview

### Page 1 – Crypto Market Overview
![Crypto Market Dashboard](images/dash_1.png)

### Page 2 – Crypto Price Analysis
![Crypto Price Analysis](images/dash_2.png)

### Page 3 – Crypto Volume Analysis
![Crypto Volume Analysis](images/dash_3.png)

---

## 📁 Repository Structure

```
crypto-dashboard/
├── README.md
├── crypto_dashboard.pbix       ← Power BI report file
├── data/
│   └── crypto_data.csv         ← Source dataset (37,083 rows, 23 coins)
├── images/
│   ├── dash_1.png              ← Market Overview page
│   ├── dash_2.png              ← Price Analysis page
│   └── dash_3.png              ← Volume Analysis page
└── sql/
    ├── 00_setup.sql            ← DB + table creation, CSV import
    ├── 01_kpi_summary.sql      ← All headline KPI cards
    ├── 02_coin_performance.sql ← Per-coin breakdown
    ├── 03_market_cap_breakdown.sql ← Coin dominance & market share
    ├── 04_top_coins_ranking.sql    ← Top 10 rankings (ROW_NUMBER CTE)
    └── 05_yearly_trends.sql        ← YoY trends (LAG + CASE WHEN CTE)
```

---

## 📌 Dashboard Pages

### 1. Crypto Market Dashboard
- **KPIs:** Current Price, Previous Day Close, Total Market Cap, Total Volume
- **Charts:** Total Market Cap Over Time, Market Share Donut Chart, Market Cap by Coin (bar)
- **Stats:** Number of Coins (23), Avg Volatility %, ROI %
- **Filters:** Date range slider, Coin Name slicer

### 2. Crypto Price Analysis
- **KPIs:** Current Price, All Time High, Distance from ATH %, Weekly & Monthly Price Change %, All Time Low, ROI %
- **Charts:** Close Price with MA7, MA30, MA90 moving averages, Daily Returns bar chart
- **Stats:** Best Day Return % (3.56), Worst Day Return % (-0.73), ROI % (11.94K)
- **Filters:** Date range slider, Coin Name slicer

### 3. Crypto Volume Analysis
- **KPIs:** Total Volume (112.08T), Avg Daily Volume (40.77bn), Max Volume (731.68bn), Volume Change %
- **Charts:** Daily Volume Over Time (area chart), Volume Previous Period (horizontal bar), Closing Volume Daily (scatter), Total Volume over Price (scatter)
- **Filters:** Date range slider, Coin Name slicer

---

## 📂 Dataset

| Field | Description |
|---|---|
| `Name` | Cryptocurrency name (e.g., Bitcoin, Ethereum) |
| `Date` | Trading date |
| `Close` | Closing price (USD) |
| `Volume` | Daily trading volume |
| `Market Cap` | Market capitalization |

- **Date Range:** April 2013 – July 2021
- **Coins Covered:** 23 (Bitcoin, Ethereum, Tether, Binance Coin, Cardano, XRP, Dogecoin, and more)
- **Source:** Public cryptocurrency market data

---

## 🗄️ SQL Queries

The `sql/` folder contains MySQL scripts that reproduce every dashboard metric in plain SQL — making the analysis logic transparent and portfolio-ready.

| File | Description | SQL Techniques |
|------|-------------|----------------|
| [`00_setup.sql`](sql/00_setup.sql) | Create database & table, load CSV via `LOAD DATA LOCAL INFILE`, sanity-check counts | `CREATE TABLE`, `LOAD DATA`, `STR_TO_DATE`, `UNION ALL` |
| [`01_kpi_summary.sql`](sql/01_kpi_summary.sql) | All headline KPIs from the three dashboard pages (price, volume, market cap, volatility, ROI) | `SUM`, `AVG`, `MAX`, subqueries, `COALESCE`, `NULLIF` |
| [`02_coin_performance.sql`](sql/02_coin_performance.sql) | Per-coin breakdown: current price, ATH/ATL, total volume, market cap, volatility, ROI, bull/bear days | `FIRST_VALUE() OVER`, `PARTITION BY`, `CASE WHEN`, `LEFT JOIN` |
| [`03_market_cap_breakdown.sql`](sql/03_market_cap_breakdown.sql) | Coin dominance %, market cap rank, growth % first→last date, running cumulative share | `RANK() OVER`, `CROSS JOIN`, running `SUM() OVER`, CTEs |
| [`04_top_coins_ranking.sql`](sql/04_top_coins_ranking.sql) | Top 10 coins ranked by market cap, total volume, ROI %, and avg volatility | `ROW_NUMBER() OVER`, four CTEs, `UNION ALL` |
| [`05_yearly_trends.sql`](sql/05_yearly_trends.sql) | Year-over-year summary (2013–2021): volume, market cap, price, YoY growth %, bull/bear label; plus a per-coin volume pivot | `LAG() OVER`, `CASE WHEN` pivot, `YEAR()`, CTEs |

### Setting up in MySQL Workbench

1. Open MySQL Workbench and connect to your local server.
2. Enable local file loading: **Edit → Preferences → SQL Editor** → check **"Allow Loading Local Infile"** → reconnect.
3. Open `sql/00_setup.sql`, update the file path in the `LOAD DATA LOCAL INFILE` line to the absolute path of `data/CryptoData1.csv` on your machine (use forward slashes).
4. Run `00_setup.sql` — verify the sanity check shows **37,083 rows** and **23 distinct coins**.
5. Run any of `01_` through `05_` in MySQL Workbench or via the CLI:
   ```bash
   mysql -u root -p crypto_dashboard < sql/01_kpi_summary.sql
   ```

---

## 🛠️ Tools Used

| Tool | Purpose |
|---|---|
| Power BI Desktop | Dashboard creation & DAX measures |
| MySQL | SQL query development & KPI verification |
| CSV | Data source |
| DAX | KPI calculations (ATH, ROI, Moving Averages, Volatility) |

---

## 🔑 Key Insights

- **Bitcoin dominates** market cap at 0.64T, followed by Ethereum at 0.27T
- **2021 bull run** saw the highest total market cap ever (~2T) and peak daily volumes exceeding 0.8T
- **ROI of 7.81K%** across the full period reflects crypto's exponential growth
- **Average volatility** across all coins stands at 0.08%
- **All Time High** for the tracked period was $63.50K

---

## 🚀 How to Use

1. Clone or download this repository
2. Open `crypto_dashboard.pbix` in **Power BI Desktop**
3. Use the **Name** slicer to filter by individual cryptocurrency
4. Adjust the **Date** range slider to explore specific time periods
5. Navigate between pages using the **"next pg →"** button in the dashboard

---

## 🛠️ Skills Demonstrated

![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat&logo=mysql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![DAX](https://img.shields.io/badge/DAX-F2C811?style=flat&logo=powerbi&logoColor=black)
![Data Analytics](https://img.shields.io/badge/Data%20Analytics-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Excel](https://img.shields.io/badge/Excel-217346?style=flat&logo=microsoftexcel&logoColor=white)

| Skill | Applied In This Project |
|-------|------------------------|
| **Power BI** | Multi-page interactive dashboard, slicers, KPI cards, custom visuals |
| **DAX** | 25+ measures — ATH, ROI, CAGR, moving averages, volatility, RANKX |
| **MySQL** | 6 query files — window functions, CTEs, YoY analysis, LOAD DATA |
| **Data Modelling** | Star schema, date table, calculated columns, measure table |
| **SQL Window Functions** | `ROW_NUMBER()`, `RANK()`, `LAG()`, `FIRST_VALUE()`, `PARTITION BY` |
| **Data Cleaning** | Date format parsing (`STR_TO_DATE`), null handling, type casting |
| **Python** | Data exploration and preprocessing of CSV source data |

---

## 📬 Contact

Feel free to connect or raise an issue if you have feedback or questions!

[![Portfolio](https://img.shields.io/badge/Portfolio-srivatchan2004.github.io-0A66C2?style=flat&logo=github&logoColor=white)](https://srivatchan2004.github.io)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Srivatchan-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/srivatchan2004/)

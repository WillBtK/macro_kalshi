"""
series_config.py

Single source of truth mapping each economic series to its Kalshi series ticker,
the CSV filenames the R conversion reads/writes, and the FRED series for the
realised underlying variable. Shared by the incremental scraper, the derived-data
loader, and the FRED collector.
"""

# key:      internal/series name used in the database and the front-end
# ticker:   Kalshi series ticker passed to autogenerate_kalshi_tickers()
# trades:   raw trade CSV the R conversion reads (data/trade_level_data/<trades>)
# moments:  derived moments CSV the R conversion writes (data/daily_moments_data/<moments>)
# dist:     derived long-format distribution CSV (data/daily_distribution_data/<dist>)
# fred:     {id, units} for the realised series on FRED (units: lin=level,
#           pc1=% change from year ago, pch=% change from prior period)
SERIES = [
    # Kalshi KXFED resolves to the FOMC target *range*; a strike is the range's
    # lower bound and the reported moments are the range midpoint. The realized
    # comparison is therefore the target-range midpoint = (upper + lower) / 2.
    dict(key="fed_levels", ticker="KXFED",
         trades="trade_level_data_fed_levels.csv",
         moments="daily_moments_fed_levels.csv",
         dist="daily_distributions_fed_levels.csv",
         fred=dict(id="DFEDTARU", id2="DFEDTARL", units="lin")),
    dict(key="headline_cpi_releases", ticker="KXCPIYOY",
         trades="trade_level_data_headline_cpi_releases.csv",
         moments="daily_moments_headline_cpi_releases.csv",
         dist="daily_distributions_headline_cpi_releases.csv",
         fred=dict(id="CPIAUCSL", units="pc1")),
    dict(key="core_cpi_releases", ticker="KXCPICOREYOY",
         trades="trade_level_data_core_cpi_releases.csv",
         moments="daily_moments_core_cpi_releases.csv",
         dist="daily_distributions_core_cpi_releases.csv",
         fred=dict(id="CPILFESL", units="pc1")),
    dict(key="headline_cpi_releases_mom", ticker="KXCPI",
         trades="trade_level_data_headline_cpi_releases_mom.csv",
         moments="daily_moments_headline_cpi_releases_mom.csv",
         dist="daily_distributions_headline_cpi_releases_mom.csv",
         fred=dict(id="CPIAUCSL", units="pch")),
    dict(key="headline_cpi_end_of_year", ticker="KXACPI",
         trades="trade_level_data_headline_cpi_end_of_year.csv",
         moments="daily_moments_headline_cpi_end_of_year.csv",
         dist="daily_distributions_headline_cpi_end_of_year.csv",
         fred=dict(id="CPIAUCSL", units="pc1")),
    # KXGDPYEAR resolves to the BEA advance estimate of annual real GDP growth
    # for the year (annual-average basis: prior-year annual level to current-year
    # annual level), NOT Q4/Q4. Realized = FRED annual real GDP % change.
    dict(key="gdp_end_of_year", ticker="KXGDPYEAR",
         trades="trade_level_data_gdp_end_of_year.csv",
         moments="daily_moments_gdp_end_of_year.csv",
         dist="daily_distributions_gdp_end_of_year.csv",
         fred=dict(id="A191RL1A225NBEA", units="lin")),
    dict(key="unemployment_releases", ticker="KXU3",
         trades="trade_level_data_unemployment.csv",
         moments="daily_moments_unemployment_releases.csv",
         dist="daily_distributions_unemployment_releases.csv",
         fred=dict(id="UNRATE", units="lin")),
    # Quarterly real GDP growth, seasonally-adjusted annualised q/q (KXGDP).
    # Realized = FRED quarterly real GDP % change (SAAR).
    dict(key="gdp_quarterly", ticker="KXGDP",
         trades="trade_level_data_gdp_quarterly.csv",
         moments="daily_moments_gdp_quarterly.csv",
         dist="daily_distributions_gdp_quarterly.csv",
         fred=dict(id="A191RL1Q225SBEA", units="lin")),
    # Nonfarm payrolls, monthly change in jobs (KXPAYROLLS).
    # Realized = FRED total nonfarm payrolls, change from prior month (thousands).
    dict(key="nonfarm_payrolls", ticker="KXPAYROLLS",
         trades="trade_level_data_nonfarm_payrolls.csv",
         moments="daily_moments_nonfarm_payrolls.csv",
         dist="daily_distributions_nonfarm_payrolls.csv",
         fred=dict(id="PAYEMS", units="chg")),
]

TRADES_DIR = "data/trade_level_data"
MOMENTS_DIR = "data/daily_moments_data"
DIST_DIR = "data/daily_distribution_data"

# ---- Quote-based (bid/ask) distribution ----------------------------------
# A parallel distribution derived from Kalshi's daily candlestick bid/ask
# midpoint across strikes (the order book), rather than executed trades. It
# reflects the live cross-strike price structure even on days/strikes with no
# trades. Covers the CDF threshold markets; the order-book converter now applies
# per-series strike_scale, so nonfarm payrolls is included (strikes scaled to
# thousands). The annual bracket markets (PDF path) remain excluded.
QUOTE_SERIES = [
    "fed_levels",
    "headline_cpi_releases",
    "core_cpi_releases",
    "headline_cpi_releases_mom",
    "unemployment_releases",
    "gdp_quarterly",
    "nonfarm_payrolls",
]
ORDERBOOK_DIR = "data/orderbook_data"                 # raw candlestick CSVs (per series)
BA_MOMENTS_DIR = "data/daily_bid_ask_moments_data"    # quote-derived moments
BA_DIST_DIR = "data/daily_bid_ask_distribution_data"  # quote-derived distributions

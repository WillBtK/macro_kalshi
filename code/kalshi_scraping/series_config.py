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
    dict(key="fed_levels", ticker="KXFED",
         trades="trade_level_data_fed_levels.csv",
         moments="daily_moments_fed_levels.csv",
         dist="daily_distributions_fed_levels.csv",
         fred=dict(id="DFEDTARU", units="lin")),
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
    dict(key="gdp_end_of_year", ticker="KXGDPYEAR",
         trades="trade_level_data_gdp_end_of_year.csv",
         moments="daily_moments_gdp_end_of_year.csv",
         dist="daily_distributions_gdp_end_of_year.csv",
         fred=dict(id="A191RL1Q225SBEA", units="lin")),
    dict(key="unemployment_releases", ticker="KXU3",
         trades="trade_level_data_unemployment.csv",
         moments="daily_moments_unemployment_releases.csv",
         dist="daily_distributions_unemployment_releases.csv",
         fred=dict(id="UNRATE", units="lin")),
]

TRADES_DIR = "data/trade_level_data"
MOMENTS_DIR = "data/daily_moments_data"
DIST_DIR = "data/daily_distribution_data"

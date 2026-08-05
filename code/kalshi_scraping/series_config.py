"""
series_config.py

Single source of truth mapping each economic series to its Kalshi series ticker
and the CSV filenames the R conversion reads (inputs) and writes (derived
outputs). Shared by the incremental scraper and the derived-data loader.
"""

# key:      internal/series name used in the database and the front-end
# ticker:   Kalshi series ticker passed to autogenerate_kalshi_tickers()
# trades:   raw trade CSV the R conversion reads (data/trade_level_data/<trades>)
# moments:  derived moments CSV the R conversion writes (data/daily_moments_data/<moments>)
# dist:     derived long-format distribution CSV (data/daily_distribution_data/<dist>)
SERIES = [
    dict(key="fed_levels", ticker="KXFED",
         trades="trade_level_data_fed_levels.csv",
         moments="daily_moments_fed_levels.csv",
         dist="daily_distributions_fed_levels.csv"),
    dict(key="headline_cpi_releases", ticker="KXCPIYOY",
         trades="trade_level_data_headline_cpi_releases.csv",
         moments="daily_moments_headline_cpi_releases.csv",
         dist="daily_distributions_headline_cpi_releases.csv"),
    dict(key="core_cpi_releases", ticker="KXCPICOREYOY",
         trades="trade_level_data_core_cpi_releases.csv",
         moments="daily_moments_core_cpi_releases.csv",
         dist="daily_distributions_core_cpi_releases.csv"),
    dict(key="headline_cpi_releases_mom", ticker="KXCPI",
         trades="trade_level_data_headline_cpi_releases_mom.csv",
         moments="daily_moments_headline_cpi_releases_mom.csv",
         dist="daily_distributions_headline_cpi_releases_mom.csv"),
    dict(key="headline_cpi_end_of_year", ticker="KXACPI",
         trades="trade_level_data_headline_cpi_end_of_year.csv",
         moments="daily_moments_headline_cpi_end_of_year.csv",
         dist="daily_distributions_headline_cpi_end_of_year.csv"),
    dict(key="gdp_end_of_year", ticker="KXGDPYEAR",
         trades="trade_level_data_gdp_end_of_year.csv",
         moments="daily_moments_gdp_end_of_year.csv",
         dist="daily_distributions_gdp_end_of_year.csv"),
    dict(key="unemployment_releases", ticker="KXU3",
         trades="trade_level_data_unemployment.csv",
         moments="daily_moments_unemployment_releases.csv",
         dist="daily_distributions_unemployment_releases.csv"),
]

TRADES_DIR = "data/trade_level_data"
MOMENTS_DIR = "data/daily_moments_data"
DIST_DIR = "data/daily_distribution_data"

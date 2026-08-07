# orderbook_convert_runner.R
#
# Quote-based counterpart to data_convert_runner.R. Converts each series'
# order-book candlestick CSV (data/orderbook_data/orderbook_<key>.csv, written by
# scrape_orderbook.py) into daily distributions + moments using the SAME
# middle-out CDF methodology as the trade path, but reading the bid/ask MIDPOINT
# (convert_bid_ask_data_cdfs.R) instead of the last trade. Outputs go to the
# daily_bid_ask_* dirs; load_derived_quotes.py loads them into the *_quotes
# tables. Per-series params mirror the trade runner. Each series is wrapped so
# one failure can't stop the rest.

source("code/convert_trades_to_pdfs/convert_bid_ask_data_cdfs.R")

# Keep all contracts: the bid/ask converter's default end_date is a stale 2025
# cutoff that would drop current/recent contracts.
KEEP_ALL <- as.Date("2100-01-01")

run_one <- function(key, strike_int, horizon, madj) {
  tryCatch(
    extract_distributions(
      input_file           = paste0("data/orderbook_data/orderbook_", key, ".csv"),
      output_distributions = paste0("data/daily_bid_ask_distribution_data/daily_distributions_", key, ".csv"),
      output_moments       = paste0("data/daily_bid_ask_moments_data/daily_moments_", key, ".csv"),
      strike_int           = strike_int,
      days_before_horizon  = horizon,
      end_date             = KEEP_ALL,
      moment_adjustment    = madj),
    error = function(e) message("quote conversion failed for ", key, ": ", conditionMessage(e)))
}

# key                         strike_int  horizon  moment_adjustment  (match the trade runner)
run_one("fed_levels",                0.25,   180,   0.125)
run_one("headline_cpi_releases",     0.1,    30,    0.1)
run_one("core_cpi_releases",         0.1,    30,    0.1)
run_one("headline_cpi_releases_mom", 0.1,    30,    0.1)
run_one("unemployment_releases",     0.1,    30,    0.1)
run_one("gdp_quarterly",             0.5,    400,   0.25)

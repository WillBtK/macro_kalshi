# This file is a driver to convert all of our trade level and orderbook data to 
# moments and probability distribution data


############ Trade-level Data ############
source("code/convert_trades_to_pdfs/convert_trade_level_data_cdfs.R")


# FFR levels
extract_distributions(input_file = 'data/trade_level_data/trade_level_data_fed_levels.csv',
                      output_distributions = 'data/daily_distribution_data/daily_distributions_fed_levels.csv',
                      output_moments = 'data/daily_moments_data/daily_moments_fed_levels.csv',
                      output_wide = 'data/daily_distribution_data/wide/daily_distributions_fed_levels.csv',
                      strike_int = 0.25,
                      days_before_horizon = 180,
                      moment_adjustment = .125)


# CPI YoY headline
extract_distributions(input_file = 'data/trade_level_data/trade_level_data_headline_cpi_releases.csv',
                      output_distributions = 'data/daily_distribution_data/daily_distributions_headline_cpi_releases.csv',
                      output_moments = 'data/daily_moments_data/daily_moments_headline_cpi_releases.csv',
                      output_wide = 'data/daily_distribution_data/wide/daily_distributions_headline_cpi_releases.csv',
                      strike_int = 0.1,
                      days_before_horizon = 30,
                      moment_adjustment = .1)

# CPI YoY core
extract_distributions(input_file = 'data/trade_level_data/trade_level_data_core_cpi_releases.csv',
                      output_distributions = 'data/daily_distribution_data/daily_distributions_core_cpi_releases.csv',
                      output_moments = 'data/daily_moments_data/daily_moments_core_cpi_releases.csv',
                      output_wide = 'data/daily_distribution_data/wide/daily_distributions_core_cpi_releases.csv',
                      strike_int = 0.1,
                      days_before_horizon = 30,
                      moment_adjustment = .1)

# CPI MoM headline
extract_distributions(input_file = 'data/trade_level_data/trade_level_data_headline_cpi_releases_mom.csv',
                      output_distributions = 'data/daily_distribution_data/daily_distributions_headline_cpi_releases_mom.csv',
                      output_moments = 'data/daily_moments_data/daily_moments_headline_cpi_releases_mom.csv',
                      output_wide = 'data/daily_distribution_data/wide/daily_distributions_headline_cpi_releases_mom.csv',
                      strike_int = 0.1,
                      days_before_horizon = 30,
                      moment_adjustment = .1)

# Unemployment
extract_distributions(input_file = 'data/trade_level_data/trade_level_data_unemployment.csv',
                      output_distributions = 'data/daily_distribution_data/daily_distributions_unemployment_releases.csv',
                      output_moments = 'data/daily_moments_data/daily_moments_unemployment_releases.csv',
                      output_wide = 'data/daily_distribution_data/wide/daily_distributions_unemployment_releases.csv',
                      strike_int = 0.1,
                      days_before_horizon = 30,
                      moment_adjustment = .1)

# Nonfarm payrolls (KXPAYROLLS): threshold market, strikes listed in absolute
# jobs (e.g. -T150000). strike_scale = 0.001 puts moments in THOUSANDS of jobs
# so they line up with the FRED realised change (PAYEMS chg, also thousands).
# Wrapped so a new-series hiccup never kills the established series' conversion.
tryCatch(
  extract_distributions(input_file = 'data/trade_level_data/trade_level_data_nonfarm_payrolls.csv',
                        output_distributions = 'data/daily_distribution_data/daily_distributions_nonfarm_payrolls.csv',
                        output_moments = 'data/daily_moments_data/daily_moments_nonfarm_payrolls.csv',
                        output_wide = 'data/daily_distribution_data/wide/daily_distributions_nonfarm_payrolls.csv',
                        strike_int = 50,
                        days_before_horizon = 45,
                        moment_adjustment = 25,
                        strike_scale = 0.001),
  error = function(e) message("nonfarm_payrolls conversion failed: ", conditionMessage(e)))

# Quarterly real GDP (KXGDP): threshold market on the quarter's SAAR q/q growth
# (KXGDP-YYMONDD-T<pct>), so the CDF converter with a 0.5-pp strike grid. Values
# are already in percent, so no strike scaling. days_before_horizon kept wide so
# far-dated quarters retain enough history for the horizon / constant-maturity
# views. Wrapped so a hiccup never breaks the established series.
tryCatch(
  extract_distributions(input_file = 'data/trade_level_data/trade_level_data_gdp_quarterly.csv',
                        output_distributions = 'data/daily_distribution_data/daily_distributions_gdp_quarterly.csv',
                        output_moments = 'data/daily_moments_data/daily_moments_gdp_quarterly.csv',
                        output_wide = 'data/daily_distribution_data/wide/daily_distributions_gdp_quarterly.csv',
                        strike_int = 0.5,
                        days_before_horizon = 400,
                        moment_adjustment = 0.25),
  error = function(e) message("gdp_quarterly conversion failed: ", conditionMessage(e)))



############ Trade-level Data-- Annual ############
source("code/convert_trades_to_pdfs/convert_trade_level_data_pdfs.R")


# CPI end of year
extract_distributions(
  input_file = "data/trade_level_data/trade_level_data_headline_cpi_end_of_year.csv",
  output_distributions = "data/daily_distribution_data/daily_distributions_headline_cpi_end_of_year.csv",
  output_moments = "data/daily_moments_data/daily_moments_headline_cpi_end_of_year.csv",
  output_wide = "data/daily_distribution_data/wide/daily_distributions_headline_cpi_end_of_year.csv"
  
)

# GDP end of year
extract_distributions(
  input_file = "data/trade_level_data/trade_level_data_gdp_end_of_year.csv",
  output_distributions = "data/daily_distribution_data/daily_distributions_gdp_end_of_year.csv",
  output_moments = "data/daily_moments_data/daily_moments_gdp_end_of_year.csv",
  output_wide = "data/daily_distribution_data/wide/daily_distributions_gdp_end_of_year.csv"
)



############ Order-book Data ############
source("code/convert_trades_to_pdfs/convert_bid_ask_data_cdfs.R")

# FFR levels
# extract_distributions(input_file = 'data/orderbook_data/daily_bid_ask_fed_decisions_data.csv',
#                       output_distributions = 'data/daily_bid_ask_distribution_data/daily_distributions_fed_levels.csv',
#                       output_moments = 'data/daily_bid_ask_moments_data/daily_moments_fed_levels.csv',
#                       strike_int = 0.25,
#                       days_before_horizon = 180,
#                       moment_adjustment = .125)
# 
# # CPI YoY Headline
# extract_distributions(input_file = 'data/orderbook_data/daily_bid_ask_cpi_data.csv',
#                       output_distributions = 'data/daily_bid_ask_distribution_data/daily_distributions_headline_cpi_releases.csv',
#                       output_moments = 'data/daily_bid_ask_moments_data/daily_moments_headline_cpi_releases.csv',
#                       strike_int = 0.1,
#                       days_before_horizon = 30,
#                       moment_adjustment = .1)
# 
# # Unemployment
# extract_distributions(input_file = 'data/orderbook_data/daily_bid_ask_unemployment_data.csv',
#                       output_distributions = 'data/daily_bid_ask_distribution_data/daily_distributions_unemployment_releases.csv',
#                       output_moments = 'data/daily_bid_ask_moments_data/daily_moments_unemployment_releases.csv',
#                       strike_int = 0.1,
#                       days_before_horizon = 30,
#                       moment_adjustment = .1)
# 
# 
# 
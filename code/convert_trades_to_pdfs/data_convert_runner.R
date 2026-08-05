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
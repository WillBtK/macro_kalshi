# detecting_insider_trading.R
# 
# Author: Anthony M. Diercks, Jared Dean Katz
# Affiliation: Federal Reserve Board of Governors, Northwestern University Kellogg School of Businesss
# Contact: jared.katz@kellogg.northwestern.edu
# Date: July 2025
# 
# Description:
# -------------
# This script uses the Kalshi API to download and archive all contracts where
# there are increasing strikes.
# It is designed for researchers to be able to obtain current
# prediction market data.
# 
# 
# Usage:
# ------
# 
# Dependencies:
# -------------
# - R version 4.3.0
# - Kalshi API
# 
# 
# License & Citation:
# --------------------
# This script is distributed under the MIT License (see LICENSE file).
# If you use this script or data collected with it in published work,
# please cite:
#     
# Diercks, Katz, Wright (2026) 
# 
# with use.
# 
# Disclaimer:
# -----------
# This is academic software provided 'as is', without warranty of any kind.
# Use at your own risk and verify data with official sources where appropriate.
# 
# Reproducibility:
# ----------------
# 
# Run on Macbook M1 in R Studio environment using R version 4.3.0

##################################
##     Package Installation     ##
##################################

library(tidyverse)
library(lubridate)
library(matrixStats)
library(collapse)

# First, load intraday kalshi moments and bloomberg revealed cpi and merge
load_cpi_data <- function() {
  
  kalshi_data <- read_csv('data/hourly_moments_data/hourly_moments_headline_cpi_releases.csv')
  
  kalshi_data <- kalshi_data %>% filter(datetime_6h_utc <= as.Date('2025-07-01') & datetime_6h_utc > as.Date('2022-01-01'))
  
  
  actual_release_data <- read_csv('data/external_data/bb_cpi_surprises.csv')
  colnames(actual_release_data) = c('horizon_date', 'contract_preamble', 'realized_cpi', 'bb_survey_median_cpi')
  
  merged_data <- kalshi_data %>% left_join(actual_release_data)  
  
  merged_data <- merged_data %>% mutate(kalshi_mean_error = mean - realized_cpi,
                                        kalshi_median_error = median - realized_cpi,
                                        kalshi_mode_error = mode - realized_cpi)
  
  merged_data <- merged_data %>%
    group_by(contract_preamble) %>%
    arrange(datetime_6h_utc) %>%
    mutate(
      final_mean = last(mean),
      final_median = last(median),
      final_mode = last(mode),
      final_mean_error = last(kalshi_mean_error),
      final_median_error = last(kalshi_median_error),
      final_mode_error = last(kalshi_mode_error),
      mean_distance_from_final = mean - final_mean,
      median_distance_from_final = median - final_median,
      mode_distance_from_final = mode - final_mode
    ) %>%
    ungroup()
  
  return(merged_data)
}

# Next, load intraday kalshi moments and bloomberg revealed unemployment and merge
load_unemployment_data <- function() {
  
  kalshi_data <- read_csv('data/hourly_moments_data/hourly_moments_unemployment_releases.csv')
  
  kalshi_data <- kalshi_data %>% filter(datetime_6h_utc <= as.Date('2025-07-01') & datetime_6h_utc > as.Date('2022-01-01'))
  
  
  actual_release_data <- read_csv('data/external_data/bb_unemployment_surprises.csv')

  merged_data <- kalshi_data %>% left_join(actual_release_data)  
  
  merged_data <- merged_data %>% mutate(kalshi_mean_error = mean - actual_release,
                                        kalshi_median_error = median - actual_release,
                                        kalshi_mode_error = mode - actual_release)
  
  merged_data <- merged_data %>%
    group_by(contract_preamble) %>%
    arrange(datetime_6h_utc) %>%
    mutate(
      final_mean = last(mean),
      final_median = last(median),
      final_mode = last(mode),
      final_mean_error = last(kalshi_mean_error),
      final_median_error = last(kalshi_median_error),
      final_mode_error = last(kalshi_mode_error),
      mean_distance_from_final = mean - final_mean,
      median_distance_from_final = median - final_median,
      mode_distance_from_final = mode - final_mode
    ) %>%
    ungroup()
  
  return(merged_data)
}

cpi_data <- load_cpi_data()
unemployment_data <- load_unemployment_data()


# Filter 1: Observations exactly 6 hours before expiry
cpi_6h_before <- cpi_data %>%
  filter(datetime_6h_utc == expiry_datetime - hours(6))

# Filter 2: Observations exactly 12 hours before expiry
cpi_12h_before <- cpi_data %>%
  filter(datetime_6h_utc == expiry_datetime - hours(12))

# Filter 3: Observations exactly 24 hours before expiry
cpi_24h_before <- cpi_data %>%
  filter(datetime_6h_utc == expiry_datetime - hours(24))


# Filter 1: Observations exactly 6 hours before expiry
unemp_6h_before <- unemployment_data %>%
  filter(datetime_6h_utc == expiry_datetime - hours(6))

# Filter 2: Observations exactly 12 hours before expiry
unemp_12h_before <- unemployment_data %>%
  filter(datetime_6h_utc == expiry_datetime - hours(12))

# Filter 3: Observations exactly 24 hours before expiry
unemp_24h_before <- unemployment_data %>%
  filter(datetime_6h_utc == expiry_datetime - hours(24))

library(xtable)

# Create a function to calculate probabilities for any dataset
calc_probs <- function(data, dataset_name, hours_before) {
  data %>%
    summarise(
      prob_pos_error_given_pos_distance = mean(final_mean_error > 0 & mean_distance_from_final > 0) / 
        mean(mean_distance_from_final > 0),
      prob_pos_error_given_neg_distance = mean(final_mean_error > 0 & mean_distance_from_final < 0) / 
        mean(mean_distance_from_final < 0),
      prob_pos_error_overall = mean(final_mean_error > 0)
    ) %>%
    mutate(
      dataset = dataset_name,
      hours_before = hours_before,
      .before = 1
    )
}

# Combine all results into one table
probability_table <- bind_rows(
  calc_probs(cpi_6h_before, "CPI", 6),
  calc_probs(cpi_12h_before, "CPI", 12),
  calc_probs(cpi_24h_before, "CPI", 24),
  calc_probs(unemp_6h_before, "Unemployment", 6),
  calc_probs(unemp_12h_before, "Unemployment", 12),
  calc_probs(unemp_24h_before, "Unemployment", 24)
)

# Round the probabilities and replace NaN/Inf with NA
probability_table <- probability_table %>%
  mutate(across(where(is.numeric), ~round(., 3))) %>%
  mutate(across(where(is.numeric), ~ifelse(is.nan(.) | is.infinite(.), NA, .)))

# Rename columns to be LaTeX-friendly
colnames(probability_table) <- c("Dataset", "Hours Before", 
                                 "P(Error>0 | Distance>0)", 
                                 "P(Error>0 | Distance<0)", 
                                 "P(Error>0)")

# Generate LaTeX table
latex_table <- xtable(probability_table, 
                      caption = "Conditional Probabilities of Positive Forecast Error",
                      label = "tab:conditional_probs",
                      align = c("l", "l", "r", "r", "r", "r"),
                      digits = 3)

# Print LaTeX code
print(latex_table, 
      include.rownames = FALSE,
      caption.placement = "top",
      NA.string = "--")
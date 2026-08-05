# insider_trading_dist_construction.R
# 
# Author: Anthony M. Diercks, Jared Dean Katz
# Affiliation: Federal Reserve Board of Governors, Northwestern University Kellogg School of Businesss
# Contact: jared.katz@kellogg.northwestern.edu
# Date: July 2025
# 
# Description:
# -------------
# This script uses the Kalshi API to download and archive all contracts where
# there are increasing strikes, at an INTRADAY level.
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


#' Read and process trade-level data from CSV file
#'
#' @param input_file Path to the CSV file to be read.
#' @return A data frame with parsed datetime, extracted contract preamble, strike price, and sorted data.
read_data <- function(input_file) {
  
  df <- read_csv(input_file)
  
  # Convert datetime and create 6-hour intervals in UTC
  df <- df %>%
    mutate(
      created_time_utc = as.POSIXct(created_time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"),
      
      # Create 6-hour intervals aligned to midnight UTC (00:00, 06:00, 12:00, 18:00)
      datetime_6h_utc = floor_date(created_time_utc, "6 hours"),
      
      # Create Eastern time versions for display
      created_time_et = format(with_tz(created_time_utc, "America/New_York"), "%Y-%m-%d %H:%M:%S %Z"),
      datetime_6h_et = format(with_tz(datetime_6h_utc, "America/New_York"), "%Y-%m-%d %H:%M:%S %Z"),
      
      # Keep date for compatibility with days_before_horizon filtering
      date = as.Date(datetime_6h_utc)
    )
  
  # Extract contract_preamble (e.g., FED-22DEC) and strike price
  df <- df %>%
    mutate(
      contract_preamble = str_extract(ticker, "^[^-]+(?:-[^-]+)*"),
      contract_preamble = str_replace(contract_preamble, "-T\\d+\\.?\\d*$", ""),
      contract_preamble = ifelse(contract_preamble == 'FED-22JULY', 'FED-22JUL', contract_preamble),
      strike = as.numeric(str_extract(ticker, "(?<=-T)\\d+\\.?\\d*"))
    ) %>%
    arrange(contract_preamble, strike, date)
  
  return(df)
}


#' Convert trade-level Kalshi data to 6-hourly summary
#'
#' Takes the last trade of each day as the daily value, and aggregates volume.
#'
#' @param df A data frame containing trade-level options data with columns: date, contract_preamble, strike, yes_price, count (volume)
#' @return A data frame with daily last prices and total volume per contract and strike.
convert_to_6hourly <- function(df, method = 'last') {
  if (method == 'last') {
    df %>%
      group_by(datetime_6h_utc, datetime_6h_et, contract_preamble, strike) %>%
      arrange(created_time_utc, .by_group = TRUE) %>%
      summarise(
        yes_price = dplyr::last(yes_price),
        interval_volume = sum(count),
        date = first(date),  # Keep date for filtering
        .groups = "drop"
      ) %>%
      arrange(contract_preamble, strike, datetime_6h_utc)
  } else if (method == 'average') {
    df %>%
      group_by(datetime_6h_utc, datetime_6h_et, contract_preamble, strike) %>%
      arrange(created_time_utc, .by_group = TRUE) %>%
      summarise(
        yes_price = weighted.mean(yes_price, count),
        interval_volume = sum(count),
        date = first(date),
        .groups = "drop"
      ) %>%
      arrange(contract_preamble, strike, datetime_6h_utc)
  }
}

#' Fill missing 6-hour intervals with last known price (from a previous interval)
#'
#' Ensures each valid contract_preamble and strike pair has data for every 6-hour interval in the full range.
#' Fills forward the last known price, sets interval volume to 0 on filled intervals,
#' and trims data outside the active contract period.
#'
#' @param df A data frame with columns: datetime_6h_utc, contract_preamble, strike, yes_price, interval_volume.
#' @param days_before_horizon Number of days before expiry to include data for
#' @return A data frame with missing intervals filled and cleaned.
fill_dataless_intervals <- function(df, days_before_horizon) {
  
  # Get unique strike-preamble combinations that actually exist
  valid_combos <- df %>% select(contract_preamble, strike) %>% distinct()
  
  # Get full 6-hour interval range, properly aligned
  start_time <- floor_date(min(df$datetime_6h_utc), "6 hours")
  end_time <- ceiling_date(max(df$datetime_6h_utc), "6 hours")
  intervals <- seq(start_time, end_time, by = "6 hours")
  
  # Create full interval range for only valid strike-preamble combos
  full_interval_range <- valid_combos %>%
    crossing(datetime_6h_utc = intervals) %>%
    mutate(
      datetime_6h_et = format(with_tz(datetime_6h_utc, "America/New_York"), "%Y-%m-%d %H:%M:%S %Z"),
      date = as.Date(datetime_6h_utc)
    )
  
  # Merge with current df
  df <- df %>% 
    full_join(full_interval_range, by = c("datetime_6h_utc", "datetime_6h_et", "contract_preamble", "strike", "date")) %>% 
    arrange(contract_preamble, strike, datetime_6h_utc)
  
  # Get the contract expiry datetime (use the last interval with data)
  df <- df %>%
    group_by(contract_preamble) %>%
    mutate(
      expiry_datetime = if (all(is.na(yes_price))) as.POSIXct(NA) else max(datetime_6h_utc[!is.na(yes_price)])
    ) %>%
    ungroup()
  
  # Get rid of stale prices that took place before the forecast period we care about
  df <- df %>% 
    filter(datetime_6h_utc >= expiry_datetime - days(days_before_horizon) - days(10))
  
  # Fill NA rows with last price and fill in 0 for interval volume on these intervals
  df <- df %>%
    group_by(contract_preamble, strike) %>%
    fill(yes_price, .direction = "down") %>%
    ungroup() %>% 
    mutate(
      interval_volume = ifelse(is.na(interval_volume), 0, interval_volume)
    )
  
  # Remove the rows at the start with no price, rows after the expiry datetime, and
  # rows for bins that never existed
  df <- df %>% 
    na.omit() %>%
    filter(
      datetime_6h_utc <= expiry_datetime
    )
  
  return(df)
}

#' Middle out algorithm is our preferred method of removing arbitrage violations in Kalshi prices,
#' which can be particularly helpful when there's low or infrequent trades in markets
#'
#' Idea: Choose an event [x, infinity) bin in the distribution which we argue has good liquidity (and thus should
#' have relatively accurate prices). Then, ensure that events that encompass it [x_{i-1}, infinity)
#' are priced higher, and events that are encompassed by it [x_{i+1}, infinity) are priced lower.
#' Repeat this process, creating a distribution that is connected and monotonically increasing.
#'
#' @param target Price level which we target as the center bin (note Kalshi prices 1-99, so the
#' median is 49, not 50)
#' @param df_grp Contract/day level df which we perform the operation on
#' @return A data frame with missing dates filled and cleaned.
adjust_middle_out <- function(df_grp, target = 49) {
  # df_grp is one (contract_preamble, date) group, already arranged by strike
  yes <- df_grp$yes_price
  n   <- length(yes)
  
  
  # --- 1. pick center index k based on triples ---
  k <- which.min(abs(yes - target))
  
  adj <- yes
  
  # --- 2. left side: lower strikes must have higher prices ---
  if (k > 1) {
    left_idx <- 1:(k - 1)
    # from center moving left in strike: [yes[k], yes[k-1], ..., yes[1]]
    seq_left <- c(yes[k], rev(yes[left_idx]))
    # enforce non-decreasing as we move away from center
    cm_left  <- cummax(seq_left)
    # drop center and flip back
    adj[left_idx] <- rev(cm_left[-1])
  }
  
  # --- 3. right side: higher strikes must have lower prices ---
  if (k < n) {
    right_idx <- (k + 1):n
    # from center moving right: [yes[k], yes[k+1], ..., yes[n]]
    seq_right <- c(yes[k], yes[right_idx])
    # enforce non-increasing as we move away from center
    cm_right  <- cummin(seq_right)
    adj[right_idx] <- cm_right[-1]
  }
  
  df_grp$adjusted_yes_price <- adj
  df_grp
}

#' Clean the data to impose no arbitrage restrictions and push our Kalshi prices into a monotonic
#' and connected CDF. Several potential options to impose this.
#'
#' @param df Dataframe of prices ready to be converted into a CDF
#' @param type Method to impose monotonic increasing/no arbitrage assumptions. By default middle-out
#' (defined above). Can also impose right-to-left (ensuring prices decrease from the right-tail
#' bins) or left-to-right (ensuring prices increase from the left-tail bins)
clean_data <- function(
    df,
    type = "middle-out"
) {
  
  df <- df %>% dplyr::arrange(contract_preamble, strike, date)
  
  if (type == "right-to-left") {
    return(
      df %>%
        dplyr::group_by(contract_preamble, date) %>%
        dplyr::arrange(dplyr::desc(strike), .by_group = TRUE) %>%
        dplyr::mutate(adjusted_yes_price = cummax(yes_price)) %>%
        dplyr::ungroup()
    )
    
  } else if (type == "left-to-right") {
    return(
      df %>%
        dplyr::group_by(contract_preamble, date) %>%
        dplyr::arrange(strike, .by_group = TRUE) %>%
        dplyr::mutate(adjusted_yes_price = -cummax(-yes_price)) %>%
        dplyr::ungroup()
    )
  } else if (type == "middle-out") {
    
    return(
      df %>%
        group_by(contract_preamble, date) %>%
        arrange(strike, .by_group = TRUE) %>%
        group_modify(~ adjust_middle_out(.x, target = 49)) %>%
        ungroup()
    )
  }
}

#' Convert adjusted prices to probability distributions
#'
#' Adds low-end bins to each contract/date slice, computes approximate probability
#' buckets by differencing adjusted prices, and iteratively swaps probabilities
#' to smooth out local inconsistencies.
#'
#' @param df A data frame with columns: contract_preamble, date, expiry_date, strike, adjusted_yes_price.
#' @param strike_int A value representing the difference between strikes (how low to set the low bin)
#' @param days_before_horizon A value for removing data too far away from the horizon from the dataset
#' @return A data frame with an added `probability` column representing
#'         approximate probability mass for each strike bin.
convert_to_probabilities <- function(df, strike_int, days_before_horizon, type = 'swap') {
  
  # Add low bins representing if even the minimum strike listed was not cleared
  # In order to not skew moments towards 0, the low bin is marked as the
  # strike_int away from the lowest bin listed by Kalshi
  all_cols <- names(df)
  new_rows <- df %>%
    group_by(contract_preamble, datetime_6h_utc, datetime_6h_et, expiry_datetime) %>%
    summarise(strike = min(strike) - strike_int, date = first(date), .groups = "drop")
  
  df <- bind_rows(df, new_rows)
  
  # Now, we calculate probabilities by taking 99 (the highest possible yes_price)
  # on Kalshi and subtracting the left-most yes-price. 
  # ie the lowest bin will be: 99 - [price to buy an 'above lowest bin' contract]
  # second lowest bin will be:
  # [price to buy an 'above lowest bin' contract] - [price to buy an 'above 2nd lowest bin' contract]
  # etc...
  df <- df %>% 
    group_by(contract_preamble, datetime_6h_utc) %>% 
    arrange(strike) %>%
    mutate(probability = 
             ifelse(is.na(lag(strike)), 99 - lead(adjusted_yes_price),
                    ifelse(!is.na(lead(strike)), adjusted_yes_price - lead(adjusted_yes_price), adjusted_yes_price - 1)
             ))
  
  # Add in missing strikes
  df <- df %>%
    group_by(contract_preamble, datetime_6h_utc, datetime_6h_et, expiry_datetime) %>%
    arrange(strike, .by_group = TRUE) %>%
    
    # work on an integer step index to avoid floating-point problems
    mutate(
      k = round((strike - min(strike, na.rm = TRUE)) / strike_int)
    ) %>% 
    
    distinct(k, .keep_all = TRUE) %>%  # remove any duplicates 
    complete(
      k = full_seq(k, 1),              # fill only gaps in the index
      fill = list(
        yes_price          = 0,
        adjusted_yes_price = 0,
        probability        = 0,
        daily_volume       = 0
      )
    ) %>% 
    
    # rebuild strike from the integer index
    mutate(
      strike = min(strike, na.rm = TRUE) + k * strike_int
    ) %>% 
    select(-k) %>% 
    ungroup()
  
  
  
  # Because of low trade volumes, sometimes Kalshi has two contracts that have
  # the exact same yes_price, despite one being for a lower strike than the
  # other. Our previous function would automatically assign the probability to
  # the higher strike, but we actually want to do a bunch of swapping to ensure
  # connected distributions around the modal outcome. We'll loop through the bins
  # once each time, but need to run swap_probabilities until there are no more
  # bins to swap 
  # (This behaves like bubble sort, but we push both sides towards the middle
  # instead)
  swap_probabilities <- function(df_group) {
    
    # For each contract-day, we loop through all the strikes, and if there
    # are gaps in the probability distribution, we fill them by pushing
    # outer bins towards the median
    df_group <- df_group %>% arrange(strike) %>% mutate(swapped = FALSE)

    # Reduce console spam - only print every 100th group or on first iteration
    if (runif(1) < 0.01) {  # Print ~1% of groups
      print(paste('working on: ', head(df_group$contract_preamble, 1), 
                  head(df_group$datetime_6h_utc, 1)))
    }
    
    nrows <- nrow(df_group) - 1
    
    # fill backwards adjusted_yes_values so we properly swap bins towards median
    df_group <- df_group %>%
      mutate(
        adjusted_yes_price = na_if(adjusted_yes_price, 0)
      ) %>%
      fill(adjusted_yes_price, .direction = "up") 
    
    
    
    j = 0
    while(any(df_group$swapped) | j == 0) {
      
      
      df_group$swapped <- FALSE
      
      # to avoid cycles, we have to make sure everything goes to where the median is.
      # Never swap the median location (location just after adjust_yes_price > 49) that we've determined.
      protected_idx <- which(df_group$adjusted_yes_price > 49)
      if(length(protected_idx) == 0) { # if there's no price above 49, just take the largest yesprice as med
        protected_idx <- which.max(df$adjusted_yes_price)
      }
      else {protected_idx <- max(protected_idx)}
      
      # loop through all the strikes
      if (nrows > 2) {
        for (i in 1:nrows) {
          
          # push the low end of the distribution towards the right if there are gaps
          if (
            df_group$adjusted_yes_price[i] > 49 &&
            df_group$probability[i] != 0 &&
            df_group$probability[i + 1] == 0 &&
            i != protected_idx            # don't use protected row as i
          ) {
            
            # Swap x[i] and x[i+1]
            df_group$probability[i+1] <- df_group$probability[i]
            df_group$probability[i] <- 0
            df_group$swapped[i+1] <- TRUE
            
          }
          
          # push the high end of the distribution towards the left if there are gaps
          # above the median
          
          if (
            df_group$adjusted_yes_price[i] < 49 &&
            df_group$probability[i] == 0 &&
            df_group$probability[i + 1] != 0 &&
            i != protected_idx &&           # don't use protected row as i
            (i + 1) != protected_idx 
          ) {
            
            # Swap x[i] and x[i-1]
            df_group$probability[i] <- df_group$probability[i + 1]
            df_group$probability[i + 1] <- 0
            df_group$swapped[i] <- TRUE
            
          }
        }
      }
      j = j + 1
      print(j)
    }
    
    return(df_group)
  }
  
  # Apply our algorithm to the dataframe until we go through an iteration
  # where no bins are swapped
  if (type == 'swap') {
    df <- df %>%
      group_by(contract_preamble, date) %>%
      group_split() %>%
      map_dfr(swap_probabilities)
  }
  
  
  
  # Make sure our probabilities add up to 100
  df <- df %>% group_by(contract_preamble, date) %>% arrange(strike) %>%
    mutate(sum = sum(probability),
           probability = probability * 100 / sum) %>% select(-sum)
  
  # And remove intervals that we're not interested in
  df <- df %>% filter(datetime_6h_utc >= expiry_datetime - days(days_before_horizon))
  
  
  return(df)
  
  
}


# return a new dataframe with the day and contract preamble and
# mean, median, mode, variance, skewness, kurtosis
weightedGMSkew <- function(x, w, na.rm = TRUE) {
  if (na.rm) {
    sel <- !is.na(x) & !is.na(w)
    x <- x[sel]; w <- w[sel]
  }
  w <- w / sum(w)
  mu <- sum(w * x)
  # weighted median
  ord <- order(x); x_o <- x[ord]; w_o <- w[ord]
  cumw <- cumsum(w_o)
  m_w <- x_o[min(which(cumw >= 0.5))]
  mad <- sum(w * abs(x - m_w))
  (mu - m_w) / mad
}

get_moments <- function(df, moment_adjustment) {
  
  df <- df %>%
    group_by(datetime_6h_utc, datetime_6h_et, contract_preamble, expiry_datetime) %>%
    summarise(
      mean     = sum(probability * strike, na.rm = TRUE) / sum(probability, na.rm = TRUE) + moment_adjustment,
      median   = weightedMedian(strike, w = probability, na.rm = TRUE, interpolate = FALSE) + moment_adjustment,
      mode = fmode(strike, w = probability, na.rm = TRUE, ties='first') + moment_adjustment,
      skewness = weightedGMSkew(strike, w = probability, na.rm = TRUE),
      kurtosis = DescTools::Kurt(strike, w = probability, na.rm = TRUE),
      variance = sum(probability * (strike - (sum(probability * strike) / sum(probability)))^2, na.rm = TRUE) / sum(probability, na.rm = TRUE),
      .groups = "drop"
    )
  return(df)
}


#' Extract probability distributions and compute moments from raw Kalshi trade data
#'
#' Reads raw data, processes it through several cleaning and transformation steps,
#' computes probability distributions and statistical moments, and writes results to CSV files.
#'
#' @param input_file Path to the input CSV file with raw trade-level data.
#' @param output_distributions Path to output CSV file for the processed probability distributions.
#' @param output_moments Path to output CSV file for the computed moments
#' @param days_before_horizon A value for removing data too far away from the horizon from the
#' dataset
#' @param moment_adjustment By default 0, an adjustment to central moments so that strikes get
#' correctly interpreted as the corresponding events where they would pay off
#' @return No return value. Writes processed data to specified output files.
extract_distributions <- function(input_file, output_distributions, output_moments, strike_int,
                                  days_before_horizon, moment_adjustment=0) {
  
  df <- read_data(input_file = input_file)
  df <- convert_to_6hourly(df, method = 'last')
  df <- fill_dataless_intervals(df, days_before_horizon)
  df <- clean_data(df)
  
  df <- convert_to_probabilities(df, strike_int = strike_int, days_before_horizon)
  moments_df <- get_moments(df, moment_adjustment)
  
  write_csv(moments_df, output_moments)
  write_csv(df, output_distributions)
  
}


# extract_distributions(input_file = 'data/trade_level_data/trade_level_data_fed_levels.csv',
#                       output_distributions = 'data/hourly_distribution_data/hourly_distributions_fed_levels.csv',
#                       output_moments = 'data/hourly_moments_data/hourly_moments_fed_levels.csv',
#                       strike_int = 0.25,
#                       days_before_horizon = 180,
#                       moment_adjustment = .125)
# 
extract_distributions(input_file = 'data/trade_level_data/trade_level_data_headline_cpi_releases.csv',
                      output_distributions = 'data/hourly_distribution_data/hourly_distributions_headline_cpi_releases.csv',
                      output_moments = 'data/hourly_moments_data/hourly_moments_headline_cpi_releases.csv',
                      strike_int = 0.1,
                      days_before_horizon = 30,
                      moment_adjustment = .1)

extract_distributions(input_file = 'data/trade_level_data/trade_level_data_unemployment.csv',
                      output_distributions = 'data/hourly_distribution_data/hourly_distributions_unemployment_releases.csv',
                      output_moments = 'data/hourly_moments_data/hourly_moments_unemployment_releases.csv',
                      strike_int = 0.1,
                      days_before_horizon = 30,
                      moment_adjustment = .1)

extract_distributions(input_file = 'data/trade_level_data/trade_level_data_core_cpi_releases.csv',
                      output_distributions = 'data/hourly_distribution_data/hourly_distributions_core_cpi_releases.csv',
                      output_moments = 'data/hourly_moments_data/hourly_moments_core_cpi_releases.csv',
                      strike_int = 0.1,
                      days_before_horizon = 30,
                      moment_adjustment = .1)


# extract_distributions(input_file = 'data/trade_level_data/trade_level_data_fed_levels.csv',
#                       output_distributions = 'data/daily_distribution_data_middle_out/daily_distributions_fed_levels.csv',
#                       output_moments = 'data/daily_moments_data_middle_out/daily_moments_fed_levels.csv',
#                       strike_int = 0.25,
#                       days_before_horizon = 180)
# 
# 
# extract_distributions(input_file = 'data/trade_level_data/trade_level_data_headline_cpi_releases.csv',
#                       output_distributions = 'data/daily_distribution_data_middle_out/daily_distributions_headline_cpi_releases.csv',
#                       output_moments = 'data/daily_moments_data_middle_out/daily_moments_headline_cpi_releases.csv',
#                       strike_int = 0.1,
#                       days_before_horizon = 30)

# extract_distributions(input_file = 'data/trade_level_data/trade_level_data_headline_cpi_releases.csv',
#                       output_distributions = 'data/daily_distribution_data_middle_out/daily_distributions_headline_cpi_releases_regressions.csv',
#                       output_moments = 'data/daily_moments_data_middle_out/daily_moments_headline_cpi_releases_regressions.csv',
#                       strike_int = 0.1,
#                       days_before_horizon = 90)

# extract_distributions(input_file = 'data/trade_level_data/trade_level_data_unemployment.csv',
#                       output_distributions = 'data/daily_distribution_data_middle_out/daily_distributions_unemployment_releases.csv',
#                       output_moments = 'data/daily_moments_data_middle_out/daily_moments_unemployment_releases.csv',
#                       strike_int = 0.1,
#                       days_before_horizon = 60)

# extract_distributions(input_file = 'data/trade_level_data/trade_level_data_headline_cpi_releases_mom.csv',
#                       output_distributions = 'data/daily_distribution_data_middle_out/daily_distributions_headline_cpi_releases_mom.csv',
#                       output_moments = 'data/daily_moments_data_middle_out/daily_moments_headline_cpi_releases_mom.csv',
#                       strike_int = 0.1,
#                       days_before_horizon = 60)

# extract_distributions(input_file = 'data/trade_level_data/trade_level_data_core_cpi_releases.csv',
#                       output_distributions = 'data/daily_distribution_data_middle_out/daily_distributions_core_cpi_releases.csv',
#                       output_moments = 'data/daily_moments_data_middle_out/daily_moments_core_cpi_releases.csv',
#                       strike_int = 0.1,
#                       days_before_horizon = 30)
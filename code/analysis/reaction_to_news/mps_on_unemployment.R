setwd('~/Documents/Research/PredictionMarketsPublic/')

source('~/Documents/Research/Utilities/utilities.R')
library(tidyverse)
library(modelsummary)
library(sandwich)
library(lmtest)

# Load bloomberg + kalshi merged data
# calculate changes
load_data_unemployment <- function() {
  
  # df_mps <- readxl::read_xlsx('data/external_data/mps.xlsx')
  df_mps <- read_csv('data/external_data/mps.csv')
  
  colnames(df_mps) <- c('prediction_date', 'mps_statement', 'mps_press_conference', 'mps_event')

  df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_unemployment_releases.csv')
  df_kalshi <- df_kalshi %>% mutate(kalshi_mean_c = mean - lag(mean),
                                    kalshi_median_c = median - lag(median),
                                    kalshi_mode_c = mode - lag(mode),
                                    kalshi_variance_c = variance - lag(variance),
                                    kalshi_skew_c = skewness - lag(skewness),
                                    kalshi_kurt_c = kurtosis - lag(kurtosis))
  
  df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
  
  df <- left_join(df_kalshi, df_mps) %>% select(prediction_date, contract_preamble,
                                                horizon_date,
                                                kalshi_mean_c, 
                                                kalshi_median_c, kalshi_mode_c, 
                                                kalshi_skew_c, kalshi_variance_c,
                                                kalshi_kurt_c, 
                                                mps_statement, 
                                                mps_press_conference, mps_event) %>% na.omit()
  
  df <- df %>% filter(horizon_date <= as.Date('2025-08-31'), prediction_date >= as.Date('2022-01-01'))
  
  # Get "long-run" kalshi forecasts (2 months away)
  df <- df %>% filter(horizon_date <= prediction_date %m+% months(1))
  
  return(df)
  
}

responses_to_surprises <- function(df, output_name = 'output/mps_regressions.tex', spec = 'mps_statement') {
  
  # Narrow mps regressions
  if(spec == 'mps_statement') {
    model_mean_c <- lm(kalshi_mean_c ~ mps_statement, data = df)
    model_median_c <- lm(kalshi_median_c ~ mps_statement, data = df)
    model_mode_c <- lm(kalshi_mode_c ~ mps_statement, data = df)
    model_var_c <- lm(kalshi_variance_c ~ mps_statement, data = df)
    model_skew_c <- lm(kalshi_skew_c ~ mps_statement, data = df)
    model_kurtosis_c <- lm(kalshi_kurt_c ~ mps_statement, data = df)
    
  } else if(spec == 'mps_event') {
    # Wide mps regressions
    model_mean_c <- lm(kalshi_mean_c ~ mps_event, data = df)
    model_median_c <- lm(kalshi_median_c ~ mps_event, data = df)
    model_mode_c <- lm(kalshi_mode_c ~ mps_event, data = df)
    model_var_c <- lm(kalshi_variance_c ~ mps_event, data = df)
    model_skew_c <- lm(kalshi_skew_c ~ mps_event, data = df)
    model_kurtosis_c <- lm(kalshi_kurt_c ~ mps_event, data = df)
  }
  
  # Put models in a named list so the names become column labels
  models <- list(
    "Mean"     = model_mean_c,
    "Median"   = model_median_c,
    "Mode"     = model_mode_c,
    "Variance" = model_var_c,
    "Skewness"     = model_skew_c,
    "Kurtosis" = model_kurtosis_c
  )
  
  if(spec == 'mps_statement') {
    note_text <- "Notes: Robust standard errors (HC3). Columns represent change in moments of the Unemployment Rate distribution on the day of the news release of meetings more than 2 months away (end of previous day to end of day of release). A monetary policy shock is measured as the raw change in the fourth ED contract (in 2022) and the fourth 3 month SOFR contract (2023-2025). Statement shock from San Francisco Fed's USMPD Database."
  } else if(spec == 'mps_event') {
    note_text <- "Notes: Robust standard errors (HC3). Columns represent change in moments of the Unemployment Rate distribution on the day of the news release of meetings more than 2 months away (end of previous day to end of day of release). A monetary policy shock is measured as the raw change in the fourth ED contract (in 2022) and the fourth 3 month SOFR contract (2023-2025). Monetary Event shock from San Francisco Fed's USMPD Database."
  }
  
  coef_map <- c(
    "(Intercept)" = "(Intercept)",
    setNames("Monetary Policy Shock", spec)
  )
  
  # LaTeX regression table with robust SEs
  modelsummary(
    models,
    vcov      = 'HC3',  # robust SEs
    statistic = "({std.error})",           # how SEs appear under coef
    stars     = c('*' = 0.10, '**' = 0.05, '***' = 0.01),
    coef_map  = coef_map,
    gof_omit = "IC|Log.Lik|RMSE|F",  # keep N, R2, Adj R2; hide AIC/BIC/etc.
    title  = paste("Unemployment Distribution responses to Monetary Policy Shocks"),
    notes = note_text,
    output = output_name                   
  )
  
  
}


run_exhibit <- function() {
  
  
  # Create pdf
  # pdf('output/mps_exhibit.pdf', width = 8.5, height = 11)
  # setPar()
  df <- load_data_unemployment()
  
  responses_to_surprises(df, spec = 'mps_statement', output_name = 'output/mps_regressions_statement_unemployment.tex')
  responses_to_surprises(df, spec = 'mps_event', output_name = 'output/mps_regressions_event_unemployment.tex')
  
  
  # dev.off()
}


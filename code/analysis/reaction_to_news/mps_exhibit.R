setwd('~/Documents/Research/PredictionMarketsReplication/')

source('~/Documents/Research/Utilities/utilities.R')
library(tidyverse)
library(modelsummary)
library(sandwich)
library(lmtest)

# Load bloomberg + kalshi merged data
# calculate changes
load_data <- function(input='statement_shock', output='ffr', include_next_meeting = TRUE, next_meetings = 0) {
  
  # Load the monetary policy shock data of interest
  
  # From SF Fed's USMPD csv``
  if(input=='statement_shock') {
    df_mps <- read_csv('data/external_data/mps.csv') %>% select('Date', 'STMT') 
  } else if(input == 'pc_shock') {
    df_mps <- read_csv('data/external_data/mps.csv') %>% select('Date', 'PC') 
  } else if(input=='event_shock') {
    df_mps <- read_csv('data/external_data/mps.csv') %>% select('Date', 'ME') 
    
  # From SF Fed's 'Data for' USMPD csv
  } else if(input=='statement_mp1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'MP1')
    
  } else if(input=='statement_mp2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'MP2')
    
    
  } else if(input=='statement_ed7') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED7')
    
    
    
  } else if(input=='statement_ed6') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED6')
    
    
    
  } else if(input=='statement_ed5') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED5')
    
    
  } else if(input=='statement_ed4') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED4')
    
  } else if(input=='statement_ed3') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED3')
    
  } else if(input=='statement_ed2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED2')
    
  } else if(input=='statement_ed1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED1')
    
  } else if(input=='statement_residual') {
    # residual of ed4 on mp1
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED4', 'MP1')
    m <- lm(MP1 ~ ED4, data = df_mps)
    
    # Add residuals and select desired columns
    df_mps <- df_mps %>%
      mutate(Resids = resid(m)) %>%
      select(Date, Resids)
    
  } else if(input=='pc_mp1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'MP1')
    
  } else if(input=='pc_mp2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'MP2')
    
    
  } else if(input=='pc_ed7') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED7')
    
    
    
  } else if(input=='pc_ed6') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED6')
    
    
    
  } else if(input=='pc_ed5') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED5')
    
    
  } else if(input=='pc_ed4') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED4')
    
  } else if(input=='pc_ed3') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED3')
    
  } else if(input=='pc_ed2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED2')
    
  } else if(input=='pc_ed1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED1')
    
  } else if (input == 'pc_residual') {
    
    # residual of ed4 on mp1
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED4', 'MP1')
    m <- lm(MP1 ~ ED4, data = df_mps)
    
    # Add residuals and select desired columns
    df_mps <- df_mps %>%
      mutate(Resids = resid(m)) %>%
      select(Date, Resids)
    
    
  } else if(input=='pc_residual') { 
    
  } else if(input=='event_mp1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'MP1')
    
  } else if(input=='event_mp2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'MP2')
    
    
  } else if(input=='event_ed7') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED7')
    
    
    
  } else if(input=='event_ed6') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED6')
    
    
    
  } else if(input=='event_ed5') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED5')
    
    
    
  } else if(input=='event_ed4') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED4')
  
    } else if(input=='event_ed3') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED3')
    
  } else if(input=='event_ed2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED2')
    
  } else if(input=='event_ed1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED1')
    
  } else if(input=='event_residual') {
    
    # residual of ed4 on mp1
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Monetary Events') %>% select('Date', 'ED4', 'MP1')
    m <- lm(MP1 ~ ED4, data = df_mps)
    
    # Add residuals and select desired columns
    df_mps <- df_mps %>%
      mutate(Resids = resid(m)) %>%
      select(Date, Resids)
    
  } else if(input=='minutes_mp1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'MP1')
    
  } else if(input=='minutes_mp2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'MP2')
    
    
  } else if(input=='minutes_ed7') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED7')
    
    
    
  } else if(input=='minutes_ed6') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED6')
    
    
    
  } else if(input=='minutes_ed5') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED5')
    
    
  } else if(input=='minutes_ed4') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED4')
    
  } else if(input=='minutes_ed3') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED3')
    
  } else if(input=='minutes_ed2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED2')
    
  } else if(input=='minutes_ed1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED1')
    
  } else if(input=='minutes_residual') {
    # residual of ed4 on mp1
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Minutes') %>% select('Date', 'ED4', 'MP1')
    m <- lm(MP1 ~ ED4, data = df_mps)
  }
    

  colnames(df_mps) <- c('prediction_date', 'shock')

  if(output=='ffr') {
    df_kalshi <- read_csv('data/external_data/kalshi_news_surprises_ffr.csv')
    
    df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_fed_levels.csv')
    df_kalshi <- df_kalshi %>%
      arrange(contract_preamble, date) %>%
      group_by(contract_preamble) %>%
      mutate(
        skewness2 = (mean - mode),
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
        kalshi_skew2_c = skewness2 - lag(skewness2),
        kalshi_kurt_c = kurtosis - lag(kurtosis)
      ) %>%
      ungroup()
    
    df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
    
    
  } else if (output == 'unemployment') {
    
    df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_unemployment_releases.csv')
    df_kalshi <- df_kalshi %>%
      arrange(contract_preamble, date) %>%
      group_by(contract_preamble) %>%
      mutate(
        skewness2 = (mean - median)/variance^(1/2),
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
        kalshi_skew2_c = skewness2 - lag(skewness2),
        kalshi_kurt_c = kurtosis - lag(kurtosis)
      ) %>%
      ungroup()
    
    df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
    
  } else if (output=='cpi') {
    df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_headline_cpi_releases_regressions.csv')
    df_kalshi <- df_kalshi %>%
      arrange(contract_preamble, date) %>%
      group_by(contract_preamble) %>%
      mutate(
        skewness2 = (mean - mode)/variance^(1/2),
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
        kalshi_skew2_c = skewness2 - lag(skewness2),
        kalshi_kurt_c = kurtosis - lag(kurtosis)
      ) %>%
      ungroup()
    
    df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
  
  } else if (output=='cpi_mom') {
    df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_headline_cpi_releases_mom.csv')
    df_kalshi <- df_kalshi %>%
      arrange(contract_preamble, date) %>%
      group_by(contract_preamble) %>%
      mutate(
        skewness2 = (mean - mode)/variance^(1/2),
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
        kalshi_skew2_c = skewness2 - lag(skewness2),
        kalshi_kurt_c = kurtosis - lag(kurtosis)
      ) %>%
      ungroup()
    
    df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
    
  } else if (output=='core_cpi') {
    df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_core_cpi_releases.csv')
    df_kalshi <- df_kalshi %>%
      arrange(contract_preamble, date) %>%
      group_by(contract_preamble) %>%
      mutate(
        skewness2 = (mean - mode)/variance^(1/2),
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
        kalshi_skew2_c = skewness2 - lag(skewness2),
        kalshi_kurt_c = kurtosis - lag(kurtosis)
      ) %>%
      ungroup()
    
    df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
      
  } else if (output=='cpi_swanson') {
    df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_headline_cpi_releases_regressions_swanson.csv')
    df_kalshi <- df_kalshi %>%
      arrange(contract_preamble, date) %>%
      group_by(contract_preamble) %>%
      mutate(
        skewness2 = (mean - mode)/variance^(1/2),
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
        kalshi_skew2_c = skewness2 - lag(skewness2),
        kalshi_kurt_c = kurtosis - lag(kurtosis)
      ) %>%
      ungroup()
    
    df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
    
  } 

  df <- left_join(df_kalshi, df_mps) %>% select(prediction_date, contract_preamble,
                                               horizon_date, 
                                               # kalshi_mean, 
                                               # kalshi_median, kalshi_mode, 
                                               # kalshi_skew, kalshi_variance,
                                               kalshi_mean_c, 
                                               kalshi_median_c, kalshi_mode_c, 
                                               kalshi_skew_c, kalshi_variance_c,
                                               kalshi_kurt_c, kalshi_skew2_c,
                                               # ticker_name, 
                                               shock) %>% na.omit()
  
  df <- df %>% filter(horizon_date <= as.Date('2025-08-31'))
  
  # full_join(df, df_old)
  
  # Get "long-run" kalshi forecasts (1 months away)
  if(output=='ffr' | output=='cpi' | output=='cpi_mom' & include_next_meeting == FALSE) {
     df <- df %>% filter(horizon_date >= prediction_date %m+% months(1))
  }
  
  if(output=='ffr' & next_meetings != 0) {
    df <- df %>% filter(horizon_date >= prediction_date %m+% months(next_meetings),
                        horizon_date <= prediction_date %m+% months(next_meetings + 1))
  }
  
  # df <- df %>% filter(horizon_date <= prediction_date %m+% months(4))
  
  
  return(df)
  
}

responses_to_surprises <- function(df, output_name = 'output/mps_regressions.tex', 
  note_text='Notes: Robust standard errors (HC3). Columns represent change in moments 
  of the Federal Funds Rate distribution on the day of the news release of meetings 
  more than 2 months away (end of previous day to end of day of release). A monetary 
  policy shock is measured as the raw change in the fourth ED contract (in 2022) and 
  the fourth 3 month SOFR contract (2023-2025).', 
  title_text = "Fed Funds Rate Distribution responses to Monetary Policy Shocks",
  interaction = FALSE)
{
  
  # mps regressions
  model_mean_c <- lm(kalshi_mean_c ~ shock, data = df)
  model_median_c <- lm(kalshi_median_c ~ shock, data = df)
  model_mode_c <- lm(kalshi_mode_c ~ shock, data = df)
  model_var_c <- lm(kalshi_variance_c ~ shock, data = df)
  model_skew_c <- lm(kalshi_skew_c ~ shock, data = df)
  model_skew2_c <- lm(kalshi_skew2_c ~ shock, data = df)
  model_kurtosis_c <- lm(kalshi_kurt_c ~ shock, data = df)
  

  # Put models in a named list so the names become column labels
  models <- list(
    "Mean"     = model_mean_c,
    "Median"   = model_median_c,
    "Mode"     = model_mode_c,
    "Variance" = model_var_c,
    "Skewness"     = model_skew_c,
    "Mean - Mode" = model_skew2_c,
    "Kurtosis" = model_kurtosis_c
  )
  
  coef_map <- c(
    "(Intercept)" = "(Intercept)",
    setNames("Monetary Policy Shock", 'shock')
  )
  
  # LaTeX regression table with robust SEs
  modelsummary(
    models,
    vcov      = 'HC3',  # robust SEs
    statistic = "({std.error})",           # how SEs appear under coef
    stars     = c('*' = 0.10, '**' = 0.05, '***' = 0.01),
    coef_map  = coef_map,
    gof_omit = "IC|Log.Lik|RMSE|F",  # keep N, R2, Adj R2; hide AIC/BIC/etc.
    title  = title_text,
    notes = note_text,
    output = output_name                   
  )
  
  
}


run_exhibit <- function() {
  
  
  shock_types <- c('statement_shock', 'pc_shock', 'event_shock', 
                   
                   'statement_mp1', 'statement_mp2', 'statement_ed7',
                   'statement_ed6', 'statement_ed5',
                   'statement_ed4','statement_ed3',
                   'statement_ed2', 'statement_ed1',  'statement_residual',
                   
                   'minutes_mp2', 'minutes_ed7',
                   'minutes_ed6', 'minutes_ed5',
                   'minutes_ed4','minutes_ed3',
                   'minutes_ed2', 'minutes_ed1',

                   'pc_mp1', 'pc_mp2', 'pc_ed7', 'pc_ed6', 'pc_ed5',
                   'pc_ed4', 'pc_ed3', 'pc_ed2',
                   'pc_ed1', 'pc_residual',
                   
                   'event_mp1', 'event_mp2', 'event_ed7', 'event_ed6', 'event_ed5', 
                   'event_ed4', 'event_ed3', 'event_ed2', 
                   'event_ed1', 'event_residual'
                   )
  
  output_types <- c('ffr', 'unemployment', 'cpi', 'core_cpi', 'cpi_mom')
  
  include_next_meeting_types <- c(TRUE, FALSE)
  
  
  for (i in 1:length(shock_types)) {
    for (j in 1:length(output_types)) {
      for (include_next_meeting in include_next_meeting_types) {
        
        shock <- shock_types[i]
        output <- output_types[j]
        
        note_addition <- ''
        sample_addition <- ''
        # if(output != 'ffr') {include_next_meeting = TRUE}
        if(include_next_meeting) {
          note_addition = 'more than 1 month away '
          sample_addition = '_far_meetings'
        }
        
        output_name <- paste0('output/mps_regressions/', output, '/', shock, sample_addition, '.tex')
        
        
        note_text <- paste0("Notes: Robust standard errors (HC3). Columns represent change in moments 
  of the ", output,  " distribution on the day of the news release of meetings ", note_addition, "
  (end of previous day to end of day of release). A monetary policy shock is 
  measured as the ", shock,  "shock according to San Francisco Fed's USMPD Database.")
        
        title_text <- ''
        if (output == 'ffr') {title_text <- "Fed Funds Rate Distribution responses to Monetary Policy Shocks"}
        if (output == 'unemployment') {title_text <- "Unemployment Rate Distribution responses to Monetary Policy Shocks"}
        if (output == 'cpi') {title_text <- "Headline CPI Distribution responses to Monetary Policy Shocks"}
        if (output == 'core_cpi') {title_text <- "Core CPI Distribution responses to Monetary Policy Shocks"}
        
        
        print(shock)
        print(output)
        df <- load_data(input=shock, output=output, include_next_meeting = include_next_meeting)
        
        responses_to_surprises(df, output_name = output_name, 
                                           note_text = note_text, 
                                           title_text = title_text)
      }
    }
  }
}


run_different_horizons <- function() {
  
  
  shock_types <- c('event_ed4')
  
  output_types <- c('ffr')
  
  next_meeting_types <- c(1,2,3,4,5,6)
  
  
  for (i in 1:length(shock_types)) {
    for (j in 1:length(output_types)) {
      for (next_meeting in next_meeting_types) {
        
        shock <- shock_types[i]
        output <- output_types[j]
        
        note_addition <- ''
        sample_addition <- ''
        include_next_meeting <- TRUE
        if(include_next_meeting) {
          note_addition = paste('[only gets the meeting', next_meeting, 'meetings away ] ')
          sample_addition = paste0('_', next_meeting, '_meetings')
        }
        
        output_name <- paste0('output/mps_regressions/', output, '/', shock, sample_addition, '.tex')
        
        
        note_text <- paste0("Notes: Robust standard errors (HC3). Columns represent change in moments 
  of the ", output,  " distribution on the day of the news release of meetings ", note_addition, "
  (end of previous day to end of day of release). A monetary policy shock is 
  measured as the ", shock,  "shock according to San Francisco Fed's USMPD Database.")
        
        title_text <- ''
        if (output == 'ffr') {title_text <- "Fed Funds Rate Distribution responses to Monetary Policy Shocks"}
        
        print(shock)
        print(output)
        df <- load_data(input=shock, output=output, next_meetings = next_meeting)
        
        responses_to_surprises(df, output_name = output_name, 
                               note_text = note_text, 
                               title_text = title_text)
      }
    }
  }
}

run_exhibit()
# run_different_horizons()


responses_to_surprises <- function(df, output_name = 'output/mps_regressions.tex', 
                                   note_text='Notes: Robust standard errors (HC3). Columns represent change in moments 
  of the Federal Funds Rate distribution on the day of the news release of meetings 
  more than 2 months away (end of previous day to end of day of release). A monetary 
  policy shock is measured as the raw change in the fourth ED contract (in 2022) and 
  the fourth 3 month SOFR contract (2023-2025).', 
                                   title_text = "Fed Funds Rate Distribution responses to Monetary Policy Shocks",
                                   interaction = FALSE)
{
  
  # mps regressions
  model_mean_c <- lm(kalshi_mean_c ~ shock, data = df)
  model_median_c <- lm(kalshi_median_c ~ shock, data = df)
  model_mode_c <- lm(kalshi_mode_c ~ shock, data = df)
  model_var_c <- lm(kalshi_variance_c ~ shock, data = df)
  model_skew_c <- lm(kalshi_skew_c ~ shock, data = df)
  model_skew2_c <- lm(kalshi_skew2_c ~ shock, data = df)
  model_kurtosis_c <- lm(kalshi_kurt_c ~ shock, data = df)
  
  
  # Put models in a named list so the names become column labels
  models <- list(
    "Mean"     = model_mean_c,
    "Median"   = model_median_c,
    "Mode"     = model_mode_c,
    "Variance" = model_var_c,
    "Skewness"     = model_skew_c,
    "Mean - Mode" = model_skew2_c,
    "Kurtosis" = model_kurtosis_c
  )
  
  coef_map <- c(
    "(Intercept)" = "(Intercept)",
    setNames("Monetary Policy Shock", 'shock')
  )
  
  # LaTeX regression table with robust SEs
  modelsummary(
    models,
    vcov      = 'HC3',  # robust SEs
    statistic = "({std.error})",           # how SEs appear under coef
    stars     = c('*' = 0.10, '**' = 0.05, '***' = 0.01),
    coef_map  = coef_map,
    gof_omit = "IC|Log.Lik|RMSE|F",  # keep N, R2, Adj R2; hide AIC/BIC/etc.
    title  = title_text,
    notes = note_text,
    output = output_name                   
  )
  
  
}

output <- 'core_cpi'
shock <- 'minutes_ed4'



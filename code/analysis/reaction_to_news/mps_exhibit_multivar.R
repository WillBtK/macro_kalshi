setwd('~/Documents/Research/PredictionMarketsPublic/')

source('~/Documents/Research/Utilities/utilities.R')
library(tidyverse)
library(modelsummary)
library(sandwich)
library(lmtest)

# Load bloomberg + kalshi merged data
# calculate changes
load_data_multi <- function(input='shock', output='ffr', include_next_meeting = TRUE, next_meetings = 0) {
  
  # Load the monetary policy shock data of interest
  
  # From SF Fed's USMPD csv``
  if(input=='shock') {
    df_mps <- read_csv('data/external_data/mps.csv') %>% select('Date', 'STMT') 
    df_mps2 <- read_csv('data/external_data/mps.csv') %>% select('Date', 'PC') 
    df_mps <- full_join(df_mps, df_mps2)
  

    # From SF Fed's 'Data for' USMPD csv
  } else if(input=='mp1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'MP1') %>% rename(stmt_mp1 = MP1)
    df_mps2 <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'MP1') %>% rename(pc_mp1 = MP1)
    df_mps <- full_join(df_mps, df_mps2)
    
    
  } else if(input=='mp2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'MP2') %>% rename(stmt_mp2 = MP2)
    df_mps2 <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'MP2') %>% rename(pc_mp2 = MP2)
    df_mps <- full_join(df_mps, df_mps2)    
    
  } else if(input=='ed4') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED4') %>% rename(stmt_ed4 = ED4)
    df_mps2 <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED4') %>% rename(pc_ed4 = ED4)
    df_mps <- full_join(df_mps, df_mps2)  
    
  } else if(input=='ed3') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED3') %>% rename(stmt_ed3 = ED3)
    df_mps2 <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED3') %>% rename(pc_ed3 = ED3)
    df_mps <- full_join(df_mps, df_mps2) 
    
  } else if(input=='ed2') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED2') %>% rename(stmt_ed2 = ED2)
    df_mps2 <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED2') %>% rename(pc_ed2 = ED2)
    df_mps <- full_join(df_mps, df_mps2) 
    
  } else if(input=='ed1') {
    df_mps <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Statements') %>% select('Date', 'ED1') %>% rename(stmt_ed1 = ED1)
    df_mps2 <- readxl::read_xlsx('data/external_data/usmpd_data.xlsx', sheet = 'Press Conferences') %>% select('Date', 'ED1') %>% rename(pc_ed1 = ED1)
    df_mps <- full_join(df_mps, df_mps2) 
  }
  
  colnames(df_mps) <- c('prediction_date', 'stmt_shock', 'pc_shock')
  
  if(output=='ffr') {
    df_kalshi <- read_csv('data/external_data/kalshi_news_surprises_ffr.csv')
    
    df_kalshi <- read_csv('data/daily_moments_data_middle_out/daily_moments_fed_levels.csv')
    df_kalshi <- df_kalshi %>%
      arrange(contract_preamble, date) %>%
      group_by(contract_preamble) %>%
      mutate(
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
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
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
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
        kalshi_mean_c = mean - lag(mean),
        kalshi_median_c = median - lag(median),
        kalshi_mode_c = mode - lag(mode),
        kalshi_variance_c = variance - lag(variance),
        kalshi_skew_c = skewness - lag(skewness),
        kalshi_kurt_c = kurtosis - lag(kurtosis)
      ) %>%
      ungroup()
    
    df_kalshi <- df_kalshi %>% rename('prediction_date' = 'date', 'horizon_date' = 'expiry_date')
  }
  
  df <- full_join(df_kalshi, df_mps) %>% select(prediction_date, contract_preamble,
                                                horizon_date, 
                                                # kalshi_mean, 
                                                # kalshi_median, kalshi_mode, 
                                                # kalshi_skew, kalshi_variance,
                                                kalshi_mean_c, 
                                                kalshi_median_c, kalshi_mode_c, 
                                                kalshi_skew_c, kalshi_variance_c,
                                                kalshi_kurt_c,
                                                # ticker_name, 
                                                stmt_shock, pc_shock) %>% na.omit()
  
  # df <- df %>% filter(horizon_date <= as.Date('2025-08-31'))
  
  # full_join(df, df_old)
  
  # Get "long-run" kalshi forecasts (1 months away)
  if(output=='ffr' & include_next_meeting == FALSE) {
    df <- df %>% filter(horizon_date >= prediction_date %m+% months(2))
  }
  
  # if(output=='ffr' & next_meetings != 0) {
  #   df <- df %>% filter(horizon_date >= prediction_date %m+% months(next_meetings),
  #                       horizon_date <= prediction_date %m+% months(next_meetings + 1))
  # }
  # 
  # df <- df %>% filter(horizon_date <= prediction_date %m+% months(4))
  
  
  return(df)
  
}

responses_to_surprises_multi <- function(df, output_name = 'output/mps_regressions.tex', 
                                   note_text='Notes: Robust standard errors (HC3). Columns represent change in moments 
  of the Federal Funds Rate distribution on the day of the news release of meetings 
  more than 2 months away (end of previous day to end of day of release). A monetary 
  policy shock is measured as the raw change in the fourth ED contract (in 2022) and 
  the fourth 3 month SOFR contract (2023-2025).', 
                                   title_text = "Fed Funds Rate Distribution responses to Monetary Policy Shocks",
                                   interaction = FALSE)
{
  
  # mps regressions
  model_mean_c <- lm(kalshi_mean_c ~ stmt_shock + pc_shock, data = df)
  model_median_c <- lm(kalshi_median_c ~ stmt_shock + pc_shock, data = df)
  model_mode_c <- lm(kalshi_mode_c ~ stmt_shock + pc_shock, data = df)
  model_var_c <- lm(kalshi_variance_c ~ stmt_shock + pc_shock, data = df)
  model_skew_c <- lm(kalshi_skew_c ~ stmt_shock + pc_shock, data = df)
  model_kurtosis_c <- lm(kalshi_kurt_c ~ stmt_shock + pc_shock, data = df)
  
  
  # Put models in a named list so the names become column labels
  models <- list(
    "Mean"     = model_mean_c,
    "Median"   = model_median_c,
    "Mode"     = model_mode_c,
    "Variance" = model_var_c,
    "Skewness"     = model_skew_c,
    "Kurtosis" = model_kurtosis_c
  )
  
  coef_map <- c(
    "(Intercept)" = "(Intercept)",
    setNames("Monetary Policy Statement Shock", 'stmt_shock'),
    setNames("Monetary Policy Press Conference Shock", 'pc_shock')
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
  
  
  shock_types <- c('shock', 
                   
                   'mp1', 'mp2', 
                   'ed4','ed3',
                   'ed2', 'ed1'
  )
  
  output_types <- c('ffr', 'unemployment', 'cpi')
  
  include_next_meeting_types <- c(TRUE, FALSE)
  
  
  for (i in 1:length(shock_types)) {
    for (j in 1:length(output_types)) {
      for (include_next_meeting in include_next_meeting_types) {
        
        shock <- shock_types[i]
        output <- output_types[j]
        
        note_addition <- ''
        sample_addition <- ''
        # if(output != 'ffr') {include_next_meeting = TRUE}
        if(include_next_meeting == F) {
          note_addition = 'more than 1 month away '
          sample_addition = '_far_meetings'
        }
        
        output_name <- paste0('output/mps_regressions/multivar/', output, '/', shock, sample_addition, '.tex')
        
        
        note_text <- paste0("Notes: Robust standard errors (HC3). Columns represent change in moments 
  of the ", output,  " distribution on the day of the news release of meetings ", note_addition, "
  (end of previous day to end of day of release). A monetary policy shock is 
  measured as the ", shock,  "shock according to San Francisco Fed's USMPD Database.")
        
        title_text <- ''
        if (output == 'ffr') {title_text <- "Fed Funds Rate Distribution responses to Monetary Policy Shocks"}
        if (output == 'unemployment') {title_text <- "Unemployment Rate Distribution responses to Monetary Policy Shocks"}
        if (output == 'cpi') {title_text <- "Headline CPI Distribution responses to Monetary Policy Shocks"}
        
        print(shock)
        print(output)
        df <- load_data_multi(input=shock, output=output, include_next_meeting = include_next_meeting)
        
        responses_to_surprises_multi(df, output_name = output_name, 
                               note_text = note_text, 
                               title_text = title_text)
      }
    }
  }
}

run_exhibit()
setwd('~/Documents/Research/PredictionMarketsPublic/')

source('~/Documents/Research/Utilities/utilities.R')
library(tidyverse)
library(modelsummary)
library(sandwich)
library(lmtest)

# Load bloomberg + kalshi merged data
# calculate changes
load_data <- function() {
  
  df_kalshi <- read_csv('data/external_data/kalshi_news_surprises.csv')
  df_bb <- read_csv('data/external_data/bb_news_surprises.csv')
  
  df <- left_join(df_kalshi, df_bb) %>% select(prediction_date, contract_preamble,
                                               horizon_date, kalshi_mean, 
                                               kalshi_median, kalshi_mode, 
                                               kalshi_skew, kalshi_variance,
                                               kalshi_mean_c, 
                                               kalshi_median_c, kalshi_mode_c, 
                                               kalshi_skew_c, kalshi_variance_c,
                                               kalshi_kurt_c,
                                               ticker_name, survey_median, 
                                               surprise, surprise_sign)
  
  df <- df %>% filter(horizon_date <= as.Date('2025-08-31'))
  
  return(df)
  
}

plot_kalshi_change_event_days <- function(df, column_name,
                               main_title = "Kalshi Variance Changes after News") {
  # Desired order (long names from your df)
  ordered_tickers <- c(
    "CPI YOY Index",
    "PCE DEFY Index",
    "NFP TCH Index",
    "NAPMPMI Index",
    "FDTR Index",
    "FEDMMINU Index",
    "Other"
  )
  
  # Short labels to show on x-axis
  short_labels <- c("CPI", "PCE", "NFP", "ISM Man", "FOMC", "Minutes", "Other")
  
  ## --- subset and reorder ----------------------------------------------------
  df_sub <- df[df$ticker_name %in% ordered_tickers, ]
  df_sub <- df_sub[match(ordered_tickers, df_sub$ticker_name), , drop = FALSE]
  
  # remove rows that are NA after match (in case "Other" etc. missing)
  df_sub <- df_sub[!is.na(df_sub$ticker_name), ]
  y <- df_sub[[column_name]]
  
  # adjust short_labels to remaining rows
  short_labels <- short_labels[!is.na(match(ordered_tickers, df_sub$ticker_name))]
  
  names(y) <- short_labels
  
  ## --- plotting params -------------------------------------------------------
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  
  # Wider right margin for right-hand axis
  par(mar = c(6, 3, 4.5, 5))
  
  # y-limits: a bit of padding above 0 and below min value
  ylim <- range(c(y, 0))
  ylim[2] <- max(0.001, ylim[2] + 0.01)   # top (like 0.001)
  ylim[1] <- min(ylim[1] - 0.01, -0.005)  # bottom (like -0.005)
  
  ## --- barplot ---------------------------------------------------------------
  bp <- barplot(
    y,
    ylim = ylim,
    col = "blue",
    border = NA,
    axes = FALSE,       # we'll add axes manually
    cex.names = 1.2,
    names.arg = rep("", length(y))  # add axis(1) later
  )
  
  # horizontal zero line
  abline(h = 0, lwd = 2)
  
  # x-axis with short labels
  axis(1, at = bp, labels = short_labels, cex.axis = .45, padj = 0.7, tck=0.02)
  
  # left axis: ticks but no labels (just like your example)
  axis(2, labels = FALSE, tck = 0.02)
  
  # right axis: numeric labels
  yticks <- pretty(ylim)
  axis(4, at = yticks,
       labels = format(yticks, digits = 3),
       las = 1, cex.axis = 1.1, tck= 0.02)
  
  # main title
  mtext(main_title, side=3)

  plotHookBox()
}


# How different moments change depending on the event
changes_on_different_events <- function(df) {
  
  groups <- df %>% group_by(ticker_name) %>% 
    summarise_at(vars(kalshi_mean_c, kalshi_median_c, kalshi_mode_c, 
                      kalshi_skew_c, kalshi_variance_c, kalshi_kurt_c),
                 funs(mean(., na.rm=TRUE)))
  
  par(fig=c(0, 0.47, 0.66, 1), new=F)
  plot_kalshi_change_event_days(groups, "kalshi_mean_c", main_title = 'Kalshi mean change after news')
  
  par(fig=c(0.53, 1, 0.66, 1), new=T)
  plot_kalshi_change_event_days(groups, "kalshi_median_c", main_title = 'Kalshi median change after news')
  
  par(fig=c(0, 0.47, 0.33, .66), new=T)
  plot_kalshi_change_event_days(groups, "kalshi_mode_c", main_title = 'Kalshi mode change after news')
  
  par(fig=c(0.53, 1, 0.33, .66), new=T)
  plot_kalshi_change_event_days(groups, "kalshi_variance_c", main_title = 'Kalshi variance change after news')
  
  par(fig=c(0, 0.47, 0, .33), new=T)
  plot_kalshi_change_event_days(groups, "kalshi_skew_c", main_title = 'Kalshi skewness change after news')
  
  par(fig=c(0.53, 1, 0, .33), new=T)
  plot_kalshi_change_event_days(groups, "kalshi_kurt_c", main_title = 'Kalshi kurtosis change after news')
}


plot_kalshi_change_surprises <- function(df, column_name,
                                          main_title = "Kalshi Variance Changes after News") {
  # Desired order (long names from your df)
  ordered_tickers <- c(
    "Positive",
    "None",
    "Negative"
  )
  
  # Short labels to show on x-axis
  short_labels <- c("Positive", "None", "Negative")
  
  ## --- subset and reorder ----------------------------------------------------
  df_sub <- df[df$surprise_sign %in% ordered_tickers, ]
  df_sub <- df_sub[match(ordered_tickers, df_sub$surprise_sign), , drop = FALSE]
  
  # remove rows that are NA after match (in case "Other" etc. missing)
  df_sub <- df_sub[!is.na(df_sub$surprise_sign), ]
  y <- df_sub[[column_name]]
  
  # adjust short_labels to remaining rows
  short_labels <- short_labels[!is.na(match(ordered_tickers, df_sub$surprise_sign))]
  
  names(y) <- short_labels
  
  ## --- plotting params -------------------------------------------------------
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  
  # Wider right margin for right-hand axis
  par(mar = c(6, 3, 4.5, 5))
  
  # y-limits: a bit of padding above 0 and below min value
  ylim <- range(c(y, 0))
  ylim[2] <- max(0.001, ylim[2] + 0.01)   # top (like 0.001)
  ylim[1] <- min(ylim[1] - 0.01, -0.005)  # bottom (like -0.005)
  
  ## --- barplot ---------------------------------------------------------------
  bp <- barplot(
    y,
    ylim = ylim,
    col = "blue",
    border = NA,
    axes = FALSE,       # we'll add axes manually
    cex.names = 1.2,
    names.arg = rep("", length(y))  # add axis(1) later
  )
  
  # horizontal zero line
  abline(h = 0, lwd = 2)
  
  # x-axis with short labels
  axis(1, at = bp, labels = short_labels, cex.axis = .45, padj = 0.7, tck=0.02)
  
  # left axis: ticks but no labels (just like your example)
  axis(2, labels = FALSE, tck = 0.02)
  
  # right axis: numeric labels
  yticks <- pretty(ylim)
  axis(4, at = yticks,
       labels = format(yticks, digits = 3),
       las = 1, cex.axis = 1.1, tck= 0.02)
  
  # main title
  mtext(main_title, side=3)
  
  plotHookBox()
}


responses_to_surprises <- function(df, ticker_choice = 'CPI YOY Index', output_name = 'output/regressions.tex') {
  
  df <- df %>% filter(ticker_name == ticker_choice)
  
  # Standardize surprises for NFP to be 100k jobs as a surprise
  if (ticker_choice == 'NFP TCH Index') {
    df <- df %>% mutate(surprise = surprise / 100)
  }
  
  groups <- df %>% group_by(surprise_sign) %>% 
    summarise_at(vars(kalshi_mean_c, kalshi_median_c, kalshi_mode_c, 
                      kalshi_skew_c, kalshi_variance_c, kalshi_kurt_c),
                 funs(mean(., na.rm=TRUE)))
  
  par(fig=c(0, 0.47, 0.66, 1), new=F)
  plot_kalshi_change_surprises(groups, "kalshi_mean_c", main_title = paste('Kalshi mean change after news', ticker_choice))
  
  par(fig=c(0.53, 1, 0.66, 1), new=T)
  plot_kalshi_change_surprises(groups, "kalshi_median_c", main_title = paste('Kalshi median change after news', ticker_choice))
  
  par(fig=c(0, 0.47, 0.33, .66), new=T)
  plot_kalshi_change_surprises(groups, "kalshi_mode_c", main_title = paste('Kalshi mode change after news', ticker_choice))
  
  par(fig=c(0.53, 1, 0.33, .66), new=T)
  plot_kalshi_change_surprises(groups, "kalshi_variance_c", main_title = paste('Kalshi variance change after news', ticker_choice))
  
  par(fig=c(0, 0.47, 0, .33), new=T)
  plot_kalshi_change_surprises(groups, "kalshi_skew_c", main_title = paste('Kalshi skewness change after news', ticker_choice))
  
  par(fig=c(0.53, 1, 0, .33), new=T)
  plot_kalshi_change_surprises(groups, "kalshi_kurt_c", main_title = paste('Kalshi kurtosis change after news', ticker_choice))
  
  # Regressions instead of discrete
  model_mean_c <- lm(kalshi_mean_c ~ surprise, data = df)
  model_median_c <- lm(kalshi_median_c ~ surprise, data = df)
  model_mode_c <- lm(kalshi_mode_c ~ surprise, data = df)
  model_var_c <- lm(kalshi_variance_c ~ surprise, data = df)
  model_skew_c <- lm(kalshi_skew_c ~ surprise, data = df)
  model_kurtosis_c <- lm(kalshi_kurt_c ~ surprise, data = df)
  
  # Put models in a named list so the names become column labels
  models <- list(
    "Mean"     = model_mean_c,
    "Median"   = model_median_c,
    "Mode"     = model_mode_c,
    "Variance" = model_var_c,
    "Skewness"     = model_skew_c,
    "Kurtosis" = model_kurtosis_c
  )
  
  if(ticker_choice == 'CPI YOY Index') {
    note_text <- "Notes: Robust standard errors (HC3). Columns represent change in moments of the Federal Funds Rate distribution on the day of the news release (end of previous day to end of day of release). A CPI Surprise is a positive 1% difference between Bloomberg survey expectations and actual released headline YoY CPI."
      
  } else if(ticker_choice == 'PCE DEFY Index') {
    
    note_text <- "Notes: Robust standard errors (HC3). Columns represent change in moments of the Federal Funds Rate distribution on the day of the news release (end of previous day to end of day of release). A CPI Surprise is a positive 1% difference between Bloomberg survey expectations and actual released headline YoY PCE."
    
  } else if(ticker_choice == 'NFP TCH Index') {
    
    note_text <- "Notes: Robust standard errors (HC3). Columns represent change in moments of the Federal Funds Rate distribution on the day of the news release (end of previous day to end of day of release). A CPI Surprise is a positive 100k jobs difference between Bloomberg survey expectations and actual released Non-Farm Payrolls numbers."

  }
  
  # LaTeX regression table with robust SEs
  modelsummary(
    models,
    vcov      = 'HC3',  # robust SEs
    statistic = "({std.error})",           # how SEs appear under coef
    stars     = c('*' = 0.10, '**' = 0.05, '***' = 0.01),
    coef_map  = c(
      "(Intercept)" = "(Intercept)",
      "surprise"    = "Surprise"
    ),
    gof_omit = "IC|Log.Lik|RMSE|F",  # keep N, R2, Adj R2; hide AIC/BIC/etc.
    title  = paste("Fed Funds Rate Distribution responses to ", ticker_choice),
    notes = note_text,
    output = output_name                   
  )
  

}


run_exhibit <- function() {
  
  
  # Create pdf
  pdf('output/news_exhibit.pdf', width = 8.5, height = 11)
  setPar()
  df <- load_data()
  
  changes_on_different_events(df)
  
  responses_to_surprises(df, ticker_choice = 'CPI YOY Index', output_name = 'output/cpi_regressions.tex')
  responses_to_surprises(df, ticker_choice = 'PCE DEFY Index', output_name = 'output/pce_regressions.tex')
  responses_to_surprises(df, ticker_choice = 'NFP TCH Index', output_name = 'output/nfp_regressions.tex')
  
  
  dev.off()
}


run_exhibit()
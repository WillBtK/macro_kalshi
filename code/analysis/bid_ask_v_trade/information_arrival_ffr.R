# Not finished

# merge with kalshi data
merge_bid_ask_with_trade <- function() {
  
  # get kalshi from filepath
  trade_level <- read_csv('data/daily_moments_data/daily_moments_fed_levels.csv')
  bid_ask_level <- read_csv('data/daily_bid_ask_moments_data/daily_moments_fed_levels.csv')
  
  colnames(trade_level) <- c("prediction_date", "contract_preamble", "horizon_date", "kalshi_mean_tl", "kalshi_median_tl", "kalshi_mode_tl", "kalshi_skew_tl", "kalshi_kurt_tl", "kalshi_variance_tl")
  colnames(bid_ask_level) <- c("prediction_date", "contract_preamble", "horizon_date", "kalshi_mean_ba", "kalshi_median_ba", "kalshi_mode_ba", "kalshi_skew_ba", "kalshi_kurt_ba", "kalshi_variance_ba")
  
  
  trade_level <- trade_level %>% mutate(
    kalshi_mean_tl = kalshi_mean_tl,
    kalshi_median_tl = kalshi_median_tl,
    kalshi_mode_tl = kalshi_mode_tl,
    prediction_date = as.Date(prediction_date),
    horizon_date = as.Date(horizon_date)
  )
  
  bid_ask_level <- bid_ask_level %>% mutate(
    kalshi_mean_ba = kalshi_mean_ba,
    kalshi_median_ba = kalshi_median_ba,
    kalshi_mode_ba = kalshi_mode_ba,
    prediction_date = as.Date(prediction_date),
    horizon_date = as.Date(horizon_date) - days(1)
  )
  
  kalshi_data <- full_join(trade_level, bid_ask_level) %>% na.omit()
  
  # Join with realized ffr
  df <- read_csv('data/external_data/ffr_data.csv')
  colnames(df) <- c("horizon_date", "realized_ffr")
  
  df <- df %>% mutate(
    horizon_date = as.Date(horizon_date)
  ) 
  
  df <- full_join(kalshi_data, df)
  
  
  df <- df %>% filter(horizon_date <= as.Date('2026-01-01') & horizon_date > as.Date('2022-01-01') 
                      # & horizon_date != as.Date('2022-06-15')
                      )
  
  sep22 <- df %>% filter(horizon_date == as.Date('2022-06-15'))
  
  # Add column for "days before the decision"
  df <- df %>% mutate(days_before_decision = as.double(difftime(horizon_date , prediction_date , units = c("days"))),
                      kalshi_abs_mean_error_tl = abs(kalshi_mean_tl - realized_ffr),
                      kalshi_abs_median_error_tl = abs(kalshi_median_tl - realized_ffr),
                      kalshi_abs_mode_error_tl = abs(kalshi_mode_tl - realized_ffr),
                      
                      kalshi_abs_mean_error_ba = abs(kalshi_mean_ba - realized_ffr),
                      kalshi_abs_median_error_ba = abs(kalshi_median_ba - realized_ffr),
                      kalshi_abs_mode_error_ba = abs(kalshi_mode_ba - realized_ffr),
                      
  )
  
  df <- df %>% filter(days_before_decision>=1)
  
  return(df)
  
}

construct_average_errors <- function(df) {
  
  df <- df %>% filter(days_before_decision <= 165)
  
  df <- df %>% group_by(days_before_decision) %>%
    summarize(average_abs_mean_error_tl = mean(kalshi_abs_mean_error_tl, na.rm = T),
              average_abs_median_error_tl = mean(kalshi_abs_median_error_tl, na.rm = T),
              average_abs_mode_error_tl = mean(kalshi_abs_mode_error_tl, na.rm = T),
              
              average_abs_mean_error_ba = mean(kalshi_abs_mean_error_ba, na.rm = T),
              average_abs_median_error_ba = mean(kalshi_abs_median_error_ba, na.rm = T),
              average_abs_mode_error_ba = mean(kalshi_abs_mode_error_ba, na.rm = T)
              )
  
  return(df)
  
}

# Driver function to do all the work before charting
load_data <- function() {
  

  df <- merge_bid_ask_with_trade()
  avg_errors <- construct_average_errors(df)
  
  return(avg_errors)
}

chart_average_errors <- function(avg_errors) {
  
  
  # Sort the data frame by days_before_event descending (optional)
  avg_errors <- avg_errors[order(-avg_errors$days_before_decision), ]
  
  # Plot y1
  plot(avg_errors$days_before_decision, avg_errors$average_abs_mean_error_tl, type = "l", xlim = rev(range(avg_errors$days_before_decision)),
       col = "blue",
       xlab = NA,
       ylab = NA,
       axes = FALSE, ylim = c(0,.5))
  
  # Add y2 to the same plot
  lines(avg_errors$days_before_decision, avg_errors$average_abs_median_error_tl, col = "red")
  lines(avg_errors$days_before_decision, avg_errors$average_abs_mode_error_tl, col = "purple")
  
  # Add bid-ask midpoint forecasts
  lines(avg_errors$days_before_decision, avg_errors$average_abs_mean_error_ba, col = "blue4", lty=5)
  lines(avg_errors$days_before_decision, avg_errors$average_abs_median_error_ba, col = "red4", lty=5)
  lines(avg_errors$days_before_decision, avg_errors$average_abs_mode_error_ba, col = "purple4", lty=5)
  
  
  legend("topright", legend = c("Kalshi Mean Forecast Error- Trades", "Kalshi Median Forecast Error- Trades", "Kalshi Mode Forecast Error- Trades",
                                "Kalshi Mean Forecast Error- Bid-ask midpoints", "Kalshi Median Forecast Error- Bid-ask midpoints", "Kalshi Mode Forecast Error- Bid-ask midpoints"), 
         col = c("blue", "red", "purple", 'blue4', 'red4', 'purple4'), 
         lty = c(1,1,1,5,5,5),
         pch=c(NA, NA, NA, NA, NA, NA), 
         pt.bg = c('black', 'black', 'black', 'black', 'black', 'black'), 
         bty='n', 
         cex = .7)
  
  plotHookBox()
  
  # Axes
  tick_positions <- seq(0, max(avg_errors$days_before_decision), 10)
  
  # Add x-axis with ticks and labels
  axis(1, at = tick_positions, labels = T, tck=.02, lwd=0, lwd.ticks=1, cex.axis = 0.7) 
  mtext("Days before FOMC", side = 1, line = 2, adj = .5, cex = 0.8, las = 1)
  
  
  # Y-axis labels
  
  axis(4, las=2, tck=.02, lwd=0, lwd.ticks=1, cex.axis = 0.7, labels=FALSE, mgp=c(0, 0.3, 0))
  axis(2, las=2, tck=.02, lwd=0, lwd.ticks=1, cex.axis = 0.7, labels=TRUE, mgp=c(0, 0.3, 0))
  mtext("Forecast prediction error (percent)", side = 2, line = 2, adj = .5, cex = 0.7, las = 0)
  
} 

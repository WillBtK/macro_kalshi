# This file will do some analysis on 2025 YE CPI and GDP markets.

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


# loads and merges our CPI and GDP data
load_data <- function() {
  
  # We need the distribution data because we are also interested in upside or downside risk.
  
  end_of_year_gdp <- read.csv('data/daily_distribution_data/daily_distributions_gdp_end_of_year.csv')
  end_of_year_cpi <- read.csv('data/daily_distribution_data/daily_distributions_headline_cpi_end_of_year.csv')
  
  # So we calculate the moments we want manually.
  end_of_year_gdp_moments <- end_of_year_gdp %>%
    group_by(date, contract_preamble, expiry_date) %>%
    summarise(
      mean_gdp     = sum(probability * strike, na.rm = TRUE) / sum(probability, na.rm = TRUE),
      median_gdp   = weightedMedian(strike, w = probability, na.rm = TRUE, interpolate = FALSE),
      mode_gdp     = fmode(strike, w = probability, na.rm = TRUE, ties = 'first'),
      skewness_gdp = weightedGMSkew(strike, w = probability, na.rm = TRUE),
      kurtosis_gdp = DescTools::Kurt(strike, w = probability, na.rm = TRUE),
      variance_gdp = sum(probability * (strike - (sum(probability * strike) / sum(probability)))^2, na.rm = TRUE) / sum(probability, na.rm = TRUE),
      p25_gdp      = wtd.quantile(strike, weights = probability, probs = 0.25, na.rm = TRUE),
      p75_gdp      = wtd.quantile(strike, weights = probability, probs = 0.75, na.rm = TRUE),
      prob_below_1five_gdp = sum(probability[strike < 1.5], na.rm = TRUE),
      prob_below_0_gdp = sum(probability[strike == 0.1], na.rm = TRUE),
      
      .groups = "drop"
    ) %>% select(-contract_preamble)
  
  end_of_year_cpi_moments <- end_of_year_cpi %>%
    group_by(date, contract_preamble, expiry_date) %>%
    summarise(
      mean_cpi     = sum(probability * strike, na.rm = TRUE) / sum(probability, na.rm = TRUE),
      median_cpi   = weightedMedian(strike, w = probability, na.rm = TRUE, interpolate = FALSE),
      mode_cpi     = fmode(strike, w = probability, na.rm = TRUE, ties = 'first'),
      skewness_cpi = weightedGMSkew(strike, w = probability, na.rm = TRUE),
      kurtosis_cpi = DescTools::Kurt(strike, w = probability, na.rm = TRUE),
      variance_cpi = sum(probability * (strike - (sum(probability * strike) / sum(probability)))^2, na.rm = TRUE) / sum(probability, na.rm = TRUE),
      p25_cpi      = wtd.quantile(strike, weights = probability, probs = 0.25, na.rm = TRUE),
      p75_cpi      = wtd.quantile(strike, weights = probability, probs = 0.75, na.rm = TRUE),
      prob_above_3_cpi = sum(probability[strike > 3], na.rm = TRUE),
      prob_above_4_cpi = sum(probability[strike > 4], na.rm = TRUE),
      .groups = "drop"
    ) %>% select(-contract_preamble)
  
  
  # spf data
  dates_gdp <- c('2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', 
             '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13')
  
  dates_gdpd <- c('2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11', '2025-02-11',
                 '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13', '2025-05-13')
  
  
  gdp_strikes <- c(9, 8, 6.3, 4.7, 3.2, 2, .7, -.7, -2.3, -4.1, -5.1,
                   9, 8, 6.3, 4.7, 3.2, 2, .7, -.7, -2.3, -4.1, -5.1)
  
  gdp_data <- c(0.06, 0.03, 0.18, 3.72, 31.29, 44.80, 14.36, 4.83, 0.53, 0.1, 0.1,
                0,    0,    0.1,  1.08, 11.4,  35.69, 37.59, 12.8, 1.16, 0.11, 0.07)
  
  gdpd_strikes <- c(4, 3.7, 3.2, 2.7, 2.2, 1.7, 1.2, 0.7, 0.2, 0,
                    4, 3.7, 3.2, 2.7, 2.2, 1.7, 1.2, 0.7, 0.2, 0)
  
  gdpd_data <- c(1.69, 2.73, 10.98, 26.46, 39.13, 13.67, 3.47, 0.97, 0.34, 0.55,
                 3.68, 14.06, 27.66, 29.35, 19.11, 4.33, 1.26, 0.46, 0.04, 0.04)
  
  gdp_data <- data.frame(dates_gdp, gdp_strikes, gdp_data) %>% group_by(dates_gdp) %>% 
    summarize(prob_below_1five_gdp_spf = sum(gdp_data[gdp_strikes < 1.5], na.rm = TRUE),
              prob_below_0_gdp_spf = sum(gdp_data[gdp_strikes < .1], na.rm = TRUE), .groups = "drop") %>% rename(date = dates_gdp)
  
  gdpd_data <- data.frame(dates_gdpd, gdpd_strikes, gdpd_data) %>% group_by(dates_gdpd) %>% 
    summarize(prob_above_3_gdpd_spf = sum(gdpd_data[gdpd_strikes > 3], na.rm = TRUE),
              prob_above_4_gdpd_spf = sum(gdpd_data[gdpd_strikes > 3.9], na.rm = TRUE), .groups = "drop") %>% rename(date = dates_gdpd)
  
  # Merge our moments for the two 
  data <- inner_join(end_of_year_cpi_moments, end_of_year_gdp_moments, by='date')
  data <- full_join(data, gdp_data, by='date')
  data <- full_join(data, gdpd_data, by='date')
  
  
  
  return(data)
}

# Plot timeseries of modal cpi and gdp expectations using data in base R
plot_cpi_expectations <- function(data) {
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$mean_cpi,
    type = "l",
    col = "red",
    lwd = 2,
    ylim = range(c(2, 4), na.rm = TRUE),
    xlab = "Date",
    ylab = "Expectation (level)",
    main = "",
    axes = F
  )

  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_cpi <- c(2.5, 2.7, 2.9, 3.3, 3.2, 3, 2.9)
  
  bchip <- data.frame(date, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_cpi, col='red', bg = 'red', pch = 4, cex = 1.2)
  
  mtext("2025 expectations", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  
  # Add legend
  legend("topright",
         legend = c("Kalshi mean CPI", 'Blue Chip mean CPI'),
         col = c("red"),
         lty = c(1, NA),
         pch = c(NA, 4),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
}

plot_gdp_expectations <- function(data) {
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$mean_gdp,
    type = "l",
    col = "blue",
    lwd = 2,
    ylim = range(c(1, 2.5), na.rm = TRUE),
    xlab = "Date",
    ylab = "",
    main = "",
    axes = F
  )
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_gdp <- c(2.2, 2.2, 2, 1.4, 1.2, 1.4, 1.4)
  
  bchip <- data.frame(date, bchip_gdp) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_gdp, col='blue', bg = 'blue', pch = 4, cex = 1.2)
  
  
  # Add legend
  legend("topright",
         legend = c("Kalshi mean GDP", "Blue Chip mean GDP"),
         col = c("blue"),
         lty = c(1, NA),
         pch = c(NA, 4),
         lwd = 2,
         bty = "n", 
         cex = legend.cex)
}

plot_stagflation <- function(data) {
  
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$prob_below_1five_gdp,
    type = "l",
    col = "blue",
    lwd = 2,
    ylim = range(0, 85),
    xlab = "Date",
    ylab = "Probability",
    axes = F
  )
  
  lines(data$date, data$prob_above_3_cpi, col='red')
  
  # lines(data$date, data$prob_above_3_cpi * data$prob_below_1five_gdp / 100, col='purple')
  
  # Add points for SPF
  spf_data <- data %>% filter(!is.na(prob_above_3_gdpd_spf))
  points(spf_data$date, spf_data$prob_above_3_gdpd_spf, col = 'black', bg = 'red', pch=23)
  points(spf_data$date, spf_data$prob_below_1five_gdp_spf, col = 'black', bg = 'blue', pch=23)
  
  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
                   '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_gdp <- c(0, 0, 6.52, 41.3, 76.6, 50, 41.3)
  # bchip_cpi <- c(6.38, 8.69, 40, 80, 76.1, 59.57, 35.55)
  bchip_cpi <- c(4.25, 6.52, 24.4, 66.6, 67.4, 42.55, 15.5)
  
  bchip <- data.frame(date, bchip_gdp, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_gdp, col = 'blue', bg = 'blue', pch = 4)
  points(bchip$date, bchip$bchip_cpi, col='red', bg = 'red', pch = 4)
  
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add title
  mtext("Stagflation", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  
  # Add legend
  legend("topleft",
         legend = c("Prob GDP < 1.5", "Prob CPI > 3", "Prob GDP < 1.5 (SPF)", "Prob GDP Deflator > 3 (SPF)", "Prob GDP < 1.5 (BChip)", "Prob CPI > 3 (BChip)"),
         col = c("blue", "red", "black", 'black', "blue", 'red'),
         pch = c(NA,NA, 23,23, 4, 4),
         pt.bg = c(NA, NA, "blue", 'red', "blue", 'red'),
         lty = c(1, 1, NA, NA, NA, NA),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
  
}

plot_stagflation_tail <- function(data) {
  
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$prob_below_0_gdp,
    type = "l",
    col = "blue",
    lwd = 2,
    ylim = range(0, 50),
    xlab = "Date",
    ylab = "Probability",
    axes = F
  )
  
  lines(data$date, data$prob_above_4_cpi, col='red')
  
  # lines(data$date, data$prob_above_4_cpi * data$prob_below_0_gdp / 100, col='purple')
  
  # Add SPF Data
  spf_data <- data %>% filter(!is.na(prob_above_4_gdpd_spf))
  points(spf_data$date, spf_data$prob_above_4_gdpd_spf, col = 'black', bg = 'red', pch=23)
  points(spf_data$date, spf_data$prob_below_0_gdp_spf, col = 'black', bg = 'blue', pch=23)
  
  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_gdp <- c(0, 0, 0, 4.34, 6.38, 0, 0)
  bchip_cpi <- c(0, 0, 2.22, 8.88, 4.34, 0, 0)
  
  bchip <- data.frame(date, bchip_gdp, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_gdp, col = 'blue', bg = 'blue', pch = 4)
  points(bchip$date, bchip$bchip_cpi, col='red', bg = 'red', pch = 4)
  
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add title
  mtext("Severe stagflation", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  

  # Add legend
  legend("topleft",
         legend = c("Prob GDP < 0", "Prob CPI > 4", "Prob GDP < 0 (SPF)", "Prob GDP Deflator > 4 (SPF)", "Prob GDP < 0 (BChip)", "Prob CPI > 4 (BChip)"),
         col = c("blue", "red", "black", 'black', "blue", 'red'),
         pch = c(NA,NA, 23, 23, 23, 23),
         pt.bg = c(NA, NA, "blue", 'red', "blue", 'red'),
         lty = c(1, 1, NA, NA, NA, NA),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
  
}



plot_gdp <- function(data) {
  
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$prob_below_1five_gdp,
    type = "l",
    col = "blue",
    lwd = 2,
    ylim = range(0, 85),
    xlab = "Date",
    ylab = "",
    axes = F
  )
  
  # lines(data$date, data$prob_above_3_cpi * data$prob_below_1five_gdp / 100, col='purple')
  
  # Add points for SPF
  spf_data <- data %>% filter(!is.na(prob_above_3_gdpd_spf))
  points(spf_data$date, spf_data$prob_below_1five_gdp_spf, col = 'black', bg = 'blue', pch=23)
  
  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_gdp <- c(0, 0, 6.52, 41.3, 76.6, 50, 41.3)
  # bchip_cpi <- c(6.38, 8.69, 40, 80, 76.1, 59.57, 35.55)
  bchip_cpi <- c(4.25, 6.52, 24.4, 66.6, 67.4, 42.55, 15.5)
  
  bchip <- data.frame(date, bchip_gdp, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_gdp, col='blue', bg = 'blue', pch = 4)
  
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add title
  # mtext("Stagflation", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  
  # Add legend
  legend("bottomright",
         legend = c("Prob GDP < 1.5", "Prob GDP < 1.5 (SPF)", "% of modal E[GDP] < 1.5 (BChip)"),
         col = c("blue", "black",  "blue"),
         pch = c(NA, 23, 4),
         pt.bg = c(NA, "blue", "blue"),
         lty = c(1, NA, NA),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
  
}

plot_cpi <- function(data) {
  
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$prob_above_3_cpi,
    type = "l",
    col = "red",
    lwd = 2,
    ylim = range(0, 85),
    xlab = "Date",
    ylab = "Probability",
    axes = F
  )
  

  # lines(data$date, data$prob_above_3_cpi * data$prob_below_1five_gdp / 100, col='purple')
  
  # Add points for SPF
  spf_data <- data %>% filter(!is.na(prob_above_3_gdpd_spf))
  points(spf_data$date, spf_data$prob_above_3_gdpd_spf, col = 'black', bg = 'red', pch=23)

  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_gdp <- c(0, 0, 6.52, 41.3, 76.6, 50, 41.3)
  # bchip_cpi <- c(6.38, 8.69, 40, 80, 76.1, 59.57, 35.55)
  bchip_cpi <- c(4.25, 6.52, 24.4, 66.6, 67.4, 42.55, 15.5)
  
  bchip <- data.frame(date, bchip_gdp, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_cpi, col='red', bg = 'red', pch = 4)
  
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add title
  mtext("Stagflation", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  
  # Add legend
  legend("bottom",
         legend = c("Prob CPI > 3", "Prob GDP Deflator > 3 (SPF)", "% of modal E[CPI] > 3 (BChip)"),
         col = c("red", "black", 'red'),
         pch = c(NA, 23, 4),
         pt.bg = c(NA, 'red', 'red'),
         lty = c(1, NA, NA),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
  
}

plot_gdp_tail <- function(data) {
  
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$prob_below_0_gdp,
    type = "l",
    col = "blue",
    lwd = 2,
    ylim = range(0, 55),
    xlab = "Date",
    ylab = "Probability",
    axes = F
  )
  
  # lines(data$date, data$prob_above_4_cpi * data$prob_below_0_gdp / 100, col='purple')
  
  # Add SPF Data
  spf_data <- data %>% filter(!is.na(prob_above_4_gdpd_spf))
  points(spf_data$date, spf_data$prob_below_0_gdp_spf, col = 'black', bg = 'blue', pch=23)
  
  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_gdp <- c(0, 0, 0, 4.34, 6.38, 0, 0)
  bchip_cpi <- c(0, 0, 2.22, 8.88, 4.34, 0, 0)
  
  bchip <- data.frame(date, bchip_gdp, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_gdp, col = 'blue', bg = 'blue', pch = 4)
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add title
  mtext("Severe stagflation", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  
  
  # Add legend
  legend("topleft",
         legend = c("Prob GDP < 0", "Prob GDP < 0 (SPF)", "% of modal E[GDP] < 0 (BChip)"),
         col = c("blue", 'black', "blue"),
         pch = c(NA, 23, 4),
         pt.bg = c(NA, "blue", "blue"),
         lty = c(1, NA, NA),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
  
}

plot_gdp_tail <- function(data) {
  
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$prob_below_0_gdp,
    type = "l",
    col = "blue",
    lwd = 2,
    ylim = range(0, 55),
    xlab = "Date",
    ylab = "",
    axes = F
  )
  
  # lines(data$date, data$prob_above_4_cpi * data$prob_below_0_gdp / 100, col='purple')
  
  # Add SPF Data
  spf_data <- data %>% filter(!is.na(prob_above_4_gdpd_spf))
  points(spf_data$date, spf_data$prob_below_0_gdp_spf, col = 'black', bg = 'blue', pch=23)
  
  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_gdp <- c(0, 0, 0, 4.34, 6.38, 0, 0)
  bchip_cpi <- c(0, 0, 2.22, 8.88, 4.34, 0, 0)
  
  bchip <- data.frame(date, bchip_gdp, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_gdp, col = 'blue', bg = 'blue', pch = 4)
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add title
  # mtext("Severe stagflation", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  
  
  # Add legend
  legend("topleft",
         legend = c("Prob GDP < 0", "Prob GDP < 0 (SPF)", "% of modal E[GDP] < 0 (BChip)"),
         col = c("blue", 'black', "blue"),
         pch = c(NA, 23, 4),
         pt.bg = c(NA, "blue", "blue"),
         lty = c(1, NA, NA),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
  
}


plot_cpi_tail <- function(data) {
  
  # Convert date to Date class if it's not already
  data$date <- as.Date(data$date)
  
  # Set up plotting area
  plot(
    data$date, data$prob_above_4_cpi,
    type = "l",
    col = "red",
    lwd = 2,
    ylim = range(0, 50),
    xlab = "Date",
    ylab = "Probability",
    axes = F
  )
  

  # Add SPF Data
  spf_data <- data %>% filter(!is.na(prob_above_4_gdpd_spf))
  points(spf_data$date, spf_data$prob_above_4_gdpd_spf, col = 'black', bg = 'red', pch=23)

  
  # Add points for Blue Chip
  date <- c('2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01',
            '2025-05-01', '2025-06-01', '2025-07-01')
  
  bchip_cpi <- c(0, 0, 2.22, 8.88, 4.34, 0, 0)
  
  bchip <- data.frame(date, bchip_cpi) %>% mutate(date = as.Date(date))
  points(bchip$date, bchip$bchip_cpi, col='red', bg = 'red', pch = 4)
  
  
  plotHookBox()
  
  # Add axis
  axis.Date(1, at = pretty(data$date), format = "%b.")  # x-axis
  axis(2, las = 1)  # y-axis
  
  # Add title
  mtext("Severe stagflation", side = 3, line = 1, adj = 0, font = 1, cex = title.cex)
  
  
  # Add legend
  legend("topleft",
         legend = c("Prob CPI > 4", "Prob GDP Deflator > 4 (SPF)", "% of modal E[CPI] > 4 (BChip)"),
         col = c("red", "black", 'red'),
         pch = c(NA, 23, 4),
         pt.bg = c(NA, 'red', 'red'),
         lty = c(1, NA, NA),
         lwd = 2,
         bty = "n",
         cex = legend.cex)
  
}


library(tidyverse)
library(Hmisc)
library(lubridate)
library(matrixStats)
library(collapse)
source('~/Documents/Research/Utilities/utilities.R')

setwd('~/Documents/Research/PredictionMarketsPublic')

data <- load_data()


pdf('output/stagflation.pdf', width = 8.5, height = 11)


setPar()
par(fig=c(0, 0.53, .65, 1))
plot_cpi_expectations(data)

setPar()
par(fig=c(0.47, 1, .65, 1), new=T)
plot_gdp_expectations(data)

setPar()
par(fig=c(0, 0.7, .6, 1), new=F)
plot_stagflation(data)

setPar()
par(fig=c(0.47 , 1, .3, 0.65), new=T)
plot_stagflation_tail(data)

setPar()
par(fig=c(0, 0.53, .65, 1), new=F)
plot_cpi(data)

setPar()
par(fig=c(0.47 , 1, .65, 1), new=T)
plot_gdp(data)

setPar()
par(fig=c(0, 0.53, .3, 0.65), new=T)
plot_cpi_tail(data)

setPar()
par(fig=c(0.47 , 1, .3, 0.65), new=T)
plot_gdp_tail(data)


dev.off()

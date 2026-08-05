# exhibit.R
# library(np)

library(lubridate)
library(tis)
library(tidyverse)
library(data.table)
library(reshape2)
library(zoo)
library(DBI)
library(xts)
library(grid)
library(gridExtra)
library(gridBase)
library(dplyr)

library(timeDate)
library(writexl)


setwd("~/Documents/Research/PredictionMarketsReplication/")

source("code/utilities.R")
setPar()


pdf(file="output/comparison_charts.pdf", width=8.5, height=11)

# Margins for stamped version on website
margins.inch=c(0.5, .5, 0.5, 0.5)
par(oma=c(2.5, 3, 1.2, 4.5), mar=margins.inch, mgp=c(1, .25, 0))

pos = list(
  TOPLEFT=c(0, .49, .678, 1),
  TOPRIGHT=c(.51, 1, .676, 1),
  TOPLEFT2=c(0, .5, .69, 1),
  TOPLEFT3=c(0, .5, .69, 1),
  TOP = c(0, 1, 0.6, 1),
  TOPRIGHT2=c(.5, 1, .69, 1),
  MIDLEFT=c(0, .49, .332, .66),
  MIDRIGHT=c(.51, 1, .332, .66),
  MIDLEFT2=c(0.0, .5, .325, .65),
  MIDRIGHT2=c(.5, 1, .325, .65),
  BOTLEFT=c(0, .49, 0, .3125),
  BOTRIGHT=c(.51, 1, 0, .3125),
  BOTLEFT2=c(0.25, .75, 0, .312),
  BOTRIGHT2=c(.5, 1, 0, .312),
  BOTTOM=c(0, 1, 0, .315),
  CENTERBOTTOM = c(0.25, 0.75, 0, 0.3),
  CENTERMID = c(0.25, 0.75, 0.325, 0.65))

#################################
# PAGE 1-- FFR Errors over time #
#################################

 source("code/analysis/bid_ask_v_trade/information_arrival_ffr.R")
 df <- load_data() # load all of the data we need to make our FFR charts.

 par(fig=pos$TOP, new=FALSE)
 chart_average_errors(df)
 
#################################
# PAGE 2-- CPI Errors over time #
################################

# source('code/comparison_charts/information_arrival_cpi.R')
# df <- load_data()
# 
# reset()
# par(fig=pos$TOP, new=FALSE)
# chart_average_errors(df)


#########################################
# PAGE 2-- Unemployment Errors over time #
##########################################

# source('code/comparison_charts/information_arrival_unemployment.R')
# df <- load_data()
# 
# reset()
# par(fig=pos$TOP, new=FALSE)
# chart_average_errors(df)

dev.off()


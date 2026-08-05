# Draws the FRB-style box around R plots, including the long top tick mark

plotHookBox <- function(col = 'black', lwd = par('lwd')) {
  
  
  lines(grconvertX(c(0.05, 0, 0, 1, 1, 0.95), "npc", "user"),
        grconvertY(c(1,1,0,0,1,1), "npc", "user"),
        col=col, lwd=lwd, xpd = TRUE)
  
}


setPar <- function() {
  
  par(tck = -0.02)  # Negative value: ticks point inward
  
}

title.cex <- 1.5
legend.cex <- 0.7

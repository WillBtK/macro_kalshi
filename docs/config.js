// Supabase connection for the front-end.
//
// Both values below are *publishable* — they are meant to live in client-side
// code. The anon key only grants what your Row-Level-Security policies allow
// (here: SELECT on the derived public tables). The database password is NOT
// here and must never be put in front-end code.
//
// If you ever recreate the Supabase project, update these two values.
window.MK_CONFIG = {
  SUPABASE_URL: "https://nidqyfcutlzylxhnkkrl.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5pZHF5ZmN1dGx6eWx4aG5ra3JsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5Mzk2NDUsImV4cCI6MjEwMTUxNTY0NX0.k4hprFQ1d8c9NOETWCfZyGFTug9BveRDzmYf2C4-8OY",

  // Display labels + axis units for each series key (matches series_config.py).
  // `spec` is a plain-English summary of what the Kalshi contract resolves to.
  // GDP is verified from the KXGDPYEAR rules; the others are best-effort
  // summaries — adjust to the exact market rules if needed.
  SERIES_META: {
    fed_levels:                {label: "Fed Funds target (midpoint)", unit: "%", axis: "Target midpoint (%)",
      spec: "Resolves to the FOMC target range for the labelled meeting. The strike is the range's lower bound; the plotted mean/median/mode are the range midpoint."},
    headline_cpi_releases:     {label: "Headline CPI (YoY)",       unit: "%",   axis: "YoY (%)",
      spec: "Resolves to the year-over-year change in headline CPI-U for the labelled release month."},
    core_cpi_releases:         {label: "Core CPI (YoY)",           unit: "%",   axis: "YoY (%)",
      spec: "Resolves to the year-over-year change in core CPI-U (ex food & energy) for the labelled release month."},
    headline_cpi_releases_mom: {label: "Headline CPI (MoM)",       unit: "%",   axis: "MoM (%)",
      spec: "Resolves to the seasonally-adjusted month-over-month change in headline CPI-U for the labelled release month."},
    headline_cpi_end_of_year:  {label: "Headline CPI, end-of-year",unit: "%",   axis: "YoY (%)",
      spec: "Resolves to the year-over-year (annual) headline CPI inflation for the labelled year."},
    gdp_end_of_year:           {label: "GDP, end-of-year",         unit: "%",   axis: "Real GDP (% ann.)",
      spec: "Resolves to the BEA advance estimate of annual real GDP growth for the labelled year (annual-average basis: prior-year annual level to current-year annual level, not Q4/Q4). The realized line uses the latest revised BEA annual figure."},
    unemployment_releases:     {label: "Unemployment rate",        unit: "%",   axis: "Rate (%)",
      spec: "Resolves to the U-3 unemployment rate for the labelled release month."},
    nonfarm_payrolls:          {label: "Nonfarm payrolls (m/m)",   unit: "k",   axis: "Jobs added (thousands, m/m)",
      spec: "Resolves to the monthly change in total nonfarm payroll employment for the labelled release month. Kalshi lists strikes in absolute jobs; values here are in thousands (e.g. 150 = +150,000) to match the FRED realized change."},
    gdp_quarterly:             {label: "Real GDP (q/q SAAR)",      unit: "%",   axis: "Real GDP q/q SAAR (%)",
      spec: "Resolves to the seasonally-adjusted annualised quarter-over-quarter real GDP growth rate for the labelled quarter (the BEA advance estimate). Contracts are dated by their release/quarter-end date; the label shows the quarter they resolve to."},
  },
};

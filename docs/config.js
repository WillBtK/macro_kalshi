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
  SERIES_META: {
    fed_levels:                {label: "Fed Funds target (midpoint)", unit: "%", axis: "Target midpoint (%)"},
    headline_cpi_releases:     {label: "Headline CPI (YoY)",       unit: "%",   axis: "YoY (%)"},
    core_cpi_releases:         {label: "Core CPI (YoY)",           unit: "%",   axis: "YoY (%)"},
    headline_cpi_releases_mom: {label: "Headline CPI (MoM)",       unit: "%",   axis: "MoM (%)"},
    headline_cpi_end_of_year:  {label: "Headline CPI, end-of-year",unit: "%",   axis: "YoY (%)"},
    gdp_end_of_year:           {label: "GDP, end-of-year",         unit: "%",   axis: "Real GDP (% ann.)"},
    unemployment_releases:     {label: "Unemployment rate",        unit: "%",   axis: "Rate (%)"},
  },
};

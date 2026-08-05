# Self-hosting notes — macro_kalshi

This repo is a self-hosted fork of
[`jdkatz21/Prediction_Markets_Public`](https://github.com/jdkatz21/Prediction_Markets_Public),
the replication package for *Diercks, Katz, Wright (2026), "Kalshi and the Rise of
Macro Markets"* (NBER WP 34702).

These notes document the pipeline, the changes made for self-hosting, and the
known limitations. They are the data-layer reference for later work (query layer
and front-end).

## Pipeline overview (scrape → convert → output)

1. **Ticker discovery** — `code/kalshi_scraping/tickers.py :: autogenerate_kalshi_tickers(series)`
   queries Kalshi's **public** (unauthenticated) endpoints — `/events`,
   `/historical/markets`, `/markets` — to build the list of per-strike market
   tickers for each economic series (FFR levels `KXFED`, CPI YoY `KXCPIYOY`, core
   CPI `KXCPICOREYOY`, CPI MoM `KXCPI`, annual CPI `KXACPI`, annual GDP
   `KXGDPYEAR`, unemployment `KXU3`).

2. **Trade scrape** — `code/kalshi_scraping/scrape_kalshi_trades.py` loops the
   tickers and calls `KalshiHttpClient.get_all_trades_for_ticker` (in
   `clients_kalshi.py`), which pulls from **both** `/historical/trades` and
   `/markets/trades`, dedupes on `trade_id`, sorts by time, and writes one CSV per
   series to `data/trade_level_data/`. This step is **authenticated** (RSA-signed
   requests). Raw columns: `trade_id, ticker, count, created_time,
   yes_price_dollars, no_price_dollars, taker_side`.

3. **Conversion** — `Rscript code/convert_trades_to_pdfs/data_convert_runner.R`
   runs `extract_distributions()` per series: last-trade (or VWAP) daily
   aggregation → fill missing days → impose no-arbitrage monotonic CDF
   ("middle-out") → difference into a probability mass function → compute moments.

### Outputs (verified schema)

Run against synthetic data in this environment to confirm the schema (real data
requires credentials + network access to Kalshi — see limitations):

- `data/daily_moments_data/daily_moments_<series>.csv`
  `date, contract_preamble, expiry_date, daily_volume, mean, median, mode, skewness, kurtosis, variance`

- `data/daily_distribution_data/daily_distributions_<series>.csv` (long)
  `contract_preamble, date, expiry_date, strike, yes_price, daily_volume, adjusted_yes_price, probability, swapped`
  (`swapped` is an internal working flag from the arbitrage-cleaning loop; it is
  harmless but currently leaks into the file.)

- `data/daily_distribution_data/wide/daily_distributions_<series>.csv` (wide, used by the website)
  `date, contract_preamble, volume, <one column per strike = probability mass>`

`data/` and `output/` are git-ignored, so **no data is committed to the repo** —
persistence is entirely external (see the GitHub Action / S3 note below).

## Credentials setup

Get an API key from the Kalshi developer portal (https://docs.kalshi.com/welcome):
you receive a **Key ID** and download an **RSA private key** (`.pem`).

- **Local runs:** copy `env.env.example` → `env.env` (git-ignored) and set
  `KALSHI_KEYID` plus either `KALSHI_KEYFILE` (path to the `.pem`) or
  `KALSHI_PRIVATE_KEY` (inline PEM).
- **GitHub Action:** add repo secrets `KALSHI_KEYID` and `KALSHI_PRIVATE_KEY`
  (paste the full PEM). **Do not** paste the private key into chat or commit it.

## Changes made for self-hosting

- **Fixed a run-blocking bug:** both R converters
  (`convert_trade_level_data_cdfs.R`, `convert_trade_level_data_pdfs.R`)
  referenced an undefined `count_fp` in daily aggregation. The raw feed provides
  `count`; added `count_fp = as.numeric(count)` in each `read_data()`. Without
  this the R step errors with `object 'count_fp' not found`.
- **Robust credential loading** in `scrape_kalshi_trades.py`: loads `env.env`
  when present (local), supports both inline PEM and a key file, and raises clear
  errors if credentials are missing (previously it only worked inside GitHub
  Actions and crashed cryptically otherwise).
- Added `env.env.example` template.

## Known limitations & decisions to make

### March 2026 Kalshi API change — how far back we can pull
Kalshi split trade access into **historical** (`/historical/trades`) and **live**
(`/markets/trades`) endpoints. The code already pulls both, but the upstream
README warns historical access is limited (noted as ~**100 days** currently) and
that the authors are still developing a full-history method. **Implication:** a
fresh scrape today cannot reconstruct the multi-year dataset from the paper —
only roughly the last ~100 days plus live. The full historical series exists only
in the authors' published data (their S3 bucket). Confirm the exact cutoff at run
time via `KalshiHttpClient.get_historical_cutoff()` (`/historical/cutoff`).

### The weekly GitHub Action — adapt, don't keep as-is
`.github/workflows/daily-data.yml` (cron `5 17 * * 5`, Fridays 17:05 UTC)
scrapes → converts → `aws s3 sync` to the **authors'** bucket
`s3://kalshi-and-the-rise-of-macro-markets/`, and the reference website
(`docs/index.html`, econfutures.com) reads CSVs **directly** from that public
bucket. For self-hosting this must change: point it at **our own** storage
(our S3 bucket + our `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` secrets) or a
different persistence target (e.g. commit derived CSVs to the repo, or push to
whatever store the future front-end reads). The schedule/steps are otherwise fine
to keep.

### This sandbox cannot reach Kalshi or CRAN
The Claude Code web environment's egress policy blocks `api.elections.kalshi.com`
and CRAN/Posit (403). So the **live scrape and the real end-to-end run must
happen on GitHub Actions runners or a local machine**, not in an interactive web
session. (`DescTools` — one R dependency — is unavailable via apt and comes from
CRAN; the Action installs it fine.)

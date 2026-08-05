"""
scrape_kalshi_trades.py

Author: Anthony M. Diercks, Jared Dean Katz
Affiliation: Federal Reserve Board of Governors, Northwestern University Kellogg School of Businesss
Contact: jared.katz@kellogg.northwestern.edu
Date: July 2025

Description:
-------------
This script uses the Kalshi API to download and archive trades related to 
economic markets. I have given examples for downloading Federal Funds Rate,
FOMC Decisions, CPI releases, CPI Annual Percentages, Payrolls, and probability
of recession annual data at trade levels.
 
It is designed for researchers to be able to obtain current
prediction market data. See convert_trades_to_pdfs for information on how we
propose cleaning the trade-level data into statistical probability density
functions and moments.

Usage:
------

Requires a valid Kalshi API key, set via environment variable:
    export KALSHI_KEYID="your_key_id_here" and
    export KALSHI_KEYFILE='key.txt' OR
    
    define env.env to contain both environment variables
    
key.txt in the project root directory hould contain the Kalshi API key

Dependencies:
-------------
- Python 3.8+
- Kalshi API


License & Citation:
--------------------
This script is distributed under the MIT License (see LICENSE file).
If you use this script or data collected with it in published work,
please cite:
    
Diercks, Katz, Wright (2026) 

with use.

Disclaimer:
-----------
This is academic software provided "as is", without warranty of any kind.
Use at your own risk and verify data with official sources where appropriate.

Reproducibility:
----------------

Run on Macbook M1 in Conda Spyder environment.

"""

##################################
##     Package Installation     ##
##################################


# Loads required libraries
import os
import sys
import time
import pandas as pd
from dotenv import load_dotenv
from cryptography.hazmat.primitives import serialization

# Set path according to your own computer directory
# os.chdir('/Users/jaredkatz/Documents/Research/PredictionMarketsReplication')
# sys.path.append('code/kalshi_scraping')

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

# import the file that lets us connect to the Kalshi API client
from clients_kalshi import KalshiHttpClient, KalshiWebSocketClient, Environment


##################################
## Connecting to the Kalshi API ##
##################################

env = Environment.PROD

# Load credentials from env.env for local development if present. In GitHub
# Actions the secrets are already injected as environment variables, so the
# file simply won't exist and this is a no-op.
if os.path.exists("env.env"):
    load_dotenv("env.env")

KEYID = os.getenv("KALSHI_KEYID")
PRIVATE_KEY_STR = os.getenv("KALSHI_PRIVATE_KEY")   # inline PEM (used by GitHub Actions)
KEYFILE = os.getenv("KALSHI_KEYFILE")               # path to a PEM file (convenient locally)

if not KEYID:
    raise RuntimeError(
        "KALSHI_KEYID is not set. Provide it via env.env or an environment variable."
    )

# Prefer an inline PEM string; otherwise fall back to reading the key file.
if PRIVATE_KEY_STR:
    private_key = serialization.load_pem_private_key(
        PRIVATE_KEY_STR.encode(), password=None
    )
elif KEYFILE:
    with open(KEYFILE, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)
else:
    raise RuntimeError(
        "No private key found. Set KALSHI_PRIVATE_KEY (inline PEM) or "
        "KALSHI_KEYFILE (path to a PEM file) via env.env or the environment."
    )

# Initialize the HTTP client
client = KalshiHttpClient(
    key_id=KEYID,
    private_key=private_key,
    environment=env
)



##################################
## Selecting the Kalshi tickers ##
##################################

"""
Kalshi defines a unique ticker for each binary market. That means for each
unique event, there are many different tickers for all of the binary options.
To get information on the most updated markets, visit Kalshi's website to view
the tickers.

Currently, you can get a ticker for a market by clicking on the market on the
webpage, scrolling down and clicking 'timeline and payout' and then seeing
the 'ticker' defined.

Tickers tend to follow similar patterns from event to event, but there are
often slight changes, and the api is very sensitive to small typos/differences
in requested tickers. If you are missing data, check to make sure you are 
searching for the exact ticker! As a result, it's generally impractical to
look through to create ticker names...

"""

import tickers # download tickers given a tag of interest


##################################
##     Downloading the data     ##
##################################

"""
OUTDATED-- used to scrape all trades, but following April 2026 split between historical/live data
it now only returns live trades. Please use scrape_kalshi() instead if interested in getting
historical data.
# loop through each ticker and get all the trades, append to the bottom of a pandas df
# Kalshi uses pagination in their API, so we loop through pages while the pages
# remain full to get each trade on the market. At each page, we get the 
# cursor so we can continue on the next page

Inputs:
        - output_filename: location the csv of all trade data is stored
        - tickers: the list of tickers you want the trade data for
"""

# def scrape_kalshi_live(output_filename, tickers):

#     results = pd.DataFrame(columns=['trade_id', 'ticker', 'count', 
#                                     'created_time', 'yes_price_dollars', 'no_price_dollars', 
#                                     'taker_side'])
#     for ticker in tickers:
        
#         print(f"Fetching: {ticker}")
        
#         # get the trades on the first page, append to df and hold the cursor
#         trades = client.get_trades(ticker=ticker)
#         page_df = pd.DataFrame(trades['trades'])
#         print(f"First page rows: {len(page_df)}")
        
#         results = pd.concat([results, page_df], ignore_index=True)
#         cursor = trades.get('cursor')
    
#         page = 1
        
#         # for each page, get the trades and append to our df, get the new cursor
#         # when we hit the end, cursor will turn null and we'll exit the loop
#         while cursor:
            
#             print(f"  Page {page} cursor: {cursor}")
#             trades = client.get_trades(ticker=ticker, cursor=cursor)
#             page_df = pd.DataFrame(trades['trades'])
            
#             print(f"  Page {page} rows: {len(page_df)}")
#             results = pd.concat([results, page_df], ignore_index=True)
            
#             cursor = trades.get('cursor')
#             page += 1
    
#         time.sleep(1) # pause for a second after each market to avoid rate limits
        
#     # Save the csv to output_filename
#     results.to_csv(output_filename)


def scrape_kalshi(output_filename: str, tickers: list):
    """Scrape full trade history for a list of tickers and save to CSV."""
    all_results = []

    for ticker in tickers:
        print(f"Fetching: {ticker}")
        ticker_df = client.get_all_trades_for_ticker(ticker)
        print(f"  Total rows: {len(ticker_df)}")
        all_results.append(ticker_df)
        time.sleep(1)

    results = pd.concat(all_results, ignore_index=True)
    results.to_csv(output_filename, index=False)
    print(f"Saved {len(results)} total trades to {output_filename}")

##################################
##       Getting the data       ##
##################################

# Autogenerate the tickers using Kalshi's API
levels_tickers = tickers.autogenerate_kalshi_tickers('KXFED')
decisions_tickers = tickers.autogenerate_kalshi_tickers('KXFEDDECISION')
cpi_tickers = tickers.autogenerate_kalshi_tickers('KXCPIYOY')
cpi_end_of_year_tickers = tickers.autogenerate_kalshi_tickers('KXACPI')
core_cpi_tickers = tickers.autogenerate_kalshi_tickers('KXCPICOREYOY')
gdp_end_of_year_tickers = tickers.autogenerate_kalshi_tickers('KXGDPYEAR')
payrolls_tickers = tickers.autogenerate_kalshi_tickers('KXPAYROLLS')
unemployment_tickers = tickers.autogenerate_kalshi_tickers('KXU3')
cpi_tickers_mom = tickers.autogenerate_kalshi_tickers('KXCPI')

scrape_kalshi('data/trade_level_data/trade_level_data_fed_levels.csv', levels_tickers)

# scrape_kalshi('data/trade_level_data/trade_level_data_fed_decisions.csv', decisions_tickers)

scrape_kalshi('data/trade_level_data/trade_level_data_headline_cpi_releases.csv', cpi_tickers)

scrape_kalshi('data/trade_level_data/trade_level_data_headline_cpi_end_of_year.csv', cpi_end_of_year_tickers)

scrape_kalshi('data/trade_level_data/trade_level_data_core_cpi_releases.csv', core_cpi_tickers)

scrape_kalshi('data/trade_level_data/trade_level_data_headline_cpi_releases_mom.csv', cpi_tickers_mom)

scrape_kalshi('data/trade_level_data/trade_level_data_gdp_end_of_year.csv', gdp_end_of_year_tickers)

# scrape_kalshi('data/trade_level_data/trade_level_data_payrolls.csv', payrolls_tickers)

scrape_kalshi('data/trade_level_data/trade_level_data_unemployment.csv', unemployment_tickers)


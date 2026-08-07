"""
scrape_orderbook.py

Quote-based (bid/ask) counterpart to the trade scrape. For each quote-eligible
series, discover its markets and pull Kalshi's DAILY candlesticks — which carry
yes_bid / yes_ask OHLC per strike per day, present even on days with no trades —
then write one CSV per series in the exact schema convert_bid_ask_data_cdfs.R
reads (read_bid_ask). This lets the pipeline derive a market-implied distribution
from the live order-book midpoint across strikes, not only from executed trades.

Public (unauthenticated) Kalshi endpoints only — no credentials. Run from the
repo root. The daily-data workflow runs this on a GitHub Actions runner (which
can reach Kalshi); egress-restricted sandboxes will 403.
"""

import csv
import datetime as dt
import os
import sys
import time

import requests

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

import tickers as tickers_mod
from series_config import SERIES, QUOTE_SERIES, ORDERBOOK_DIR

BASE = "https://api.elections.kalshi.com/trade-api/v2"
PERIOD = 1440  # daily candles
START_TS = int(dt.datetime(2022, 1, 1, tzinfo=dt.timezone.utc).timestamp())

# Column order matches what read_bid_ask() in convert_bid_ask_data_cdfs.R expects
# (the original orderbook_scraping.py output), so the R side finds every column.
FIELDS = [
    "series", "event_ticker", "market_ticker", "end_period_utc",
    "yes_bid_open", "yes_bid_high", "yes_bid_low", "yes_bid_close",
    "yes_ask_open", "yes_ask_high", "yes_ask_low", "yes_ask_close",
    "price_open", "price_high", "price_low", "price_close",
    "volume", "open_interest",
]


def fetch_candles(series_ticker, market_ticker, end_ts):
    """Daily candlesticks for one market, with light retry/backoff."""
    url = "{}/series/{}/markets/{}/candlesticks".format(BASE, series_ticker, market_ticker)
    params = {"start_ts": START_TS, "end_ts": end_ts, "period_interval": PERIOD}
    for attempt in range(4):
        try:
            r = requests.get(url, params=params, timeout=30)
            if r.status_code == 429 or r.status_code >= 500:
                time.sleep(2 ** attempt)
                continue
            r.raise_for_status()
            return r.json().get("candlesticks", []) or []
        except requests.RequestException:
            time.sleep(2 ** attempt)
    return []


def ohlc(candle, side):
    """Return (open, high, low, close) for a candle side, tolerating gaps."""
    d = candle.get(side) or {}
    return d.get("open"), d.get("high"), d.get("low"), d.get("close")


def main():
    end_ts = int(dt.datetime.now(dt.timezone.utc).timestamp())
    os.makedirs(ORDERBOOK_DIR, exist_ok=True)
    by_key = {s["key"]: s for s in SERIES}
    for key in QUOTE_SERIES:
        s = by_key.get(key)
        if not s:
            print("{}: not in SERIES; skipping".format(key))
            continue
        series_ticker = s["ticker"]
        try:
            markets = tickers_mod.discover_markets(series_ticker)
        except Exception as e:  # noqa: BLE001
            print("{}: market discovery failed ({}); skipping".format(key, e))
            continue
        rows = []
        for m in markets:
            tk = m.get("ticker")
            if not tk:
                continue
            for c in fetch_candles(series_ticker, tk, end_ts):
                ts = c.get("end_period_ts")
                if ts is None:
                    continue
                bo, bh, bl, bc = ohlc(c, "yes_bid")
                ao, ah, al, ac = ohlc(c, "yes_ask")
                po, ph, pl, pc = ohlc(c, "price")
                rows.append({
                    "series": series_ticker,
                    "event_ticker": "",
                    "market_ticker": tk,
                    "end_period_utc": dt.datetime.utcfromtimestamp(ts).isoformat() + "Z",
                    "yes_bid_open": bo, "yes_bid_high": bh, "yes_bid_low": bl, "yes_bid_close": bc,
                    "yes_ask_open": ao, "yes_ask_high": ah, "yes_ask_low": al, "yes_ask_close": ac,
                    "price_open": po, "price_high": ph, "price_low": pl, "price_close": pc,
                    "volume": c.get("volume"),
                    "open_interest": c.get("open_interest"),
                })
            time.sleep(0.2)
        out = os.path.join(ORDERBOOK_DIR, "orderbook_{}.csv".format(key))
        with open(out, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=FIELDS)
            w.writeheader()
            w.writerows(rows)
        print("{}: {} candlestick rows from {} markets -> {}".format(key, len(rows), len(markets), out))
    print("Order-book scrape complete.")


if __name__ == "__main__":
    main()

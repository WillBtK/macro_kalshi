"""
scrape_orderbook.py

Quote-based (bid/ask) counterpart to the trade scrape. For each quote-eligible
series, discover its markets and pull Kalshi's DAILY candlesticks — which carry
yes_bid / yes_ask OHLC per strike per day, present even on days with no trades —
then write one CSV per series in the exact schema convert_bid_ask_data_cdfs.R
reads (read_bid_ask). This lets the pipeline derive a market-implied distribution
from the live order-book midpoint across strikes, not only from executed trades.

Public (unauthenticated) Kalshi endpoints only — no credentials. Run from the
repo root. Kalshi rate-limits aggressively, so this scrapes only RECENT / open
markets (older expired contracts' quote history is static and not needed for the
live views) and enforces an overall wall-clock budget so it can never stall the
daily pipeline. The daily-data workflow runs it AFTER the trade pipeline, so even
a slow/failed order-book scrape can't delay trade data.
"""

import csv
import datetime as dt
import os
import sys
import time

import requests
from cryptography.hazmat.primitives import serialization

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

import tickers as tickers_mod
from series_config import SERIES, QUOTE_SERIES, ORDERBOOK_DIR
from clients_kalshi import KalshiHttpClient, Environment

BASE = "https://api.elections.kalshi.com/trade-api/v2"


def make_client():
    """Authenticated Kalshi client. Bid/ask (order-book) candlestick data is only
    returned to AUTHENTICATED requests — unauthenticated calls return null
    yes_bid/yes_ask — so the order-book scrape must sign its requests, exactly
    like the trades scrape. Reuses the same KALSHI_KEYID / KALSHI_PRIVATE_KEY."""
    key_id = os.getenv("KALSHI_KEYID")
    pem = os.getenv("KALSHI_PRIVATE_KEY")
    keyfile = os.getenv("KALSHI_KEYFILE")
    if not key_id:
        raise RuntimeError("KALSHI_KEYID is not set (order-book bid/ask needs auth).")
    if pem:
        private_key = serialization.load_pem_private_key(pem.encode(), password=None)
    elif keyfile:
        with open(keyfile, "rb") as f:
            private_key = serialization.load_pem_private_key(f.read(), password=None)
    else:
        raise RuntimeError("Set KALSHI_PRIVATE_KEY (inline PEM) or KALSHI_KEYFILE.")
    return KalshiHttpClient(key_id=key_id, private_key=private_key, environment=Environment.PROD)
PERIOD = 1440  # daily candles
# Only pull recent candles — the quote views show recent dates, and a shorter
# window means far fewer candles per market (faster transfer, smaller payload).
START_TS = int((dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=200)).timestamp())

# Only scrape markets that closed within this window (or are still open). Older
# expired contracts don't change and aren't shown in the live quote views. Kept
# tight so the whole scrape completes well inside the wall-clock budget.
RECENT_DAYS = 90
# Hard wall-clock budget for the whole scrape; on exceeding it we write what we
# have and stop, logging the truncation (never a silent cap).
MAX_SECONDS = 1500
CALL_SLEEP = 0.1  # polite delay between candlestick calls

FIELDS = [
    "series", "event_ticker", "market_ticker", "end_period_utc",
    "yes_bid_open", "yes_bid_high", "yes_bid_low", "yes_bid_close",
    "yes_ask_open", "yes_ask_high", "yes_ask_low", "yes_ask_close",
    "price_open", "price_high", "price_low", "price_close",
    "volume", "open_interest",
]


def _ts(iso):
    if not iso:
        return None
    try:
        return dt.datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp()
    except Exception:  # noqa: BLE001
        return None


def is_recent(m, cutoff_ts):
    """Keep open markets (no/blank close) and those that closed after the cutoff."""
    t = _ts(m.get("close_time"))
    return (t is None) or (t >= cutoff_ts)


def fetch_candles(client, series_ticker, market_ticker, end_ts):
    """Daily candlesticks (with yes_bid / yes_ask OHLC) for one market, via the
    AUTHENTICATED client. The client handles rate-limiting and retry/backoff."""
    path = "/trade-api/v2/series/{}/markets/{}/candlesticks".format(series_ticker, market_ticker)
    params = {"start_ts": START_TS, "end_ts": end_ts, "period_interval": PERIOD}
    try:
        return client.get(path, params=params).get("candlesticks", []) or []
    except Exception:  # noqa: BLE001
        return []


def _cents(v):
    """Kalshi now returns candlestick prices as *_dollars strings ('0.0100'). The
    R converter expects cents, so scale dollars -> cents (0-100)."""
    if v is None or v == "":
        return None
    try:
        return round(float(v) * 100, 4)
    except (TypeError, ValueError):
        return None


def ohlc(candle, side):
    """OHLC for one side, handling Kalshi's current schema (open_dollars/…) with a
    fallback to the legacy integer-cent keys (open/…) if the API reverts."""
    d = candle.get(side) or {}
    if any(k in d for k in ("open_dollars", "close_dollars", "high_dollars", "low_dollars")):
        return (_cents(d.get("open_dollars")), _cents(d.get("high_dollars")),
                _cents(d.get("low_dollars")), _cents(d.get("close_dollars")))
    return d.get("open"), d.get("high"), d.get("low"), d.get("close")


def _fp(v):
    if v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def main():
    started = time.monotonic()
    end_ts = int(dt.datetime.now(dt.timezone.utc).timestamp())
    cutoff_ts = end_ts - RECENT_DAYS * 86400
    os.makedirs(ORDERBOOK_DIR, exist_ok=True)
    client = make_client()
    by_key = {s["key"]: s for s in SERIES}
    truncated = False
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
        recent = [m for m in markets if is_recent(m, cutoff_ts)]
        rows = []
        scanned = 0
        for m in recent:
            if time.monotonic() - started > MAX_SECONDS:
                truncated = True
                break
            tk = m.get("ticker")
            if not tk:
                continue
            scanned += 1
            for c in fetch_candles(client, series_ticker, tk, end_ts):
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
                    "volume": _fp(c.get("volume_fp", c.get("volume"))),
                    "open_interest": _fp(c.get("open_interest_fp", c.get("open_interest"))),
                })
            time.sleep(CALL_SLEEP)
        out = os.path.join(ORDERBOOK_DIR, "orderbook_{}.csv".format(key))
        with open(out, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=FIELDS)
            w.writeheader()
            w.writerows(rows)
        print("{}: {} candlestick rows from {}/{} recent markets ({} total) -> {}".format(
            key, len(rows), scanned, len(recent), len(markets), out))
        if truncated:
            print("WARNING: wall-clock budget ({}s) hit; order-book scrape truncated at series {}.".format(MAX_SECONDS, key))
            break
    print("Order-book scrape complete.")


if __name__ == "__main__":
    main()

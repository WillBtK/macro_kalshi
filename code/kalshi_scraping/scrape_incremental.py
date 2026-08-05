"""
scrape_incremental.py

Incremental trade scrape into Postgres, then export per-series CSVs for the R
conversion.

Per series:
  * If the DB has no trades yet  -> full history seed via
    get_all_trades_for_ticker (historical + live endpoints).
  * Otherwise -> pull only trades newer than the latest stored created_time
    (min_ts on the live /markets/trades endpoint) for each ticker.
Ticker discovery (autogenerate_kalshi_tickers) runs every time so newly-listed
markets (new CPI months, FOMC meetings, ...) are picked up.

New trades are upserted (dedupe on trade_id), then every series is exported to
data/trade_level_data/<file>.csv for the unchanged R pipeline.

Env: KALSHI_KEYID + (KALSHI_PRIVATE_KEY | KALSHI_KEYFILE), SUPABASE_DB_URL.
"""

import os
import sys
import time

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

from dotenv import load_dotenv
from cryptography.hazmat.primitives import serialization

from clients_kalshi import KalshiHttpClient, Environment
import tickers as tickers_mod
import db
from series_config import SERIES, TRADES_DIR

if os.path.exists("env.env"):
    load_dotenv("env.env")

KEYID = os.getenv("KALSHI_KEYID")
PRIVATE_KEY_STR = os.getenv("KALSHI_PRIVATE_KEY")
KEYFILE = os.getenv("KALSHI_KEYFILE")
if not KEYID:
    raise RuntimeError("KALSHI_KEYID is not set.")
if PRIVATE_KEY_STR:
    private_key = serialization.load_pem_private_key(PRIVATE_KEY_STR.encode(), password=None)
elif KEYFILE:
    with open(KEYFILE, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)
else:
    raise RuntimeError("Set KALSHI_PRIVATE_KEY (inline PEM) or KALSHI_KEYFILE (path).")

client = KalshiHttpClient(key_id=KEYID, private_key=private_key, environment=Environment.PROD)

# small overlap (seconds) so a boundary trade is never skipped; trade_id dedupes
OVERLAP_SECONDS = 5


def fetch_since(ticker, min_ts):
    """All live trades for a ticker with created_time >= min_ts (epoch s)."""
    out = []
    resp = client.get_trades(ticker=ticker, min_ts=min_ts)
    out.extend(resp.get("trades", []))
    cursor = resp.get("cursor")
    while cursor:
        resp = client.get_trades(ticker=ticker, min_ts=min_ts, cursor=cursor)
        out.extend(resp.get("trades", []))
        cursor = resp.get("cursor")
    return out


def seed_full(ticker):
    """Full history for a ticker (both endpoints) as a list of dicts."""
    df = client.get_all_trades_for_ticker(ticker)
    if df is None or df.empty:
        return []
    return df.to_dict("records")


def main():
    conn = db.connect()
    db.ensure_schema(conn)
    print("Schema ready.")

    for s in SERIES:
        key, series_ticker = s["key"], s["ticker"]
        print(f"\n=== {key} ({series_ticker}) ===")
        try:
            tickers = tickers_mod.autogenerate_kalshi_tickers(series_ticker)
        except Exception as e:
            print(f"  ticker discovery failed: {e}; skipping series")
            continue
        print(f"  {len(tickers)} tickers")

        hwm = db.latest_created_time(conn, key)
        incremental = hwm is not None
        min_ts = int(hwm.timestamp()) - OVERLAP_SECONDS if incremental else None
        print(f"  mode: {'incremental since ' + hwm.isoformat() if incremental else 'full seed'}")

        added = 0
        for t in tickers:
            try:
                rows = fetch_since(t, min_ts) if incremental else seed_full(t)
            except Exception as e:
                print(f"    {t}: fetch error {e}; skipping ticker")
                continue
            added += db.upsert_trades(conn, key, rows)
            time.sleep(0.2 if incremental else 1.0)
        print(f"  upserted {added} new trades")

        # export full series history to the CSV the R conversion reads
        out_path = os.path.join(TRADES_DIR, s["trades"])
        n = db.export_trades_csv(conn, key, out_path)
        print(f"  exported {n} rows -> {out_path}")

    conn.close()
    print("\nIncremental scrape + export complete.")


if __name__ == "__main__":
    main()

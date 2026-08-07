"""
probe_candles.py — one-off diagnostic.

The order-book scrape produced candles whose OHLC fields (price / yes_bid /
yes_ask / volume) are all null, so the quote pipeline loads nothing. This prints
the RAW shape of what Kalshi returns for a near-term active market, so we can see
the actual JSON keys (authenticated) and fix the parser. Also probes the
orderbook endpoint as an alternative bid/ask source. No writes.
"""

import datetime as dt
import json
import os
import sys

import requests
from cryptography.hazmat.primitives import serialization

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))
from clients_kalshi import KalshiHttpClient, Environment  # noqa: E402

BASE = "https://api.elections.kalshi.com/trade-api/v2"


def make_client():
    key_id = os.getenv("KALSHI_KEYID")
    pem = os.getenv("KALSHI_PRIVATE_KEY")
    private_key = serialization.load_pem_private_key(pem.encode(), password=None)
    return KalshiHttpClient(key_id=key_id, private_key=private_key, environment=Environment.PROD)


def main():
    client = make_client()
    # find a near-term ACTIVE CPI market (liquid, so quotes should exist)
    r = requests.get(BASE + "/markets", params={"series_ticker": "KXCPIYOY", "limit": 1000}, timeout=30).json()
    act = [m for m in r.get("markets", []) if m.get("status") == "active"]
    act.sort(key=lambda m: str(m.get("close_time")))
    if not act:
        print("no active KXCPIYOY markets"); return
    m = act[0]
    tk = m["ticker"]
    print("probe market:", tk, "| close:", m.get("close_time"))

    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    for interval in (1440, 60):
        path = "/trade-api/v2/series/{}/markets/{}/candlesticks".format("KXCPIYOY", tk)
        params = {"start_ts": now - 30 * 86400, "end_ts": now, "period_interval": interval}
        try:
            j = client.get(path, params=params)
            cs = j.get("candlesticks", [])
            print("\n=== candlesticks interval={} : {} candles ===".format(interval, len(cs)))
            if cs:
                print("keys of a candle:", sorted(cs[-1].keys()))
                print("LAST candle:", json.dumps(cs[-1])[:900])
                # find a candle with any non-null nested value
                for c in reversed(cs):
                    if any(isinstance(c.get(k), dict) and any(v is not None for v in c[k].values())
                           for k in ("price", "yes_bid", "yes_ask")):
                        print("first populated candle:", json.dumps(c)[:900]); break
        except Exception as e:  # noqa: BLE001
            print("candlesticks interval={} failed: {}".format(interval, e))

    # alternative: the live orderbook endpoint (top of book)
    try:
        ob = client.get("/trade-api/v2/markets/{}/orderbook".format(tk))
        print("\n=== orderbook ===")
        print(json.dumps(ob)[:900])
    except Exception as e:  # noqa: BLE001
        print("orderbook failed:", e)


if __name__ == "__main__":
    main()

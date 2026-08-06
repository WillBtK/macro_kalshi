"""
fetch_fred.py

Pull each indicator's realised underlying series from FRED and store it in
Postgres (underlying_history) for the front-end to overlay against the
market-implied forecasts.

Env: FRED_API_KEY, SUPABASE_DB_URL / SUPABASE_DB_PASSWORD.
Run from the repo root, any time (independent of the Kalshi scrape).
"""

import os
import sys
import time

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

import requests
import db
from series_config import SERIES

FRED_URL = "https://api.stlouisfed.org/fred/series/observations"


def fetch_one(fred_id, units, api_key):
    """Return list of (date_str, float_value) for a single FRED series, dropping gaps."""
    params = {
        "series_id": fred_id,
        "api_key": api_key,
        "file_type": "json",
        "units": units,               # lin / pc1 / pch
        "observation_start": "2020-01-01",
    }
    out = []
    for attempt in range(4):
        try:
            r = requests.get(FRED_URL, params=params, timeout=30)
            r.raise_for_status()
            for o in r.json().get("observations", []):
                v = o.get("value")
                if v in (None, "", "."):
                    continue
                try:
                    out.append((o["date"], float(v)))
                except ValueError:
                    continue
            return out
        except Exception as e:
            if attempt == 3:
                raise
            print(f"  FRED {fred_id} error: {e}; retrying...")
            time.sleep(2 ** attempt)
    return out


def fetch_series(f, api_key):
    """Fetch a series' realised values. If `id2` is given, return the per-date
    average of the two series (used for the Fed target-range midpoint)."""
    base = fetch_one(f["id"], f["units"], api_key)
    if not f.get("id2"):
        return base
    other = dict(fetch_one(f["id2"], f["units"], api_key))
    return [(d, (v + other[d]) / 2.0) for d, v in base if d in other]


def main():
    api_key = os.getenv("FRED_API_KEY")
    if not api_key:
        raise RuntimeError("FRED_API_KEY is not set.")
    conn = db.connect()
    db.ensure_schema(conn)
    for s in SERIES:
        f = s.get("fred")
        if not f:
            continue
        try:
            rows = fetch_series(f, api_key)
        except Exception as e:
            print(f"{s['key']}: FRED fetch failed ({e}); skipping")
            continue
        db.replace_underlying(conn, s["key"], rows)
        src = f["id"] + (f"+{f['id2']}/2" if f.get("id2") else "")
        print(f"{s['key']}: {len(rows)} obs from FRED {src} ({f['units']})")
        time.sleep(0.3)
    conn.close()
    print("FRED collection complete.")


if __name__ == "__main__":
    main()

"""
discover_series.py

Look up Kalshi's exact series ticker(s) for a keyword, using the public
(unauthenticated) /series endpoint — cheaper and more reliable than guessing a
ticker naming pattern. Prints ticker, title, and category for every match.

Reusable whenever adding a new series to the pipeline (more macro variables,
midterms, French elections, etc.) — run it first to get the real ticker before
touching series_config.py.

Run:  python code/kalshi_scraping/discover_series.py <keyword> [<keyword> ...]
"""

import sys

import requests

BASE = "https://api.elections.kalshi.com/trade-api/v2"


def fetch_all_series():
    out, cursor = [], None
    for _ in range(50):
        params = {"limit": 200}
        if cursor:
            params["cursor"] = cursor
        r = requests.get(BASE + "/series", params=params, timeout=30)
        r.raise_for_status()
        j = r.json()
        out.extend(j.get("series", []) or [])
        cursor = j.get("cursor") or None
        if not cursor:
            break
    return out


def main():
    keywords = [k.lower() for k in sys.argv[1:]] or ["pce"]
    series = fetch_all_series()
    print(f"Fetched {len(series)} total series from Kalshi.\n")
    for kw in keywords:
        print(f"=== matches for '{kw}' ===")
        hits = [s for s in series
                if kw in str(s.get("title", "")).lower() or kw in str(s.get("ticker", "")).lower()]
        if not hits:
            print("  (no matches)")
        for s in hits:
            print(f"  {s.get('ticker'):<20} {s.get('title')!r:<50} category={s.get('category')}")
        print()


if __name__ == "__main__":
    main()

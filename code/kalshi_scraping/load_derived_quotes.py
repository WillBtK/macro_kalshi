"""
load_derived_quotes.py

Load the quote-based (bid/ask) derived CSVs into the *_quotes Postgres tables the
front-end reads for its "Quotes" source. Mirrors load_derived.py and replaces
each series in full. Only the quote-eligible series are loaded; a missing file is
skipped (e.g. a series whose order-book scrape found nothing yet).

Env: SUPABASE_DB_URL / SUPABASE_DB_PASSWORD.
"""

import os
import sys

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

import db
from series_config import SERIES, QUOTE_SERIES, BA_MOMENTS_DIR, BA_DIST_DIR
from load_derived import load_moments, load_distributions


def main():
    conn = db.connect()
    db.ensure_schema(conn)
    by_key = {s["key"]: s for s in SERIES}
    for key in QUOTE_SERIES:
        s = by_key.get(key)
        if not s:
            continue
        mpath = os.path.join(BA_MOMENTS_DIR, s["moments"])
        dpath = os.path.join(BA_DIST_DIR, s["dist"])
        if os.path.exists(mpath):
            mrows = load_moments(mpath)
            db.replace_quote_moments(conn, key, mrows)
            print(f"{key}: {len(mrows)} quote moment rows")
        else:
            print(f"{key}: no quote moments file at {mpath}, skipping")
        if os.path.exists(dpath):
            drows = load_distributions(dpath)
            db.replace_quote_distributions(conn, key, drows)
            print(f"{key}: {len(drows)} quote distribution rows")
        else:
            print(f"{key}: no quote distribution file at {dpath}, skipping")
    conn.close()
    print("Quote derived load complete.")


if __name__ == "__main__":
    main()

"""
load_derived.py

After the R conversion writes derived CSVs, load them into Postgres. The derived
tables are replaced per-series (R recomputes full history each run), so they
always mirror the latest computation. Run from the repo root after
data_convert_runner.R.

Env: SUPABASE_DB_URL.
"""

import os
import sys
import csv

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

import db
from series_config import SERIES, MOMENTS_DIR, DIST_DIR


def num(v):
    try:
        if v is None or v == "" or v == "NA":
            return None
        return float(v)
    except (TypeError, ValueError):
        return None


def load_moments(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append((
                r["contract_preamble"], r["date"], r.get("expiry_date") or None,
                num(r.get("daily_volume")), num(r.get("mean")), num(r.get("median")),
                num(r.get("mode")), num(r.get("skewness")), num(r.get("kurtosis")),
                num(r.get("variance")),
            ))
    return rows


def load_distributions(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append((
                r["contract_preamble"], r["date"], r.get("expiry_date") or None,
                num(r.get("strike")), num(r.get("probability")), num(r.get("yes_price")),
                num(r.get("adjusted_yes_price")), num(r.get("daily_volume")),
            ))
    return rows


def main():
    conn = db.connect()
    db.ensure_schema(conn)
    for s in SERIES:
        key = s["key"]
        mpath = os.path.join(MOMENTS_DIR, s["moments"])
        dpath = os.path.join(DIST_DIR, s["dist"])
        if os.path.exists(mpath):
            mrows = load_moments(mpath)
            db.replace_moments(conn, key, mrows)
            print(f"{key}: {len(mrows)} moment rows")
        else:
            print(f"{key}: no moments file at {mpath}, skipping")
        if os.path.exists(dpath):
            drows = load_distributions(dpath)
            db.replace_distributions(conn, key, drows)
            print(f"{key}: {len(drows)} distribution rows")
        else:
            print(f"{key}: no distribution file at {dpath}, skipping")
    conn.close()
    print("Derived load complete.")


if __name__ == "__main__":
    main()

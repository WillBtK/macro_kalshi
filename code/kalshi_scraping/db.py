"""
db.py

Postgres (Supabase) access layer for the macro_kalshi pipeline.

- `connect()` opens a connection from the SUPABASE_DB_URL environment variable.
- `ensure_schema()` creates the tables, indexes, and read policies if absent
  (idempotent — safe to run every time; no manual SQL needed).
- helpers to upsert raw trades, read the per-series high-water mark, export a
  series' trades to the CSV layout the R conversion expects, and replace the
  derived moments / distributions for a series.

Raw `trades` are append-only (dedupe on trade_id). The derived tables are
recomputed in full by R each run, so we replace-by-series rather than upsert —
that guarantees they mirror the latest computation with no stale rows.
"""

import os
import csv
from urllib.parse import urlsplit
import psycopg2
from psycopg2.extras import execute_values

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS trades (
    trade_id           TEXT PRIMARY KEY,
    series             TEXT NOT NULL,
    ticker             TEXT NOT NULL,
    created_time       TIMESTAMPTZ NOT NULL,
    count_fp           DOUBLE PRECISION,
    yes_price_dollars  DOUBLE PRECISION,
    no_price_dollars   DOUBLE PRECISION,
    taker_side         TEXT
);
CREATE INDEX IF NOT EXISTS trades_series_time_idx ON trades (series, created_time DESC);

CREATE TABLE IF NOT EXISTS daily_moments (
    series             TEXT NOT NULL,
    contract_preamble  TEXT NOT NULL,
    date               DATE NOT NULL,
    expiry_date        DATE,
    daily_volume       DOUBLE PRECISION,
    mean               DOUBLE PRECISION,
    median             DOUBLE PRECISION,
    mode               DOUBLE PRECISION,
    skewness           DOUBLE PRECISION,
    kurtosis           DOUBLE PRECISION,
    variance           DOUBLE PRECISION,
    PRIMARY KEY (series, contract_preamble, date)
);

CREATE TABLE IF NOT EXISTS daily_distributions (
    series             TEXT NOT NULL,
    contract_preamble  TEXT NOT NULL,
    date               DATE NOT NULL,
    expiry_date        DATE,
    strike             DOUBLE PRECISION NOT NULL,
    probability        DOUBLE PRECISION,
    yes_price          DOUBLE PRECISION,
    adjusted_yes_price DOUBLE PRECISION,
    daily_volume       DOUBLE PRECISION,
    PRIMARY KEY (series, contract_preamble, date, strike)
);
"""

# Expose the derived tables (public market data) read-only to the Supabase
# anon/authenticated roles so the front-end can query them via PostgREST. Raw
# trades stay private. Wrapped in DO blocks so re-runs and the absence of the
# Supabase roles (e.g. a non-Supabase Postgres) don't error.
POLICY_SQL = """
DO $$
BEGIN
  EXECUTE 'ALTER TABLE daily_moments ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE daily_distributions ENABLE ROW LEVEL SECURITY';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='daily_moments' AND policyname='public_read') THEN
    EXECUTE 'CREATE POLICY public_read ON daily_moments FOR SELECT USING (true)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='daily_distributions' AND policyname='public_read') THEN
    EXECUTE 'CREATE POLICY public_read ON daily_distributions FOR SELECT USING (true)';
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  EXECUTE 'GRANT SELECT ON daily_moments, daily_distributions TO anon, authenticated';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
"""


def connect():
    url = os.getenv("SUPABASE_DB_URL")
    if not url:
        raise RuntimeError("SUPABASE_DB_URL is not set (add it as a repo secret / env var).")
    # Parse the URL ourselves and pass fields as keyword args so that special
    # characters in the password (%, spaces, @, ...) are treated literally
    # rather than being percent-decoded by libpq's URL parser.
    p = urlsplit(url)
    if p.scheme in ("postgres", "postgresql") and p.hostname:
        # A dedicated SUPABASE_DB_PASSWORD secret (raw password, no URL syntax)
        # takes precedence over the password embedded in the URL — this avoids
        # URL-transcription mistakes. Host/user/dbname still come from the URL.
        pw_secret = os.getenv("SUPABASE_DB_PASSWORD")
        raw = pw_secret if pw_secret else p.password
        # Strip stray whitespace/newlines that often sneak into pasted secrets.
        pw = raw.strip() if raw else raw
        # Diagnostic (no secret leaked): confirms host/user, the password source,
        # and whether whitespace was trimmed (raw vs stripped length).
        print(f"DB connect -> host={p.hostname} port={p.port or 5432} "
              f"user={p.username!r} dbname={(p.path or '/postgres').lstrip('/') or 'postgres'} "
              f"password_len={len(raw or '')} stripped_len={len(pw or '')} "
              f"pw_source={'SUPABASE_DB_PASSWORD' if pw_secret else 'url'}")
        conn = psycopg2.connect(
            host=p.hostname,
            port=p.port or 5432,
            user=p.username,
            password=pw,
            dbname=(p.path or "/postgres").lstrip("/") or "postgres",
            sslmode="require",
            connect_timeout=30,
        )
    else:
        # Not a URL (e.g. a libpq keyword/value DSN) — pass through unchanged.
        conn = psycopg2.connect(url, connect_timeout=30)
    conn.autocommit = False
    return conn


def ensure_schema(conn):
    with conn.cursor() as cur:
        cur.execute(SCHEMA_SQL)
        cur.execute(POLICY_SQL)
    conn.commit()


def latest_created_time(conn, series):
    """Return the newest stored trade time for a series, or None if empty."""
    with conn.cursor() as cur:
        cur.execute("SELECT max(created_time) FROM trades WHERE series = %s", (series,))
        return cur.fetchone()[0]


def upsert_trades(conn, series, rows):
    """rows: list of dicts with keys trade_id, ticker, created_time, count_fp,
    yes_price_dollars, no_price_dollars, taker_side. Dedupes on trade_id."""
    if not rows:
        return 0
    vals = [(
        r.get("trade_id"), series, r.get("ticker"), r.get("created_time"),
        _num(r.get("count_fp", r.get("count"))),
        _num(r.get("yes_price_dollars")), _num(r.get("no_price_dollars")),
        r.get("taker_side"),
    ) for r in rows if r.get("trade_id")]
    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO trades
              (trade_id, series, ticker, created_time, count_fp,
               yes_price_dollars, no_price_dollars, taker_side)
            VALUES %s
            ON CONFLICT (trade_id) DO NOTHING
        """, vals, page_size=1000)
    conn.commit()
    return len(vals)


def export_trades_csv(conn, series, path):
    """Write a series' trades to `path` in the schema the R conversion reads.
    created_time is formatted to match R's '%Y-%m-%dT%H:%M:%OSZ'. Returns row count."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    n = 0
    with conn.cursor(name=f"exp_{series}") as cur, open(path, "w", newline="") as f:
        cur.itersize = 5000
        cur.execute("""
            SELECT trade_id, ticker, count_fp, yes_price_dollars, no_price_dollars,
                   taker_side,
                   to_char(created_time AT TIME ZONE 'UTC',
                           'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS created_time
            FROM trades WHERE series = %s
            ORDER BY ticker, created_time
        """, (series,))
        w = csv.writer(f)
        w.writerow(["trade_id", "ticker", "count_fp", "yes_price_dollars",
                    "no_price_dollars", "taker_side", "created_time"])
        for row in cur:
            w.writerow(row); n += 1
    return n


def replace_moments(conn, series, rows):
    """rows: list of tuples matching the daily_moments columns (minus series)."""
    with conn.cursor() as cur:
        cur.execute("DELETE FROM daily_moments WHERE series = %s", (series,))
        if rows:
            execute_values(cur, """
                INSERT INTO daily_moments
                  (series, contract_preamble, date, expiry_date, daily_volume,
                   mean, median, mode, skewness, kurtosis, variance)
                VALUES %s
            """, [(series,) + r for r in rows], page_size=1000)
    conn.commit()


def replace_distributions(conn, series, rows):
    """rows: list of tuples matching daily_distributions columns (minus series)."""
    with conn.cursor() as cur:
        cur.execute("DELETE FROM daily_distributions WHERE series = %s", (series,))
        if rows:
            execute_values(cur, """
                INSERT INTO daily_distributions
                  (series, contract_preamble, date, expiry_date, strike,
                   probability, yes_price, adjusted_yes_price, daily_volume)
                VALUES %s
            """, [(series,) + r for r in rows], page_size=2000)
    conn.commit()


def _num(v):
    try:
        if v is None or v == "" or v == "NA":
            return None
        return float(v)
    except (TypeError, ValueError):
        return None

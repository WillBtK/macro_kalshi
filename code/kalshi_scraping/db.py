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

CREATE TABLE IF NOT EXISTS underlying_history (
    series  TEXT NOT NULL,
    date    DATE NOT NULL,
    value   DOUBLE PRECISION,
    PRIMARY KEY (series, date)
);

-- Per-market metadata (the true close/expiration times from Kalshi), so the R
-- conversion can use real contract expiries instead of inferring them from the
-- last trade date. Private (not exposed to the anon role).
CREATE TABLE IF NOT EXISTS markets (
    ticker           TEXT PRIMARY KEY,
    series           TEXT,
    close_time       TIMESTAMPTZ,
    expiration_time  TIMESTAMPTZ
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
  EXECUTE 'ALTER TABLE underlying_history ENABLE ROW LEVEL SECURITY';
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
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='underlying_history' AND policyname='public_read') THEN
    EXECUTE 'CREATE POLICY public_read ON underlying_history FOR SELECT USING (true)';
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  EXECUTE 'GRANT SELECT ON daily_moments, daily_distributions, underlying_history TO anon, authenticated';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Per-contract true expiry, aggregated from the private markets table and
-- exposed read-only (the view runs with definer rights, so markets itself
-- stays private). The front-end uses this for days-to-release, the event
-- cadence, and the expiry marker — without touching the R moments pipeline.
DO $$
BEGIN
  EXECUTE 'CREATE OR REPLACE VIEW contract_expiry AS
    SELECT series,
           regexp_replace(ticker, ''-[^-]*$'', '''') AS contract_preamble,
           max((close_time AT TIME ZONE ''UTC'')::date) AS expiry
    FROM markets WHERE close_time IS NOT NULL
    GROUP BY series, regexp_replace(ticker, ''-[^-]*$'', '''')';
  EXECUTE 'GRANT SELECT ON contract_expiry TO anon, authenticated';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
"""


# Non-secret connection defaults for this Supabase project's Session pooler.
# (The host and username are not secrets — they appear in the project URL.)
# Only the password is secret (SUPABASE_DB_PASSWORD). Any of these can be
# overridden with an env var if the project is ever recreated.
DEFAULT_DB_HOST = "aws-0-ap-south-1.pooler.supabase.com"
DEFAULT_DB_USER = "postgres.nidqyfcutlzylxhnkkrl"
DEFAULT_DB_NAME = "postgres"
DEFAULT_DB_PORT = 5432


def connect():
    # Password is the ONLY required secret. Everything else has a working
    # default, so there is no connection URL to keep valid.
    host = os.getenv("SUPABASE_DB_HOST")
    user = os.getenv("SUPABASE_DB_USER")
    dbname = os.getenv("SUPABASE_DB_NAME")
    port = os.getenv("SUPABASE_DB_PORT")
    pw = os.getenv("SUPABASE_DB_PASSWORD")

    # If a full SUPABASE_DB_URL is provided and parseable, fill any gaps from it.
    url = os.getenv("SUPABASE_DB_URL")
    if url:
        p = urlsplit(url)
        if p.scheme in ("postgres", "postgresql") and p.hostname:
            host = host or p.hostname
            user = user or p.username
            dbname = dbname or ((p.path or "/postgres").lstrip("/") or "postgres")
            port = port or (p.port and str(p.port))
            pw = pw or p.password

    host = host or DEFAULT_DB_HOST
    user = user or DEFAULT_DB_USER
    dbname = dbname or DEFAULT_DB_NAME
    port = int(port) if port else DEFAULT_DB_PORT
    pw = pw.strip() if pw else pw
    if not pw:
        raise RuntimeError("Set SUPABASE_DB_PASSWORD (the database password).")

    # Diagnostic (no secret leaked).
    print(f"DB connect -> host={host} port={port} user={user!r} "
          f"dbname={dbname} password_len={len(pw)}")
    conn = psycopg2.connect(
        host=host, port=port, user=user, password=pw, dbname=dbname,
        sslmode="require", connect_timeout=30,
    )
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


def upsert_markets(conn, series, rows):
    """rows: list of dicts {ticker, close_time, expiration_time} (ISO8601 strings
    or None). Upserts market metadata; keeps a prior non-null time if a later
    payload omits it."""
    vals = [(r.get("ticker"), series, r.get("close_time"), r.get("expiration_time"))
            for r in rows if r.get("ticker")]
    if not vals:
        return 0
    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO markets (ticker, series, close_time, expiration_time)
            VALUES %s
            ON CONFLICT (ticker) DO UPDATE SET
              series          = EXCLUDED.series,
              close_time      = COALESCE(EXCLUDED.close_time, markets.close_time),
              expiration_time = COALESCE(EXCLUDED.expiration_time, markets.expiration_time)
        """, vals, page_size=1000)
    conn.commit()
    return len(vals)


def replace_underlying(conn, series, rows):
    """rows: list of (date, value). Replaces the realised history for a series."""
    with conn.cursor() as cur:
        cur.execute("DELETE FROM underlying_history WHERE series = %s", (series,))
        if rows:
            execute_values(cur, """
                INSERT INTO underlying_history (series, date, value) VALUES %s
            """, [(series, d, v) for d, v in rows], page_size=2000)
    conn.commit()


def _num(v):
    try:
        if v is None or v == "" or v == "NA":
            return None
        return float(v)
    except (TypeError, ValueError):
        return None

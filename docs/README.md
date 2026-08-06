# Front-end (GitHub Pages)

A static site that reads the derived data **live from Supabase** (PostgREST) in
the visitor's browser and plots the market-implied forward curves against the
realized outcome.

## Files
- `index.html` — the whole app (markup + styles + logic). Charts via Plotly (CDN).
- `config.js` — the Supabase **Project URL** and **anon public key**. Both are
  publishable (safe in client code); the anon key only grants what the
  Row-Level-Security policies allow (SELECT on the derived public tables).
  The database password is **never** here.

## What it shows
For a chosen series, a fan of **forward curves** — each thin line is the
market-implied path (mean / median / mode, selectable) across contract target
dates, priced as of a past date (today, then monthly or quarterly back) — over a
bold **realized** line pulled from FRED. A range slider controls how much history
is shown; the default view starts ~12 months before the earliest market data.

## Enable GitHub Pages
Once this is merged to `main`:
1. Repo **Settings → Pages**.
2. **Source: Deploy from a branch**.
3. Branch **`main`**, folder **`/docs`**, Save.

The site publishes at `https://willbtk.github.io/macro_kalshi/`.

## Data dependencies
Reads three tables, all exposed read-only to the `anon` role by the pipeline
(`db.py` policies): `daily_moments`, `daily_distributions`, `underlying_history`.
They are populated by the daily GitHub Action. If a series shows "no data yet",
the pipeline hasn't seeded it.

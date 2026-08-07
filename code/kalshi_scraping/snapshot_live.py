"""
snapshot_live.py

Compute the CURRENT market-implied distribution for every open threshold
contract from Kalshi's live bid/ask MIDPOINT across strikes (one instant per
run) and write it to Postgres (live_snapshot_dist / live_snapshot_moments). The
front-end's "Live now" button reads these tables directly via PostgREST, so no
browser-to-Kalshi call (blocked by CORS) and no Edge Function are needed.

Methodology mirrors the R pipeline and the (now optional) Edge Function:
  yes bid/ask midpoint per strike  ->  clean the complementary CDF (middle-out,
  anchored at the strike nearest the 49c median)  ->  difference into a PMF over
  bins  ->  moments (with the half-bin continuity correction on location moments).

Public (unauthenticated) Kalshi endpoints only. Whole-table replace each run, so
the snapshot always reflects the latest pull with no stale rows. Fast and light
(one markets page per series), so it can run on a short schedule.
"""

import datetime as dt
import os
import sys
import time

import requests

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))

import db  # noqa: E402

BASE = "https://api.elections.kalshi.com/trade-api/v2"

# key -> Kalshi ticker + strike grid, mirroring data_convert_runner.R and the
# Edge Function. `scale` maps Kalshi's raw strike units to display units
# (payrolls: 10-thousand grid stored as thousands); `strike_int` is in display
# units (used for the synthetic tail-bin positions and the continuity correction).
SERIES = {
    "fed_levels":                {"ticker": "KXFED",        "strike_int": 0.25, "scale": 1.0},
    "headline_cpi_releases":     {"ticker": "KXCPIYOY",     "strike_int": 0.1,  "scale": 1.0},
    "core_cpi_releases":         {"ticker": "KXCPICOREYOY", "strike_int": 0.1,  "scale": 1.0},
    "headline_cpi_releases_mom": {"ticker": "KXCPI",        "strike_int": 0.1,  "scale": 1.0},
    "unemployment_releases":     {"ticker": "KXU3",         "strike_int": 0.1,  "scale": 1.0},
    "gdp_quarterly":             {"ticker": "KXGDP",        "strike_int": 0.5,  "scale": 1.0},
    "nonfarm_payrolls":          {"ticker": "KXPAYROLLS",   "strike_int": 10.0, "scale": 0.001},
}


def _num(v):
    try:
        n = float(v)
        return n if n == n and n not in (float("inf"), float("-inf")) else None
    except (TypeError, ValueError):
        return None


def preamble(ticker):
    """contract_preamble = ticker minus the -T<strike> suffix (mirrors the R regex)."""
    i = ticker.rfind("-T")
    return ticker[:i] if i >= 0 else ticker


def parse_strike(ticker):
    """Strike from the -T suffix; leading N = negative (e.g. -TN0.5)."""
    i = ticker.rfind("-T")
    if i < 0:
        return None
    raw = ticker[i + 2:]
    if raw.startswith("N"):
        raw = "-" + raw[1:]
    return _num(raw)


def fetch_open_markets(series_ticker):
    out, cursor = [], None
    for _ in range(20):
        params = {"series_ticker": series_ticker, "limit": 1000, "status": "open"}
        if cursor:
            params["cursor"] = cursor
        r = requests.get(BASE + "/markets", params=params, timeout=20)
        r.raise_for_status()
        j = r.json()
        out.extend(j.get("markets") or [])
        cursor = j.get("cursor") or None
        if not cursor:
            break
    return out


def middle_out(prices):
    """Enforce a non-increasing-in-strike complementary CDF, anchored at the bin
    whose price is closest to 49c, cleaning outward in both directions."""
    n = len(prices)
    adj = list(prices)
    k, best = 0, float("inf")
    for i in range(n):
        d = abs(prices[i] - 49)
        if d < best:
            best, k = d, i
    run = adj[k]
    for i in range(k - 1, -1, -1):        # lower strikes must be priced >=
        run = max(run, prices[i])
        adj[i] = run
    run = adj[k]
    for i in range(k + 1, n):             # higher strikes must be priced <=
        run = min(run, prices[i])
        adj[i] = run
    return adj


def to_pmf(strikes, cdf, si):
    """Difference the cleaned complementary CDF into a PMF over bins: a synthetic
    below-lowest bin, the interior bins, and the top-tail bin. Renormalised to 100."""
    n = len(strikes)
    bins = [(strikes[0] - si, max(0.0, 100 - cdf[0]))]
    for i in range(n - 1):
        bins.append((strikes[i], max(0.0, cdf[i] - cdf[i + 1])))
    bins.append((strikes[n - 1], max(0.0, cdf[n - 1])))
    s = sum(p for _, p in bins) or 1.0
    return [(x, p * 100 / s) for x, p in bins]


def moments(bins, madj):
    sp = sum(p for _, p in bins) or 1.0
    mean = sum(p * x for x, p in bins) / sp
    variance = sum(p * (x - mean) ** 2 for x, p in bins) / sp
    ordered = sorted(bins, key=lambda b: b[0])
    cum, median = 0.0, ordered[0][0]
    for x, p in ordered:
        cum += p
        if cum >= sp / 2:
            median = x
            break
    mode = max(ordered, key=lambda b: b[1])[0]
    return {
        "mean": mean + madj, "median": median + madj, "mode": mode + madj,
        "sd": (max(0.0, variance)) ** 0.5,
    }


def snapshot_series(key, cfg, asof):
    """Return (dist_rows, mom_rows) for one series' open contracts."""
    markets = fetch_open_markets(cfg["ticker"])
    # group strikes by contract
    by_contract = {}
    for m in markets:
        tk = str(m.get("ticker") or "")
        if not tk:
            continue
        strike = parse_strike(tk)
        if strike is None:
            continue
        bid, ask = _num(m.get("yes_bid")), _num(m.get("yes_ask"))
        if bid is None and ask is None:
            continue
        mid = (bid + ask) / 2 if (bid is not None and ask is not None) else (bid if bid is not None else ask)
        if mid <= 1:            # normalize dollars -> cents if needed
            mid *= 100
        mid = min(100.0, max(0.0, mid))
        by_contract.setdefault(preamble(tk), []).append((strike * cfg["scale"], mid))

    dist_rows, mom_rows = [], []
    for contract, pts in by_contract.items():
        if len(pts) < 2:
            continue
        pts.sort(key=lambda p: p[0])
        strikes = [x for x, _ in pts]
        cdf = middle_out([c for _, c in pts])
        bins = to_pmf(strikes, cdf, cfg["strike_int"])
        mom = moments(bins, cfg["strike_int"] / 2)
        for x, p in bins:
            dist_rows.append((key, contract, asof, round(x, 6), round(p, 4)))
        mom_rows.append((key, contract, asof,
                         round(mom["mean"], 6), round(mom["median"], 6),
                         round(mom["mode"], 6), round(mom["sd"], 6), len(pts)))
    return dist_rows, mom_rows


def main():
    asof = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    all_dist, all_mom = [], []
    for key, cfg in SERIES.items():
        try:
            d, mo = snapshot_series(key, cfg, asof)
            all_dist.extend(d)
            all_mom.extend(mo)
            print("{}: {} contracts, {} dist rows".format(key, len(mo), len(d)))
        except Exception as e:  # noqa: BLE001
            print("{}: snapshot failed ({}); skipping".format(key, e))
        time.sleep(0.1)

    conn = db.connect()
    try:
        db.ensure_schema(conn)
        db.replace_live_snapshot(conn, all_dist, all_mom)
    finally:
        conn.close()
    print("Live snapshot written: {} contracts across {} series (asof {}).".format(
        len(all_mom), len(SERIES), asof))


if __name__ == "__main__":
    main()

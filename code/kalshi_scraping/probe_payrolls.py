"""
probe_payrolls.py — diagnostic for the live payrolls distribution.

Reproduces the live-quotes Edge Function server-side (authenticated) for KXPAYROLLS
so we can see the raw per-strike order-book midpoints and the resulting PMF/mean,
and compare against what Kalshi shows. No writes.
"""

import os
import sys

import requests
from cryptography.hazmat.primitives import serialization

repo_root = os.getcwd()
sys.path.append(os.path.join(repo_root, "code/kalshi_scraping"))
from clients_kalshi import KalshiHttpClient, Environment  # noqa: E402

TICKER = "KXPAYROLLS"
STRIKE_INT = 10.0
SCALE = 0.001


def client():
    pem = os.getenv("KALSHI_PRIVATE_KEY")
    pk = serialization.load_pem_private_key(pem.encode(), password=None)
    return KalshiHttpClient(key_id=os.getenv("KALSHI_KEYID"), private_key=pk, environment=Environment.PROD)


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def preamble(t):
    i = t.rfind("-T")
    return t[:i] if i >= 0 else t


def parse_strike(t):
    i = t.rfind("-T")
    if i < 0:
        return None
    raw = t[i + 2:]
    if raw.startswith("N"):
        raw = "-" + raw[1:]
    return num(raw)


def top(side):
    if not isinstance(side, list) or not side:
        return None
    best = None
    for lvl in side:
        p = num(lvl[0]) if isinstance(lvl, list) and lvl else None
        if p is not None:
            best = p if best is None else max(best, p)
    return None if best is None else best * 100  # dollars -> cents


def mid_from_book(ob):
    o = ob.get("orderbook_fp") or ob.get("orderbook") or {}
    yes_bid = top(o.get("yes_dollars") or o.get("yes"))
    no_bid = top(o.get("no_dollars") or o.get("no"))
    yes_ask = (100 - no_bid) if no_bid is not None else None
    if yes_bid is not None and yes_ask is not None:
        return yes_bid, yes_ask, (yes_bid + yes_ask) / 2
    return yes_bid, yes_ask, (yes_bid if yes_bid is not None else yes_ask)


def middle_out(p):
    n = len(p); adj = list(p)
    k = min(range(n), key=lambda i: abs(p[i] - 49))
    run = adj[k]
    for i in range(k - 1, -1, -1):
        run = max(run, p[i]); adj[i] = run
    run = adj[k]
    for i in range(k + 1, n):
        run = min(run, p[i]); adj[i] = run
    return adj


def to_pmf(strikes, cdf, si):
    n = len(strikes); bins = [(strikes[0] - si, max(0.0, 100 - cdf[0]))]
    for i in range(n - 1):
        bins.append((strikes[i], max(0.0, cdf[i] - cdf[i + 1])))
    bins.append((strikes[n - 1], max(0.0, cdf[n - 1])))
    s = sum(p for _, p in bins) or 1
    return [(x, p * 100 / s) for x, p in bins]


def main():
    c = client()
    mk = c.get("/trade-api/v2/markets", params={"series_ticker": TICKER, "limit": 1000, "status": "open"})
    markets = mk.get("markets", [])
    groups = {}
    for m in markets:
        tk = str(m.get("ticker") or "")
        groups.setdefault(preamble(tk), []).append(m)
    print("open KXPAYROLLS contracts:", sorted(groups.keys()))

    # nearest-close (front) contract
    def close_of(g):
        ts = [m.get("close_time") for m in g if m.get("close_time")]
        return min(ts) if ts else "9999"
    front = sorted(groups.keys(), key=lambda k: close_of(groups[k]))[0]
    print("\n=== front contract:", front, "===")
    pts = []
    for m in sorted(groups[front], key=lambda m: parse_strike(str(m.get("ticker"))) or 0):
        tk = str(m.get("ticker"))
        strike = parse_strike(tk)
        if strike is None:
            continue
        ob = c.get("/trade-api/v2/markets/{}/orderbook".format(tk))
        yb, ya, mid = mid_from_book(ob)
        print("  strike {:>8.0f} (scaled {:>6.1f}k)  yes_bid={} yes_ask={} mid={}".format(
            strike, strike * SCALE, yb, ya, round(mid, 1) if mid is not None else None))
        if mid is not None:
            pts.append((strike * SCALE, max(0.0, min(100.0, mid))))
    if len(pts) >= 2:
        pts.sort()
        strikes = [x for x, _ in pts]
        cdf = middle_out([c2 for _, c2 in pts])
        bins = to_pmf(strikes, cdf, STRIKE_INT)
        sp = sum(p for _, p in bins) or 1
        mean = sum(p * x for x, p in bins) / sp + STRIKE_INT / 2
        print("\n  PMF (x in thousands of jobs, p%):")
        for x, p in bins:
            if p > 0.5:
                print("    {:>7.1f}k : {:>5.1f}%".format(x, p))
        print("  implied mean: {:.1f}k jobs".format(mean))


if __name__ == "__main__":
    main()

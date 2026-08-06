"""
audit_strikes.py

Read-only diagnostic: for each economic series, pull Kalshi's live strike ladder
and compare its native spacing to the `strike_int` used by the R conversion
(code/convert_trades_to_pdfs/data_convert_runner.R). The goal is to confirm the
binning grid the pipeline imposes faithfully matches how Kalshi actually lists
strikes — otherwise the distribution is either coarsened (grid too wide) or
padded with never-traded bins (grid too fine).

Uses ONLY Kalshi's public (unauthenticated) /markets endpoint — no credentials,
no database, no writes. Safe to run anywhere Kalshi is reachable (e.g. a GitHub
Actions runner; egress-restricted sandboxes will 403).

Run:  python code/kalshi_scraping/audit_strikes.py
"""

import re
import time
from collections import Counter

import requests

BASE = "https://api.elections.kalshi.com/trade-api/v2"

# (key, Kalshi series ticker, strike_int, strike_scale) exactly as passed to
# extract_distributions() in data_convert_runner.R. The two annual/bracket
# markets use the PDF path (no strike_int) — reported for information only.
SERIES = [
    ("fed_levels",                "KXFED",         0.25, 1.0),
    ("headline_cpi_releases",     "KXCPIYOY",      0.1,  1.0),
    ("core_cpi_releases",         "KXCPICOREYOY",  0.1,  1.0),
    ("headline_cpi_releases_mom", "KXCPI",         0.1,  1.0),
    ("unemployment_releases",     "KXU3",          0.1,  1.0),
    ("nonfarm_payrolls",          "KXPAYROLLS",    50.0, 0.001),
    ("gdp_quarterly",             "KXGDP",         0.5,  1.0),
    ("headline_cpi_end_of_year",  "KXACPI",        None, 1.0),  # bracket / PDF path
    ("gdp_end_of_year",           "KXGDPYEAR",     None, 1.0),  # bracket / PDF path
]


def parse_strike_from_ticker(ticker):
    """Fallback strike parse from the ticker suffix, mirroring the R regex.
    Handles -T2.5 (positive), -T-100000 (literal negative), -TN0.5 (N = negative)."""
    m = re.search(r"(?<=-T)-?N?[0-9]*\.?[0-9]+$", ticker or "")
    if not m:
        return None
    raw = re.sub(r"^N", "-", m.group(0))  # leading N denotes a negative strike
    try:
        return float(raw)
    except ValueError:
        return None


def fetch_markets(series_ticker):
    """All markets (open + historical) for a series via the public endpoint."""
    out, cursor = [], None
    for _ in range(200):
        params = {"series_ticker": series_ticker, "limit": 1000}
        if cursor:
            params["cursor"] = cursor
        r = requests.get(f"{BASE}/markets", params=params, timeout=30)
        r.raise_for_status()
        j = r.json()
        out.extend(j.get("markets", []))
        cursor = j.get("cursor")
        if not cursor:
            break
        time.sleep(0.2)
    return out


def strikes_of(markets):
    """Distinct strike values across the markets (floor_strike, else ticker parse)."""
    vals = []
    for m in markets:
        s = m.get("floor_strike")
        if s is None:
            s = parse_strike_from_ticker(m.get("ticker"))
        if s is not None:
            vals.append(round(float(s), 6))
    return sorted(set(vals))


def modal_gap(sorted_unique):
    gaps = [round(b - a, 6) for a, b in zip(sorted_unique, sorted_unique[1:]) if b > a]
    if not gaps:
        return None, Counter()
    c = Counter(gaps)
    return c.most_common(1)[0][0], c


def main():
    print("Strike-grid audit — Kalshi native spacing vs configured strike_int\n")
    hdr = "{:<28} {:<14} {:>6} {:>8} {:>10} {:>10} {:>11} {:>10} {}".format(
        "series", "ticker", "#mkts", "#strikes", "min", "max", "native_gap", "expected", "verdict")
    print(hdr)
    print("-" * len(hdr))
    for key, tk, sint, scale in SERIES:
        try:
            mkts = fetch_markets(tk)
        except Exception as e:  # noqa: BLE001
            print("{:<28} {:<14}  FETCH FAILED: {}".format(key, tk, e))
            continue
        uniq = strikes_of(mkts)
        gap, counter = modal_gap(uniq)
        expected = (sint / scale) if sint is not None else None
        if sint is None:
            verdict = "bracket/PDF (info only)"
        elif gap is None:
            verdict = "NO STRIKES FOUND"
        elif abs(gap - expected) < 1e-6:
            verdict = "MATCH"
        else:
            verdict = "MISMATCH -> set strike_int to {} (scale {})".format(gap * scale, scale)
        mn = uniq[0] if uniq else None
        mx = uniq[-1] if uniq else None
        exp_str = ("{}".format(expected)) if expected is not None else "-"
        print("{:<28} {:<14} {:>6} {:>8} {:>10} {:>10} {:>11} {:>10} {}".format(
            key, tk, len(mkts), len(uniq), str(mn), str(mx), str(gap), exp_str, verdict))
        # if the spacing isn't perfectly uniform, show the distribution of gaps
        if sint is not None and gap is not None and len(counter) > 1:
            dist = ", ".join("{}x{}".format(g, n) for g, n in counter.most_common(8))
            print("{:<28} gap distribution: {}".format("", dist))

    print("\nnative_gap = most common spacing between adjacent distinct strikes across ALL listed")
    print("markets for the series. expected = strike_int / strike_scale from data_convert_runner.R.")
    print("A clean MATCH means the R grid reproduces Kalshi's ladder exactly; a MISMATCH prints the")
    print("strike_int value to switch to (and remember moment_adjustment = strike_int / 2).")


if __name__ == "__main__":
    main()

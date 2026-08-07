// Supabase Edge Function: live-distribution
//
// The dashboard's "Live now" button calls this. Kalshi blocks direct browser
// (cross-origin) calls, so this runs server-side: it fetches the CURRENT markets
// for a series from Kalshi's public API, takes the yes bid/ask MIDPOINT per
// strike (one instant across all strikes), cleans the implied CDF (middle-out,
// as in the R pipeline), differences it into a PMF, computes moments, and returns
// it as JSON with permissive CORS so the Pages site can read it.
//
// Deploy (from repo root, with the Supabase CLI logged in):
//   supabase functions deploy live-distribution --project-ref <your-project-ref>
// The browser sends the publishable anon key, so the default JWT check passes.
//
// Query params: ?series=<internal key>&contract=<contract_preamble>
//   e.g. ?series=headline_cpi_releases&contract=KXCPIYOY-26AUG

const KALSHI = "https://api.elections.kalshi.com/trade-api/v2";

// Threshold (CDF) series only — key -> Kalshi ticker + strike grid, mirroring
// series_config.py / data_convert_runner.R (payrolls scaled to thousands).
const SERIES: Record<string, { ticker: string; strike_int: number; scale: number; unit: string }> = {
  fed_levels:                { ticker: "KXFED",        strike_int: 0.25, scale: 1,     unit: "%" },
  headline_cpi_releases:     { ticker: "KXCPIYOY",     strike_int: 0.1,  scale: 1,     unit: "%" },
  core_cpi_releases:         { ticker: "KXCPICOREYOY", strike_int: 0.1,  scale: 1,     unit: "%" },
  headline_cpi_releases_mom: { ticker: "KXCPI",        strike_int: 0.1,  scale: 1,     unit: "%" },
  unemployment_releases:     { ticker: "KXU3",         strike_int: 0.1,  scale: 1,     unit: "%" },
  gdp_quarterly:             { ticker: "KXGDP",        strike_int: 0.5,  scale: 1,     unit: "%" },
  nonfarm_payrolls:          { ticker: "KXPAYROLLS",   strike_int: 10,   scale: 0.001, unit: "k" },
};

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const num = (v: unknown): number | null => {
  const n = typeof v === "number" ? v : parseFloat(String(v));
  return Number.isFinite(n) ? n : null;
};
const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

// contract_preamble = ticker minus the -T<strike> suffix (mirrors the R regex).
const preamble = (ticker: string) => ticker.replace(/-T-?N?[0-9]*\.?[0-9]+$/, "");
// strike from the -T suffix; N prefix = negative (e.g. -TN0.5), also -T-100000.
function parseStrike(ticker: string): number | null {
  const m = ticker.match(/(?<=-T)-?N?[0-9]*\.?[0-9]+$/);
  if (!m) return null;
  const raw = m[0].replace(/^N/, "-");
  const n = parseFloat(raw);
  return Number.isFinite(n) ? n : null;
}

async function fetchMarkets(seriesTicker: string): Promise<Array<Record<string, unknown>>> {
  const out: Array<Record<string, unknown>> = [];
  let cursor: string | null = null;
  for (let i = 0; i < 20; i++) {
    const u = new URL(`${KALSHI}/markets`);
    u.searchParams.set("series_ticker", seriesTicker);
    u.searchParams.set("limit", "1000");
    u.searchParams.set("status", "open");
    if (cursor) u.searchParams.set("cursor", cursor);
    const r = await fetch(u.toString());
    if (!r.ok) throw new Error(`Kalshi /markets ${r.status}`);
    const j = await r.json();
    out.push(...(j.markets ?? []));
    cursor = j.cursor || null;
    if (!cursor) break;
  }
  return out;
}

// Enforce a valid non-increasing-in-strike CDF, anchored at the bin whose price
// is closest to the 1-99 median (49), cleaning outward in both directions.
function middleOut(prices: number[]): number[] {
  const n = prices.length;
  const adj = prices.slice();
  let k = 0, best = Infinity;
  for (let i = 0; i < n; i++) { const d = Math.abs(prices[i] - 49); if (d < best) { best = d; k = i; } }
  // left of the anchor (lower strikes) must be priced >= : running max walking out
  let run = adj[k];
  for (let i = k - 1; i >= 0; i--) { run = Math.max(run, prices[i]); adj[i] = run; }
  // right of the anchor (higher strikes) must be priced <= : running min walking out
  run = adj[k];
  for (let i = k + 1; i < n; i++) { run = Math.min(run, prices[i]); adj[i] = run; }
  return adj;
}

// Difference the cleaned CDF (complementary, P(outcome >= strike)) into a PMF
// over bins: a synthetic below-lowest bin, interior bins, and the top-tail bin.
function toPMF(strikes: number[], cdf: number[], si: number): Array<{ x: number; p: number }> {
  const n = strikes.length, bins: Array<{ x: number; p: number }> = [];
  bins.push({ x: strikes[0] - si, p: Math.max(0, 100 - cdf[0]) });      // P(< lowest strike)
  for (let i = 0; i < n - 1; i++) bins.push({ x: strikes[i], p: Math.max(0, cdf[i] - cdf[i + 1]) });
  bins.push({ x: strikes[n - 1], p: Math.max(0, cdf[n - 1]) });          // P(>= top strike)
  const sum = bins.reduce((a, b) => a + b.p, 0) || 1;
  for (const b of bins) b.p = (b.p * 100) / sum;
  return bins;
}

function moments(bins: Array<{ x: number; p: number }>, madj: number) {
  const sp = bins.reduce((a, b) => a + b.p, 0) || 1;
  const mean = bins.reduce((a, b) => a + b.p * b.x, 0) / sp;
  const variance = bins.reduce((a, b) => a + b.p * (b.x - mean) * (b.x - mean), 0) / sp;
  // weighted median (step) and mode
  const sorted = bins.slice().sort((a, b) => a.x - b.x);
  let cum = 0, median = sorted[0].x;
  for (const b of sorted) { cum += b.p; if (cum >= sp / 2) { median = b.x; break; } }
  let mode = sorted[0].x, mp = -1;
  for (const b of sorted) if (b.p > mp) { mp = b.p; mode = b.x; }
  return { mean: mean + madj, median: median + madj, mode: mode + madj, sd: Math.sqrt(Math.max(0, variance)) };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const url = new URL(req.url);
    const seriesKey = url.searchParams.get("series") ?? "";
    const contract = url.searchParams.get("contract") ?? "";
    const cfg = SERIES[seriesKey];
    if (!cfg) return json({ error: `unknown or unsupported series '${seriesKey}' (live supports threshold markets only)` }, 400);
    if (!contract) return json({ error: "missing contract" }, 400);

    const markets = await fetchMarkets(cfg.ticker);
    const pts: Array<{ strike: number; cdf: number }> = [];
    for (const m of markets) {
      const tk = String(m.ticker ?? "");
      if (preamble(tk) !== contract) continue;
      const strike = parseStrike(tk);
      if (strike == null) continue;
      const bid = num(m.yes_bid), ask = num(m.yes_ask);
      if (bid == null && ask == null) continue;
      let mid = bid != null && ask != null ? (bid + ask) / 2 : (bid ?? ask)!;
      if (mid <= 1) mid *= 100; // normalize dollars -> cents if needed
      pts.push({ strike: strike * cfg.scale, cdf: clamp(mid, 0, 100) });
    }
    if (pts.length < 2) return json({ error: "no live quotes for this contract right now (market may be closed or unlisted)" }, 404);

    pts.sort((a, b) => a.strike - b.strike);
    const cdf = middleOut(pts.map((p) => p.cdf));
    const bins = toPMF(pts.map((p) => p.strike), cdf, cfg.strike_int);
    const mom = moments(bins, cfg.strike_int / 2);
    return json({
      series: seriesKey, contract, unit: cfg.unit, asof: new Date().toISOString(),
      n_strikes: pts.length,
      strikes: bins.map((b) => Math.round(b.x * 1e6) / 1e6),
      probs: bins.map((b) => Math.round(b.p * 1e4) / 1e4),
      ...mom,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

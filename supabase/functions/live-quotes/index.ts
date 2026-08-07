// Supabase Edge Function: live-quotes
//
// The dashboard's "Live" button calls this for a genuinely real-time, on-demand
// quote distribution. Kalshi blocks direct browser calls AND only returns bid/ask
// to AUTHENTICATED requests, so this runs server-side: it signs requests with the
// Kalshi API key (RSA-PSS, same scheme as the Python client), reads the CURRENT
// order book for every strike of the selected contract, takes the yes bid/ask
// MIDPOINT (one instant across strikes), cleans the implied CDF (middle-out, as in
// the R pipeline), differences it into a PMF, computes moments, and returns JSON
// with permissive CORS.
//
// Deploy from the Supabase dashboard (no CLI needed) — see the repo chat for the
// exact iPad steps. Requires two Function secrets:
//   KALSHI_KEYID          — your Kalshi API key id
//   KALSHI_PRIVATE_KEY    — the RSA private key PEM (PKCS#8: "-----BEGIN PRIVATE KEY-----")
//
// Query: ?series=<internal key>&contract=<contract_preamble>
//   e.g. ?series=headline_cpi_releases&contract=KXCPIYOY-26AUG

const KALSHI = "https://api.elections.kalshi.com";
const V2 = "/trade-api/v2";

// key -> Kalshi ticker + strike grid (mirrors series_config.py / the R runner).
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
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const num = (v: unknown): number | null => {
  const n = typeof v === "number" ? v : parseFloat(String(v));
  return Number.isFinite(n) ? n : null;
};
const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));
const preamble = (t: string) => { const i = t.lastIndexOf("-T"); return i >= 0 ? t.slice(0, i) : t; };
function parseStrike(t: string): number | null {
  const i = t.lastIndexOf("-T"); if (i < 0) return null;
  let raw = t.slice(i + 2); if (raw.startsWith("N")) raw = "-" + raw.slice(1);
  const n = parseFloat(raw); return Number.isFinite(n) ? n : null;
}

// ---- Kalshi RSA-PSS request signing (mirrors clients_kalshi.py) ----
let KEY: CryptoKey | null = null;
async function privateKey(): Promise<CryptoKey> {
  if (KEY) return KEY;
  const pem = Deno.env.get("KALSHI_PRIVATE_KEY") ?? "";
  const b64 = pem.replace(/-----BEGIN[^-]+-----/, "").replace(/-----END[^-]+-----/, "").replace(/\s+/g, "");
  if (!b64) throw new Error("KALSHI_PRIVATE_KEY not set");
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  KEY = await crypto.subtle.importKey("pkcs8", der, { name: "RSA-PSS", hash: "SHA-256" }, false, ["sign"]);
  return KEY;
}
async function signedGet(path: string, query?: Record<string, string>): Promise<any> {
  const keyId = Deno.env.get("KALSHI_KEYID");
  if (!keyId) throw new Error("KALSHI_KEYID not set");
  const ts = Date.now().toString();
  const sig = await crypto.subtle.sign(
    { name: "RSA-PSS", saltLength: 32 }, await privateKey(),
    new TextEncoder().encode(ts + "GET" + path),
  );
  const u = new URL(KALSHI + path);
  if (query) for (const [k, v] of Object.entries(query)) u.searchParams.set(k, v);
  const r = await fetch(u.toString(), {
    headers: {
      "KALSHI-ACCESS-KEY": keyId,
      "KALSHI-ACCESS-SIGNATURE": btoa(String.fromCharCode(...new Uint8Array(sig))),
      "KALSHI-ACCESS-TIMESTAMP": ts,
    },
  });
  if (!r.ok) throw new Error(`Kalshi ${path} ${r.status}`);
  return r.json();
}

// yes-midpoint (in cents) from a live order book: best yes bid, and yes ask =
// 100 - best no bid. Prices arrive as *_dollars strings.
function midFromBook(ob: any): number | null {
  const o = ob?.orderbook_fp ?? ob?.orderbook ?? {};
  const top = (side: any): number | null => {
    if (!Array.isArray(side) || !side.length) return null;
    let best = -Infinity;
    for (const lvl of side) { const p = num(lvl?.[0]); if (p != null) best = Math.max(best, p); }
    return best === -Infinity ? null : best * 100; // dollars -> cents
  };
  const yesBid = top(o.yes_dollars ?? o.yes);
  const noBid = top(o.no_dollars ?? o.no);
  const yesAsk = noBid != null ? 100 - noBid : null;
  if (yesBid != null && yesAsk != null) return (yesBid + yesAsk) / 2;
  return yesBid ?? yesAsk;
}

function middleOut(p: number[]): number[] {
  const n = p.length, adj = p.slice();
  let k = 0, best = Infinity;
  for (let i = 0; i < n; i++) { const d = Math.abs(p[i] - 49); if (d < best) { best = d; k = i; } }
  let run = adj[k]; for (let i = k - 1; i >= 0; i--) { run = Math.max(run, p[i]); adj[i] = run; }
  run = adj[k]; for (let i = k + 1; i < n; i++) { run = Math.min(run, p[i]); adj[i] = run; }
  return adj;
}
function toPMF(strikes: number[], cdf: number[], si: number) {
  const n = strikes.length, bins: Array<{ x: number; p: number }> = [];
  bins.push({ x: strikes[0] - si, p: Math.max(0, 100 - cdf[0]) });
  for (let i = 0; i < n - 1; i++) bins.push({ x: strikes[i], p: Math.max(0, cdf[i] - cdf[i + 1]) });
  bins.push({ x: strikes[n - 1], p: Math.max(0, cdf[n - 1]) });
  const s = bins.reduce((a, b) => a + b.p, 0) || 1;
  for (const b of bins) b.p = (b.p * 100) / s;
  return bins;
}
function moments(bins: Array<{ x: number; p: number }>, madj: number) {
  const sp = bins.reduce((a, b) => a + b.p, 0) || 1;
  const mean = bins.reduce((a, b) => a + b.p * b.x, 0) / sp;
  const variance = bins.reduce((a, b) => a + b.p * (b.x - mean) ** 2, 0) / sp;
  const sorted = bins.slice().sort((a, b) => a.x - b.x);
  let cum = 0, median = sorted[0].x;
  for (const b of sorted) { cum += b.p; if (cum >= sp / 2) { median = b.x; break; } }
  let mode = sorted[0].x, mp = -1;
  for (const b of sorted) if (b.p > mp) { mp = b.p; mode = b.x; }
  return { mean: mean + madj, median: median + madj, mode: mode + madj, sd: Math.sqrt(Math.max(0, variance)) };
}

async function mapLimit<T, R>(items: T[], limit: number, fn: (t: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let i = 0;
  async function worker() { while (i < items.length) { const idx = i++; out[idx] = await fn(items[idx]); } }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const url = new URL(req.url);
    const seriesKey = url.searchParams.get("series") ?? "";
    const contract = url.searchParams.get("contract") ?? "";
    const cfg = SERIES[seriesKey];
    if (!cfg) return json({ error: `unknown series '${seriesKey}'` }, 400);
    if (!contract) return json({ error: "missing contract" }, 400);

    // strikes of this contract that are currently open
    const mk = await signedGet(`${V2}/markets`, { series_ticker: cfg.ticker, limit: "1000", status: "open" });
    const markets: any[] = (mk.markets ?? []).filter((m: any) => preamble(String(m.ticker ?? "")) === contract);
    if (markets.length < 2) return json({ error: "no open strikes for this contract right now" }, 404);

    // live order book per strike -> yes midpoint
    const pts = (await mapLimit(markets, 8, async (m: any) => {
      const tk = String(m.ticker);
      const strike = parseStrike(tk);
      if (strike == null) return null;
      try {
        const ob = await signedGet(`${V2}/markets/${tk}/orderbook`);
        const mid = midFromBook(ob);
        return mid == null ? null : { strike: strike * cfg.scale, cdf: clamp(mid, 0, 100) };
      } catch { return null; }
    })).filter(Boolean) as Array<{ strike: number; cdf: number }>;

    if (pts.length < 2) return json({ error: "no live quotes on the book right now (market may be quiet)" }, 404);
    pts.sort((a, b) => a.strike - b.strike);
    const cdf = middleOut(pts.map((p) => p.cdf));
    const bins = toPMF(pts.map((p) => p.strike), cdf, cfg.strike_int);
    const mom = moments(bins, cfg.strike_int / 2);
    return json({
      series: seriesKey, contract, unit: cfg.unit, asof: new Date().toISOString(), live: true,
      n_strikes: pts.length,
      strikes: bins.map((b) => Math.round(b.x * 1e6) / 1e6),
      probs: bins.map((b) => Math.round(b.p * 1e4) / 1e4),
      ...mom,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

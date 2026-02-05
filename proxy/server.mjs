import http from "node:http";
import { Readable } from "node:stream";

function parseArgs(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--help" || a === "-h") out.help = true;
    else if (a === "--host") out.host = argv[++i];
    else if (a === "--port") out.port = argv[++i];
    else if (a === "--base-url") out.baseUrl = argv[++i];
    else if (a === "--api-key") out.apiKey = argv[++i];
    else if (a === "--gemini-base-url") out.geminiBaseUrl = argv[++i];
    else if (a === "--gemini-api-key") out.geminiApiKey = argv[++i];
    else throw new Error(`Unknown arg: ${a}`);
  }
  return out;
}

const args = parseArgs(process.argv);
if (args.help) {
  // eslint-disable-next-line no-console
  console.log(`Usage:
  node proxy/server.mjs [--host 127.0.0.1] [--port 8787] [--base-url https://.../v1] [--api-key sk-...]
  node proxy/server.mjs [--gemini-base-url https://www.right.codes/gemini] [--gemini-api-key ...]

Environment variables:
  HOST, PORT, OPENAI_BASE_URL, OPENAI_API_KEY
  GEMINI_BASE_URL, GEMINI_API_KEY
`);
  process.exit(0);
}

const HOST = args.host || process.env.HOST || "127.0.0.1";
const PORT = Number.parseInt(args.port || process.env.PORT || "8787", 10);

const OPENAI_BASE_URL = ((args.baseUrl || process.env.OPENAI_BASE_URL || "https://api.openai.com/v1") + "").replace(/\/+$/, "");
const OPENAI_API_KEY = (args.apiKey || process.env.OPENAI_API_KEY || "") + "";

const GEMINI_BASE_URL = ((args.geminiBaseUrl || process.env.GEMINI_BASE_URL || "https://www.right.codes/gemini") + "").replace(/\/+$/, "");
// By default, reuse OPENAI_API_KEY for Gemini as requested (single-key dev setup).
const GEMINI_API_KEY = (args.geminiApiKey || process.env.GEMINI_API_KEY || OPENAI_API_KEY || "") + "";

function json(res, status, obj) {
  const body = JSON.stringify(obj, null, 2) + "\n";
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "*",
    "access-control-allow-methods": "POST, OPTIONS, GET",
  });
  res.end(body);
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(Buffer.from(chunk));
  const buf = Buffer.concat(chunks);
  return buf.toString("utf8");
}

function copyJsonHeaders(upstreamHeaders, contentLength) {
  const headers = {
    "content-type": upstreamHeaders.get("content-type") || "application/json; charset=utf-8",
    "cache-control": upstreamHeaders.get("cache-control") || "no-cache",
    "content-length": String(contentLength),
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "*",
    "access-control-allow-methods": "POST, OPTIONS, GET",
  };
  const maybe = upstreamHeaders.get("x-request-id");
  if (maybe) headers["x-request-id"] = maybe;
  return headers;
}

function copySseHeaders(upstreamHeaders) {
  const headers = {
    "content-type": upstreamHeaders.get("content-type") || "text/event-stream; charset=utf-8",
    "cache-control": upstreamHeaders.get("cache-control") || "no-cache",
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "*",
    "access-control-allow-methods": "POST, OPTIONS, GET",
  };
  const maybe = upstreamHeaders.get("x-request-id");
  if (maybe) headers["x-request-id"] = maybe;
  return headers;
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "access-control-allow-origin": "*",
        "access-control-allow-headers": "*",
        "access-control-allow-methods": "POST, OPTIONS, GET",
      });
      res.end();
      return;
    }

    // Gemini proxy:
    // - GET  /gemini/healthz
    // - POST /gemini/v1beta/models/...:generateContent
    // Forwards to GEMINI_BASE_URL and injects x-goog-api-key.
    if (url.pathname === "/gemini/healthz" && req.method === "GET") {
      json(res, 200, { ok: true, gemini_base_url: GEMINI_BASE_URL, gemini_key_set: Boolean(GEMINI_API_KEY) });
      return;
    }
    if (url.pathname.startsWith("/gemini/")) {
      if (!GEMINI_API_KEY) {
        json(res, 500, { error: "missing_env", env: "GEMINI_API_KEY (or OPENAI_API_KEY)" });
        return;
      }

      const raw = await readBody(req);
      const upstreamUrl = `${GEMINI_BASE_URL}${url.pathname.substring("/gemini".length)}${url.search}`;
      const upstream = await fetch(upstreamUrl, {
        method: req.method || "POST",
        headers: {
          "content-type": req.headers["content-type"] || "application/json",
          accept: req.headers.accept || "application/json",
          "x-goog-api-key": GEMINI_API_KEY,
        },
        body: raw && (req.method === "POST" || req.method === "PUT" || req.method === "PATCH") ? raw : undefined,
      });

      const ab = await upstream.arrayBuffer().catch(() => new ArrayBuffer(0));
      const buf = Buffer.from(ab);
      res.writeHead(upstream.status, copyJsonHeaders(upstream.headers, buf.length));
      res.end(buf);
      return;
    }

    if (req.method === "GET" && url.pathname === "/healthz") {
      json(res, 200, { ok: true });
      return;
    }

    if (req.method !== "POST" || url.pathname !== "/v1/responses") {
      json(res, 404, { error: "not_found", path: url.pathname });
      return;
    }

    if (!OPENAI_API_KEY) {
      json(res, 500, { error: "missing_env", env: "OPENAI_API_KEY" });
      return;
    }

    const raw = await readBody(req);
    let body;
    try {
      body = JSON.parse(raw || "{}");
    } catch {
      json(res, 400, { error: "invalid_json" });
      return;
    }

    const upstreamUrl = `${OPENAI_BASE_URL}/responses`;
    const upstream = await fetch(upstreamUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        accept: "text/event-stream",
        authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify(body),
    });

    if (!upstream.ok) {
      const text = await upstream.text().catch(() => "");
      json(res, upstream.status, { error: "upstream_http_error", status: upstream.status, body: text });
      return;
    }

    res.writeHead(upstream.status, copySseHeaders(upstream.headers));
    if (!upstream.body) {
      res.end();
      return;
    }

    Readable.fromWeb(upstream.body).pipe(res);
  } catch (e) {
    const err = e instanceof Error ? e : new Error(String(e));
    json(res, 500, { error: "internal_error", message: err.message });
  }
});

server.listen(PORT, HOST, () => {
  // eslint-disable-next-line no-console
  console.log(`[openagentic-proxy] listening on http://${HOST}:${PORT}`);
  console.log(`[openagentic-proxy] upstream: ${OPENAI_BASE_URL}`);
});

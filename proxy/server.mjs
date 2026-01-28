import http from "node:http";
import { Readable } from "node:stream";

const HOST = process.env.HOST || "127.0.0.1";
const PORT = Number.parseInt(process.env.PORT || "8787", 10);

const OPENAI_BASE_URL = (process.env.OPENAI_BASE_URL || "https://api.openai.com/v1").replace(/\/+$/, "");
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";

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


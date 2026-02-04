import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function parseArgs(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--help" || a === "-h") out.help = true;
    else if (a === "--host") out.host = argv[++i];
    else if (a === "--port") out.port = argv[++i];
    else if (a === "--store-dir") out.storeDir = argv[++i];
    else if (a === "--bearer-token") out.bearerToken = argv[++i];
    else throw new Error(`Unknown arg: ${a}`);
  }
  return out;
}

const args = parseArgs(process.argv);
if (args.help) {
  // eslint-disable-next-line no-console
  console.log(`Usage:
  node media_service/server.mjs [--host 127.0.0.1] [--port 8788] [--store-dir /tmp/oa-media] [--bearer-token dev-token]

Environment variables:
  HOST, PORT, OPENAGENTIC_MEDIA_STORE_DIR, OPENAGENTIC_MEDIA_BEARER_TOKEN
`);
  process.exit(0);
}

const HOST = args.host || process.env.HOST || "127.0.0.1";
const PORT = Number.parseInt(args.port || process.env.PORT || "8788", 10);

const STORE_DIR = args.storeDir || process.env.OPENAGENTIC_MEDIA_STORE_DIR || "/tmp/oa-media";
const BEARER_TOKEN = args.bearerToken || process.env.OPENAGENTIC_MEDIA_BEARER_TOKEN || "";

const MAX_NAME_LEN = 128;

const LIMITS = {
  "image/png": 8 * 1024 * 1024,
  "image/jpeg": 8 * 1024 * 1024,
  "audio/mpeg": 20 * 1024 * 1024,
  "audio/wav": 20 * 1024 * 1024,
  "video/mp4": 64 * 1024 * 1024,
};

function json(res, status, obj) {
  const body = JSON.stringify(obj, null, 2) + "\n";
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
  });
  res.end(body);
}

function bad(res, status, code, message) {
  json(res, status, { ok: false, error: code, message });
}

function requireAuth(req) {
  if (!BEARER_TOKEN) return { ok: false, status: 500, code: "missing_env", message: "OPENAGENTIC_MEDIA_BEARER_TOKEN is required" };
  const h = (req.headers.authorization || "") + "";
  if (!h.startsWith("Bearer ")) return { ok: false, status: 401, code: "unauthorized", message: "missing bearer token" };
  const tok = h.slice("Bearer ".length);
  if (tok !== BEARER_TOKEN) return { ok: false, status: 403, code: "forbidden", message: "invalid bearer token" };
  return { ok: true };
}

function safeHeaderValue(v) {
  const s = (v || "").toString().trim();
  if (!s) return "";
  if (s.length > MAX_NAME_LEN) return s.slice(0, MAX_NAME_LEN);
  return s;
}

function sniffMime(buf) {
  if (!Buffer.isBuffer(buf) || buf.length < 12) return { ok: false, error: "sniff_failed" };

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return { ok: true, mime: "image/png", kind: "image" };
  }
  // JPEG: FF D8 FF
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
    return { ok: true, mime: "image/jpeg", kind: "image" };
  }
  // WAV: RIFF....WAVE
  if (buf.length >= 12 && buf.subarray(0, 4).toString("ascii") === "RIFF" && buf.subarray(8, 12).toString("ascii") === "WAVE") {
    return { ok: true, mime: "audio/wav", kind: "audio" };
  }
  // MP3: "ID3" or frame sync 0xFFEx
  if (buf.length >= 3 && buf.subarray(0, 3).toString("ascii") === "ID3") {
    return { ok: true, mime: "audio/mpeg", kind: "audio" };
  }
  if (buf.length >= 2 && buf[0] === 0xff && (buf[1] & 0xe0) === 0xe0) {
    return { ok: true, mime: "audio/mpeg", kind: "audio" };
  }
  // MP4: size(4) + "ftyp"(4)
  if (buf.length >= 12 && buf.subarray(4, 8).toString("ascii") === "ftyp") {
    return { ok: true, mime: "video/mp4", kind: "video" };
  }
  return { ok: false, error: "unsupported_mime" };
}

async function readBodyBytes(req, maxBytes) {
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    const b = Buffer.from(chunk);
    total += b.length;
    if (total > maxBytes) return { ok: false, error: "too_large", total };
    chunks.push(b);
  }
  return { ok: true, buf: Buffer.concat(chunks), total };
}

function makeId() {
  // url-safe id: base64url without padding
  return crypto.randomBytes(12).toString("base64url");
}

function ensureStore() {
  fs.mkdirSync(STORE_DIR, { recursive: true });
}

function filePathForId(id) {
  return path.join(STORE_DIR, `${id}.bin`);
}

function metaPathForId(id) {
  return path.join(STORE_DIR, `${id}.json`);
}

function readMeta(id) {
  const p = metaPathForId(id);
  if (!fs.existsSync(p)) return null;
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

    if (req.method === "GET" && url.pathname === "/healthz") {
      json(res, 200, { ok: true });
      return;
    }

    if (req.method === "POST" && url.pathname === "/upload") {
      const auth = requireAuth(req);
      if (!auth.ok) return bad(res, auth.status, auth.code, auth.message);

      const globalMax = LIMITS["video/mp4"];
      const body = await readBodyBytes(req, globalMax);
      if (!body.ok) return bad(res, 413, "too_large", `body too large (${body.total} bytes)`);

      const sniff = sniffMime(body.buf);
      if (!sniff.ok) return bad(res, 415, sniff.error, "unsupported media type");

      const limit = LIMITS[sniff.mime] ?? 0;
      if (limit <= 0) return bad(res, 415, "unsupported_mime", "unsupported media type");
      if (body.total > limit) return bad(res, 413, "too_large", `exceeds limit for ${sniff.mime}`);

      const sha256 = crypto.createHash("sha256").update(body.buf).digest("hex");
      const id = makeId();
      const name = safeHeaderValue(req.headers["x-oa-name"]);
      const caption = safeHeaderValue(req.headers["x-oa-caption"]);

      ensureStore();
      fs.writeFileSync(filePathForId(id), body.buf);
      const meta = { id, kind: sniff.kind, mime: sniff.mime, bytes: body.total, sha256 };
      if (name) meta.name = name;
      if (caption) meta.caption = caption;
      fs.writeFileSync(metaPathForId(id), JSON.stringify(meta, null, 2) + "\n");

      json(res, 200, { ok: true, ...meta });
      return;
    }

    if (req.method === "GET" && url.pathname.startsWith("/media/")) {
      const auth = requireAuth(req);
      if (!auth.ok) return bad(res, auth.status, auth.code, auth.message);

      const id = url.pathname.slice("/media/".length).trim();
      if (!id) return bad(res, 400, "invalid_id", "missing id");

      const p = filePathForId(id);
      const meta = readMeta(id);
      if (!fs.existsSync(p) || !meta) return bad(res, 404, "not_found", "media not found");

      const buf = fs.readFileSync(p);
      res.writeHead(200, {
        "content-type": meta.mime || "application/octet-stream",
        "content-length": buf.length,
        "x-oa-sha256": meta.sha256 || "",
        "x-oa-kind": meta.kind || "",
        "cache-control": "no-store",
      });
      res.end(buf);
      return;
    }

    bad(res, 404, "not_found", "unknown route");
  } catch (e) {
    const err = e instanceof Error ? e : new Error(String(e));
    bad(res, 500, "internal_error", err.message);
  }
});

server.listen(PORT, HOST, () => {
  // eslint-disable-next-line no-console
  console.log(`[openagentic-media] listening on http://${HOST}:${PORT}`);
  // eslint-disable-next-line no-console
  console.log(`[openagentic-media] store: ${STORE_DIR}`);
});


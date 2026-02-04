import http from "node:http";
import net from "node:net";
import { spawn } from "node:child_process";

function request({ method, port, path, headers = {}, body = null }) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        method,
        host: "127.0.0.1",
        port,
        path,
        headers,
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(Buffer.from(c)));
        res.on("end", () => {
          resolve({
            status: res.statusCode || 0,
            headers: res.headers || {},
            body: Buffer.concat(chunks),
          });
        });
      },
    );
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

async function getFreePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.on("error", reject);
    s.listen(0, "127.0.0.1", () => {
      const addr = s.address();
      const port = typeof addr === "object" && addr ? addr.port : 0;
      s.close(() => resolve(port));
    });
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function must(cond, msg) {
  if (!cond) {
    const e = new Error(msg);
    e.name = "SmokeTestFailure";
    throw e;
  }
}

async function main() {
  const port = await getFreePort();
  const token = "smoke-token";
  const storeDir = "/tmp/oa-media-smoke";
  const png = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/6XKQnQAAAAASUVORK5CYII=",
    "base64",
  );

  const env = {
    ...process.env,
    HOST: "127.0.0.1",
    PORT: String(port),
    OPENAGENTIC_MEDIA_STORE_DIR: storeDir,
    OPENAGENTIC_MEDIA_BEARER_TOKEN: token,
    // Small cap so we can deterministically test eviction behavior.
    OPENAGENTIC_MEDIA_STORE_MAX_BYTES: String(png.length + 1),
  };

  const child = spawn(process.execPath, ["media_service/server.mjs"], { env, stdio: ["ignore", "pipe", "pipe"] });

  try {
    // Wait for /healthz
    let ok = false;
    for (let i = 0; i < 50; i++) {
      try {
        const r = await request({ method: "GET", port, path: "/healthz" });
        if (r.status === 200) {
          ok = true;
          break;
        }
      } catch {
        // ignore until server starts
      }
      await sleep(50);
    }
    must(ok, "server did not become healthy");

    // Unauth download must be 401
    const r401 = await request({ method: "GET", port, path: "/media/doesnotmatter" });
    must(r401.status === 401, `expected 401, got ${r401.status}`);

    // Unsafe ids must be rejected (avoid path traversal / unintended reads).
    // NOTE: Node's URL parser normalizes dot segments ("/media/../x" becomes "/x"), so we use
    // percent-encoding to keep the unsafe pattern within the /media/:id route.
    const rBad1 = await request({ method: "GET", port, path: "/media/%2e%2e%2fx", headers: { authorization: `Bearer ${token}` } });
    must(rBad1.status === 400, `expected 400 for unsafe id, got ${rBad1.status}`);
    const rBad2 = await request({ method: "GET", port, path: "/media/a/b", headers: { authorization: `Bearer ${token}` } });
    must(rBad2.status === 400, `expected 400 for unsafe id, got ${rBad2.status}`);

    // Wrong token must be 403
    const r403 = await request({
      method: "GET",
      port,
      path: "/media/doesnotmatter",
      headers: { authorization: "Bearer wrong" },
    });
    must(r403.status === 403, `expected 403, got ${r403.status}`);

    // Upload invalid magic (GIF header) must be 415
    const gif = Buffer.from([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]); // GIF89a
    const r415 = await request({
      method: "POST",
      port,
      path: "/upload",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/octet-stream",
        "content-length": String(gif.length),
      },
      body: gif,
    });
    must(r415.status === 415, `expected 415, got ${r415.status}`);

    // Upload valid 1x1 PNG and then download it.
    const rup = await request({
      method: "POST",
      port,
      path: "/upload",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/octet-stream",
        "content-length": String(png.length),
        "x-oa-name": "x.png",
      },
      body: png,
    });
    must(rup.status === 200, `expected 200, got ${rup.status}`);
    const meta = JSON.parse(rup.body.toString("utf8"));
    must(meta && meta.ok === true && typeof meta.id === "string" && meta.id.length > 0, "upload did not return ok meta");

    const rget401 = await request({ method: "GET", port, path: `/media/${meta.id}` });
    must(rget401.status === 401, `expected 401, got ${rget401.status}`);

    const rget = await request({
      method: "GET",
      port,
      path: `/media/${meta.id}`,
      headers: { authorization: `Bearer ${token}` },
    });
    must(rget.status === 200, `expected 200, got ${rget.status}`);
    must(rget.body.equals(png), "downloaded bytes mismatch");

    // Store cap: second upload should evict the first one (oldest-first) or reject deterministically.
    const rup2 = await request({
      method: "POST",
      port,
      path: "/upload",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/octet-stream",
        "content-length": String(png.length),
        "x-oa-name": "y.png",
      },
      body: png,
    });
    must([200, 413, 507].includes(rup2.status), `expected 200/413/507, got ${rup2.status}`);
    if (rup2.status === 200) {
      const meta2 = JSON.parse(rup2.body.toString("utf8"));
      must(meta2 && meta2.ok === true && typeof meta2.id === "string" && meta2.id.length > 0, "2nd upload did not return ok meta");

      const rOld = await request({
        method: "GET",
        port,
        path: `/media/${meta.id}`,
        headers: { authorization: `Bearer ${token}` },
      });
      must(rOld.status === 404, `expected 404 for evicted oldest id, got ${rOld.status}`);

      const rNew = await request({
        method: "GET",
        port,
        path: `/media/${meta2.id}`,
        headers: { authorization: `Bearer ${token}` },
      });
      must(rNew.status === 200, `expected 200 for newest id, got ${rNew.status}`);
      must(rNew.body.equals(png), "newest downloaded bytes mismatch");
    }

    // eslint-disable-next-line no-console
    console.log("PASS");
  } finally {
    child.kill("SIGTERM");
  }
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error("FAIL:", e && e.message ? e.message : e);
  process.exit(1);
});

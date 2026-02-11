#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import os
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from oa_dotenv import load_repo_dotenv


# Cherry (New API) config (repo root .env):
# - CHERRY_BASE_URL
# - CHERRY_API_KEY


def _is_local_base_url(base_url: str) -> bool:
    try:
        u = urllib.parse.urlparse(base_url)
    except Exception:
        return False
    host = (u.hostname or "").strip().lower()
    return host in {"127.0.0.1", "localhost", "::1"}


def _normalize_model_path(model: str) -> str:
    """
    Cherry's Gemini endpoint shape is documented as:
      /v1beta/models/google/<model>:generateContent

    Accept:
      - gemini-3-pro-image-preview
      - google/gemini-3-pro-image-preview
      - models/google/gemini-3-pro-image-preview
    """
    m = (model or "").strip().lstrip("/")
    if not m:
        return "google/gemini-3-pro-image-preview"
    if m.startswith("models/"):
        m = m[len("models/") :]
    if m.startswith("google/"):
        return m
    return "google/" + m


def _find_first_inline_data(v) -> tuple[bytes, str] | None:
    if isinstance(v, dict):
        id0 = None
        if "inlineData" in v:
            id0 = v.get("inlineData")
        elif "inline_data" in v:
            id0 = v.get("inline_data")
        if isinstance(id0, dict):
            data = str(id0.get("data", "")).strip()
            mime = str(id0.get("mimeType", id0.get("mime_type", ""))).strip()
            if data:
                try:
                    return base64.b64decode(data), mime
                except Exception:
                    pass
        for vv in v.values():
            r = _find_first_inline_data(vv)
            if r is not None:
                return r
        return None

    if isinstance(v, list):
        for it in v:
            r2 = _find_first_inline_data(it)
            if r2 is not None:
                return r2
        return None

    return None


def _build_opener(proxy_http: str, proxy_https: str, *, no_proxy_env: bool) -> urllib.request.OpenerDirector:
    proxies: dict[str, str] = {}
    if proxy_http.strip():
        proxies["http"] = proxy_http.strip()
    if proxy_https.strip():
        proxies["https"] = proxy_https.strip()

    if no_proxy_env:
        # Explicitly disable env proxy resolution unless the caller set proxies above.
        # Note: ProxyHandler({}) disables proxies; ProxyHandler(None) uses env proxies.
        handler = urllib.request.ProxyHandler(proxies if proxies else {})
    else:
        handler = urllib.request.ProxyHandler(proxies or None)
    return urllib.request.build_opener(handler)


def _http_post_json(
    url: str,
    headers: dict[str, str],
    payload: dict,
    timeout_sec: float,
    *,
    opener: urllib.request.OpenerDirector | None,
) -> dict:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        if opener is None:
            resp_ctx = urllib.request.urlopen(req, timeout=timeout_sec)
        else:
            resp_ctx = opener.open(req, timeout=timeout_sec)
        with resp_ctx as resp:
            raw = resp.read()
            text = raw.decode("utf-8", errors="replace")
            return {
                "ok": True,
                "status": getattr(resp, "status", 200),
                "headers": dict(resp.headers.items()),
                "text": text,
            }
    except urllib.error.HTTPError as e:
        raw = b""
        try:
            raw = e.read() or b""
        except Exception:
            pass
        text = raw.decode("utf-8", errors="replace")
        return {
            "ok": False,
            "status": int(getattr(e, "code", 0) or 0),
            "error": "http_error",
            "reason": str(getattr(e, "reason", "") or "").strip(),
            "text": text,
        }
    except (urllib.error.URLError, socket.timeout) as e:
        return {"ok": False, "status": 0, "error": "network_error", "message": str(e)}


def _to_png(raw: bytes, mime: str, width: int, height: int, *, resize: bool) -> bytes:
    try:
        from PIL import Image
    except Exception as e:
        raise RuntimeError("Missing dependency: Pillow (pip install pillow)") from e

    import io

    with Image.open(io.BytesIO(raw)) as im:
        im.load()
        if resize and width > 0 and height > 0 and (im.size[0] != width or im.size[1] != height):
            im = im.resize((width, height), Image.LANCZOS)
        out = io.BytesIO()
        im.save(out, format="PNG")
        b = out.getvalue()
        if not b or len(b) < 8 or b[:8] != b"\x89PNG\r\n\x1a\n":
            raise RuntimeError(f"PNG encode failed (source_mime={mime})")
        return b


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Call Gemini generateContent (IMAGE) and write a PNG file. Reads CHERRY_BASE_URL/CHERRY_API_KEY from repo root .env."
    )
    ap.add_argument("--model", default="google/gemini-3-pro-image-preview", help="Model name (default: google/gemini-3-pro-image-preview)")
    ap.add_argument("--prompt", default="", help="Prompt text (if empty, reads from stdin)")
    ap.add_argument("--out", default="", help="Output PNG path")
    ap.add_argument("--aspect-ratio", default="16:9", help="aspectRatio sent to API (default: 16:9)")
    ap.add_argument("--image-size", default="1K", help="imageSize sent to API (default: 1K)")
    ap.add_argument("--width", type=int, default=640, help="Output PNG width (default: 640)")
    ap.add_argument("--height", type=int, default=360, help="Output PNG height (default: 360)")
    ap.add_argument("--timeout", type=float, default=30.0, help="HTTP timeout seconds (default: 30)")
    ap.add_argument("--retries", type=int, default=3, help="Retry count for network/HTTP failures (default: 3)")
    ap.add_argument("--no-resize", action="store_true", help="Do not resize; still re-encodes to PNG")
    ap.add_argument("--check", action="store_true", help="Validate config and exit (no network call)")
    args = ap.parse_args()

    # Only source of truth: repo root .env.
    load_repo_dotenv(override=True)

    cherry_base = (os.environ.get("CHERRY_BASE_URL", "") or "").strip()
    cherry_key = (os.environ.get("CHERRY_API_KEY", "") or "").strip()
    if not cherry_base:
        raise SystemExit("Missing CHERRY_BASE_URL in repo root .env")
    if not cherry_key:
        raise SystemExit("Missing CHERRY_API_KEY in repo root .env")

    base_url = cherry_base.rstrip("/")
    base_url_src = "env:CHERRY_BASE_URL"
    api_key = cherry_key
    api_key_src = "env:CHERRY_API_KEY"

    if not (base_url.startswith("http://") or base_url.startswith("https://")):
        raise SystemExit(f"Invalid base URL (must start with http:// or https://): {base_url}")
    if _is_local_base_url(base_url):
        raise SystemExit(f"Refusing local base URL (127.0.0.1/localhost): {base_url}")

    # Always disable proxies (do not use HTTP_PROXY/HTTPS_PROXY).
    opener = _build_opener("", "", no_proxy_env=True)


    if args.check:
        u = urllib.parse.urlparse(base_url)
        host = (u.hostname or "").strip()
        print(
            "OK "
            + f"base_url={base_url} "
            + f"base_url_src={base_url_src} "
            + f"host={host} "
            + f"api_key=set "
            + f"api_key_src={api_key_src} "
            + f"model={args.model} "
            + "proxy=disabled"
        )
        return 0

    prompt = (args.prompt or "").strip()
    if not prompt:
        if sys.stdin is None or sys.stdin.isatty():
            raise SystemExit("Missing --prompt (or provide prompt via stdin)")
        prompt = sys.stdin.read().strip()
    if not prompt:
        raise SystemExit("Empty prompt")

    out_path = (args.out or "").strip()
    if not out_path:
        raise SystemExit("Missing --out")
    out = Path(out_path)
    if out.suffix.lower() != ".png":
        out = out.with_suffix(".png")
    out.parent.mkdir(parents=True, exist_ok=True)

    model_path = _normalize_model_path(args.model)
    url = base_url.rstrip("/") + f"/v1beta/models/{model_path}:generateContent"
    headers = {
        "content-type": "application/json",
        "accept": "application/json",
        "user-agent": "openagentic-gemini-script/1.0 (python urllib)",
        # Cherry/New-API style keys are typically used as Bearer tokens.
        "authorization": f"Bearer {api_key}",
        # Also include Gemini-style header (harmless if ignored).
        "x-goog-api-key": api_key,
    }
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {
                "aspectRatio": str(args.aspect_ratio).strip() or "16:9",
                "imageSize": str(args.image_size).strip() or "1K",
            },
        },
    }

    last_err = "request_failed"
    retries = max(1, int(args.retries))
    for attempt in range(retries):
        resp = _http_post_json(url, headers, payload, float(args.timeout), opener=opener)
        if resp.get("ok", False):
            text = str(resp.get("text", "") or "")
            try:
                parsed = json.loads(text)
            except Exception as e:
                raise RuntimeError(f"Response was not JSON: {e}\n{text[:2000]}") from None

            pick = _find_first_inline_data(parsed)
            if pick is None:
                raise RuntimeError(f"No inline image data found. Response:\n{text[:4000]}")
            img_bytes, mime = pick
            if not img_bytes:
                raise RuntimeError("Decoded image bytes were empty")

            png = _to_png(
                img_bytes,
                mime=mime,
                width=int(args.width),
                height=int(args.height),
                resize=(not bool(args.no_resize)),
            )
            out.write_bytes(png)
            print(f"OK wrote={out} bytes={len(png)} source_mime={mime} url_host={urllib.parse.urlparse(base_url).hostname}")
            return 0

        status = int(resp.get("status", 0) or 0)
        text = str(resp.get("text", "") or "")
        reason = str(resp.get("reason", "") or "").strip()
        msg = str(resp.get("message", "") or "").strip()
        last_err = f"HTTP {status} {reason} {msg}".strip()
        if attempt < retries - 1:
            continue

        snippet = text.strip()
        if len(snippet) > 4000:
            snippet = snippet[:4000] + "\n...[truncated]..."
        if status == 403 and ("cloudflare" in snippet.lower() or "access denied" in snippet.lower() or "error 1010" in snippet.lower()):
            raise RuntimeError(
                (
                    "Gemini request failed: HTTP 403 (Cloudflare access denied)\n"
                    "你的 base_url 看起来被 Cloudflare 按地区/IP 限制了（常见于第三方代理域名）。\n"
                    "建议：换一个可访问的 Gemini 上游/代理域名（或更换出口网络）。\n\n"
                    + snippet
                ).rstrip()
            )
        raise RuntimeError(
            (
                f"Gemini request failed: {last_err}\n"
                + f"(base_url={base_url} base_url_src={base_url_src} api_key_src={api_key_src} proxy=disabled)\n"
                + snippet
            ).rstrip()
        )

    raise RuntimeError(last_err)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)

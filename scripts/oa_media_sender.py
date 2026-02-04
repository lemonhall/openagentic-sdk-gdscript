#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json
import os
import socket
import sys
import urllib.error
import urllib.request


def b64url_encode(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode("ascii").rstrip("=")


def encode_oamedia1(meta: dict) -> str:
    line = "OAMEDIA1 " + b64url_encode(json.dumps(meta, separators=(",", ":"), ensure_ascii=False).encode("utf-8"))
    if len(line) > 512:
        raise ValueError("OAMEDIA1 line exceeds 512 chars")
    return line


def irc_encode_lines(oamedia1_line: str, max_len: int) -> list[str]:
    line = oamedia1_line.strip()
    if not line.startswith("OAMEDIA1 "):
        raise ValueError("not an OAMEDIA1 line")
    if len(line) <= max_len:
        return [line]
    payload = line[len("OAMEDIA1 ") :].strip()
    if not payload:
        raise ValueError("missing payload")

    # Deterministic mid: sha256 prefix if present in payload meta, else fallback.
    mid = "m000000000000"
    try:
        meta = json.loads(base64.urlsafe_b64decode(payload + "=="))
        sha = str(meta.get("sha256", "")).strip().lower()
        if len(sha) >= 12:
            mid = sha[:12]
    except Exception:
        pass

    overhead = len("OAMEDIA1F ") + len(mid) + 1 + len("64/64") + 1
    max_payload = max_len - overhead
    if max_payload < 8:
        raise ValueError("max_len too small for fragmentation")

    parts = [payload[i : i + max_payload] for i in range(0, len(payload), max_payload)]
    if len(parts) > 64:
        raise ValueError("too many fragments")
    total = len(parts)
    return [f"OAMEDIA1F {mid} {i+1}/{total} {parts[i]}" for i in range(total)]


def http_post_upload(base_url: str, token: str, file_path: str, name: str | None, caption: str | None) -> dict:
    url = base_url.rstrip("/") + "/upload"
    with open(file_path, "rb") as f:
        body = f.read()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/octet-stream",
    }
    if name:
        headers["x-oa-name"] = name[:128]
    if caption:
        headers["x-oa-caption"] = caption[:128]
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
    except urllib.error.HTTPError as e:
        raw = b""
        try:
            raw = e.read() or b""
        except Exception:
            pass

        msg = f"upload failed: HTTP {getattr(e, 'code', '?')} {getattr(e, 'reason', '')}".strip()
        if raw:
            try:
                j = json.loads(raw.decode("utf-8", errors="replace"))
                err = (j.get("error") or "").strip()
                detail = (j.get("message") or "").strip()
                if err or detail:
                    msg = f"{msg}: {err} {detail}".strip()
            except Exception:
                snippet = raw[:4096].decode("utf-8", errors="replace").strip()
                if snippet:
                    msg = f"{msg}: {snippet}".strip()
        raise RuntimeError(msg) from None
    except urllib.error.URLError as e:
        raise RuntimeError(f"upload failed: {e}") from None

    j = json.loads(data.decode("utf-8", errors="replace"))
    if not j.get("ok", False):
        raise RuntimeError(f"upload failed: {j.get('error')} {j.get('message')}")
    return j


def irc_send(host: str, port: int, nick: str, channel: str, lines: list[str]) -> None:
    s = socket.create_connection((host, port), timeout=10)
    f = s.makefile("rwb", buffering=0)

    def send_line(x: str) -> None:
        f.write((x.rstrip("\r\n") + "\r\n").encode("utf-8"))

    send_line(f"NICK {nick}")
    send_line(f"USER {nick} 0 * :{nick}")
    send_line(f"JOIN {channel}")
    for l in lines:
        send_line(f"PRIVMSG {channel} :{l}")

    try:
        s.shutdown(socket.SHUT_RDWR)
    except Exception:
        pass
    s.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="Upload a media file and emit/send an OAMEDIA1 reference.")
    ap.add_argument("--file", required=True, help="Path to local file to upload")
    ap.add_argument("--media-base-url", default=os.environ.get("OPENAGENTIC_MEDIA_BASE_URL", ""), help="Media service base URL")
    ap.add_argument("--token", default=os.environ.get("OPENAGENTIC_MEDIA_BEARER_TOKEN", ""), help="Media service bearer token")
    ap.add_argument("--name", default="", help="Optional filename override")
    ap.add_argument("--caption", default="", help="Optional caption")
    ap.add_argument("--print-only", action="store_true", help="Only print the OAMEDIA1 line (do not send to IRC)")
    ap.add_argument("--irc-host", default="", help="IRC host")
    ap.add_argument("--irc-port", type=int, default=6667, help="IRC port")
    ap.add_argument("--irc-channel", default="#test", help="IRC channel")
    ap.add_argument("--irc-nick", default="oa_sender", help="IRC nick")
    ap.add_argument("--irc-max-len", type=int, default=360, help="Max IRC message length")
    args = ap.parse_args()

    if not args.media_base_url or not args.token:
        raise SystemExit("Missing --media-base-url/--token (or env OPENAGENTIC_MEDIA_BASE_URL/OPENAGENTIC_MEDIA_BEARER_TOKEN)")

    meta = http_post_upload(
        args.media_base_url,
        args.token,
        args.file,
        args.name or os.path.basename(args.file),
        args.caption or "",
    )

    # Sanity: verify sha256/bytes locally too (helps catch unexpected proxies).
    with open(args.file, "rb") as f:
        local = f.read()
    if meta.get("bytes") != len(local):
        raise RuntimeError("bytes mismatch")
    if meta.get("sha256") != hashlib.sha256(local).hexdigest():
        raise RuntimeError("sha256 mismatch")

    ref = {
        "id": meta["id"],
        "kind": meta["kind"],
        "mime": meta["mime"],
        "bytes": int(meta["bytes"]),
        "sha256": meta["sha256"],
    }
    if meta.get("name"):
        ref["name"] = meta["name"]
    if meta.get("caption"):
        ref["caption"] = meta["caption"]

    line = encode_oamedia1(ref)
    print(line)

    if args.print_only:
        return 0
    if not args.irc_host:
        return 0

    lines = irc_encode_lines(line, args.irc_max_len)
    irc_send(args.irc_host, args.irc_port, args.irc_nick, args.irc_channel, lines)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)

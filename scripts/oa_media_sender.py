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

from oa_dotenv import load_dotenv_file, load_repo_dotenv


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
    ap.add_argument("--env-file", default="", help="Optional path to a .env file (defaults to repo root .env if present)")
    ap.add_argument("--file", required=True, help="Path to local file to upload")
    ap.add_argument("--media-base-url", default="", help="Media service base URL (or env OPENAGENTIC_MEDIA_BASE_URL)")
    ap.add_argument("--token", default="", help="Media service bearer token (or env OPENAGENTIC_MEDIA_BEARER_TOKEN)")
    ap.add_argument("--name", default="", help="Optional filename override")
    ap.add_argument("--caption", default="", help="Optional caption")
    ap.add_argument("--print-only", action="store_true", help="Only print the OAMEDIA1 line (do not send to IRC)")
    ap.add_argument("--check", action="store_true", help="Validate config and exit (no upload)")
    ap.add_argument("--send", action="store_true", help="Send the reference to IRC (requires IRC config; otherwise prints only)")
    ap.add_argument("--irc-host", default=None, help="IRC host (or env OA_IRC_HOST)")
    ap.add_argument("--irc-port", type=int, default=None, help="IRC port (or env OA_IRC_PORT, default 6667)")
    ap.add_argument("--irc-channel", default=None, help="IRC channel (or env OA_SENDER_IRC_CHANNEL, default #test)")
    ap.add_argument("--irc-nick", default=None, help="IRC nick (or env OA_SENDER_IRC_NICK, default oa_sender)")
    ap.add_argument("--irc-max-len", type=int, default=None, help="Max IRC message length (or env OA_SENDER_IRC_MAX_LEN, default 360)")
    args = ap.parse_args()

    if args.env_file.strip():
        load_dotenv_file(args.env_file.strip(), override=False)
    else:
        load_repo_dotenv(override=False)

    media_base_url = (args.media_base_url or os.environ.get("OPENAGENTIC_MEDIA_BASE_URL", "")).strip()
    token = (args.token or os.environ.get("OPENAGENTIC_MEDIA_BEARER_TOKEN", "")).strip()

    irc_host = (args.irc_host if args.irc_host is not None else os.environ.get("OA_IRC_HOST", "")).strip()
    irc_port = int((args.irc_port if args.irc_port is not None else os.environ.get("OA_IRC_PORT", "6667")).strip() or "6667")
    irc_channel = (args.irc_channel if args.irc_channel is not None else os.environ.get("OA_SENDER_IRC_CHANNEL", "#test")).strip() or "#test"
    irc_nick = (args.irc_nick if args.irc_nick is not None else os.environ.get("OA_SENDER_IRC_NICK", "oa_sender")).strip() or "oa_sender"
    irc_max_len = int((args.irc_max_len if args.irc_max_len is not None else os.environ.get("OA_SENDER_IRC_MAX_LEN", "360")).strip() or "360")

    if not media_base_url or not token:
        raise SystemExit("Missing --media-base-url/--token (or env OPENAGENTIC_MEDIA_BASE_URL/OPENAGENTIC_MEDIA_BEARER_TOKEN)")

    if args.check:
        if not os.path.isfile(args.file):
            raise SystemExit(f"Missing file: {args.file}")
        want_send = args.send or (args.irc_host is not None)
        if want_send and not args.print_only:
            if not irc_host:
                raise SystemExit("Missing IRC host (--irc-host or env OA_IRC_HOST)")
            if not (1 <= irc_port <= 65535):
                raise SystemExit("Invalid IRC port")
            if not irc_channel.startswith("#"):
                raise SystemExit("IRC channel must start with #")
            if not irc_nick:
                raise SystemExit("Missing IRC nick")
            if irc_max_len < 64:
                raise SystemExit("IRC max len too small")
        print("OK")
        return 0

    meta = http_post_upload(
        media_base_url,
        token,
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

    want_send = args.send or (args.irc_host is not None)
    if not want_send or not irc_host:
        return 0

    lines = irc_encode_lines(line, irc_max_len)
    irc_send(irc_host, irc_port, irc_nick, irc_channel, lines)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)

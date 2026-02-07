#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import queue
import socket
import ssl
import threading
import time
from dataclasses import dataclass
from typing import Mapping, Optional

from oa_dotenv import load_repo_dotenv


@dataclass(frozen=True)
class IrcConfig:
    host: str
    port: int
    tls: bool
    password: str
    nick: str
    user: str
    realname: str


def _truthy(v: str) -> bool:
    return v.strip().lower() in {"1", "true", "yes", "y", "on"}


def _parse_int(v: str, default: int) -> int:
    try:
        return int(v.strip())
    except Exception:
        return default


def select_irc_config(env: Mapping[str, str]) -> IrcConfig:
    host = (env.get("VR_OFFICES_IRC_HOST") or "").strip() or (env.get("OA_IRC_HOST") or "").strip()
    port_s = (env.get("VR_OFFICES_IRC_PORT") or "").strip() or (env.get("OA_IRC_PORT") or "").strip() or "6667"
    tls_s = (env.get("VR_OFFICES_IRC_TLS") or "").strip() or (env.get("OA_IRC_TLS") or "").strip() or "0"
    password = (env.get("VR_OFFICES_IRC_PASSWORD") or "").strip() or (env.get("OA_IRC_PASSWORD") or "").strip()

    nick = "OAObserve"
    user = (env.get("OA_IRC_USER") or "").strip() or nick
    realname = (env.get("OA_IRC_REALNAME") or "").strip() or "OpenAgentic Tk IRC"

    return IrcConfig(
        host=host,
        port=_parse_int(port_s, 6667),
        tls=_truthy(tls_s),
        password=password,
        nick=nick,
        user=user,
        realname=realname,
    )


@dataclass(frozen=True)
class IrcMessage:
    prefix: Optional[str]
    command: str
    params: list[str]
    trailing: Optional[str]


def parse_irc_line(line: str) -> IrcMessage:
    s = line.rstrip("\r\n")
    prefix: Optional[str] = None

    if s.startswith(":"):
        rest = s[1:]
        if " " in rest:
            prefix, s = rest.split(" ", 1)
        else:
            prefix, s = rest, ""

    s = s.lstrip()
    if not s:
        return IrcMessage(prefix=prefix, command="", params=[], trailing=None)

    parts = s.split(" ")
    command = parts[0]
    params: list[str] = []
    trailing: Optional[str] = None

    i = 1
    while i < len(parts):
        p = parts[i]
        if p.startswith(":"):
            trailing = " ".join([p[1:]] + parts[i + 1 :])
            break
        if p:
            params.append(p)
        i += 1

    return IrcMessage(prefix=prefix, command=command, params=params, trailing=trailing)


@dataclass(frozen=True)
class ListItem:
    channel: str
    users: int
    topic: str


def parse_list_numeric(line: str) -> Optional[ListItem]:
    msg = parse_irc_line(line)
    if msg.command != "322":
        return None
    if len(msg.params) < 3:
        return None

    channel = msg.params[1]
    try:
        users = int(msg.params[2])
    except Exception:
        users = 0
    topic = msg.trailing or ""
    return ListItem(channel=channel, users=users, topic=topic)


def _normalize_nick(token: str) -> str:
    t = token.strip()
    while t and t[0] in {"~", "&", "@", "%", "+"}:
        t = t[1:]
    return t


def parse_names_numeric(line: str) -> Optional[tuple[str, list[str]]]:
    msg = parse_irc_line(line)
    if msg.command != "353":
        return None
    if len(msg.params) < 3:
        return None
    channel = msg.params[2]
    trailing = (msg.trailing or "").strip()
    if not trailing:
        return (channel, [])
    names: list[str] = []
    for raw in trailing.split(" "):
        n = _normalize_nick(raw)
        if n:
            names.append(n)
    return (channel, names)

def _format_irc_command(command: str) -> bytes:
    return (command.rstrip("\r\n") + "\r\n").encode("utf-8", errors="replace")


class IrcIoThread(threading.Thread):
    def __init__(
        self,
        *,
        config: IrcConfig,
        inbound: "queue.Queue[tuple[str, object]]",
        outbound: "queue.Queue[str]",
        stop_event: threading.Event,
    ) -> None:
        super().__init__(daemon=True)
        self._config = config
        self._inbound = inbound
        self._outbound = outbound
        self._stop_event = stop_event

        self._sock: socket.socket | ssl.SSLSocket | None = None
        self._buffer = b""
        self._registered = False
        self._pending_outbound: list[str] = []
        self._names_buf: dict[str, set[str]] = {}

    def _emit(self, kind: str, payload: object) -> None:
        try:
            self._inbound.put_nowait((kind, payload))
        except Exception:
            pass

    def _connect(self) -> None:
        raw = socket.create_connection((self._config.host, self._config.port), timeout=10)
        if self._config.tls:
            ctx = ssl.create_default_context()
            raw.settimeout(10)
            sock: socket.socket | ssl.SSLSocket = ctx.wrap_socket(raw, server_hostname=self._config.host)
            sock.settimeout(0.2)
            self._sock = sock
        else:
            raw.settimeout(0.2)
            self._sock = raw

        if self._config.password:
            self._send_now(f"PASS {self._config.password}")
        self._send_now(f"NICK {self._config.nick}")
        self._send_now(f"USER {self._config.user} 0 * :{self._config.realname}")

    def _send_now(self, line: str) -> None:
        if not self._sock:
            return
        self._sock.sendall(_format_irc_command(line))

    def _send_outbound_cmd(self, cmd: str) -> None:
        c = cmd.strip()
        if not c:
            return
        self._send_now(c)
        if c.upper().startswith("JOIN "):
            parts = c.split()
            if len(parts) >= 2:
                channel = parts[1]
                if channel:
                    self._send_now(f"NAMES {channel}")

    def _recv_lines(self) -> list[str]:
        if not self._sock:
            return []
        try:
            chunk = self._sock.recv(4096)
        except socket.timeout:
            return []
        if not chunk:
            raise ConnectionError("Server closed connection")
        self._buffer += chunk
        out: list[str] = []
        while b"\n" in self._buffer:
            raw_line, self._buffer = self._buffer.split(b"\n", 1)
            raw_line = raw_line.rstrip(b"\r")
            out.append(raw_line.decode("utf-8", errors="replace"))
        return out

    def run(self) -> None:
        try:
            self._connect()
            self._emit("status", "connected")
        except Exception as e:
            self._emit("status", f"connect_failed: {e}")
            self._stop_event.set()
            return

        try:
            while True:
                try:
                    while True:
                        cmd = self._outbound.get_nowait()
                        if cmd.startswith("QUIT"):
                            self._send_now(cmd)
                        elif self._registered:
                            self._send_outbound_cmd(cmd)
                        else:
                            self._pending_outbound.append(cmd)
                except queue.Empty:
                    pass
                if self._stop_event.is_set():
                    break

                try:
                    for line in self._recv_lines():
                        msg = parse_irc_line(line)
                        if (not self._registered) and msg.command == "001":
                            self._registered = True
                            self._emit("status", "registered")
                            for cmd in self._pending_outbound:
                                if cmd.startswith("QUIT"):
                                    self._send_now(cmd)
                                else:
                                    self._send_outbound_cmd(cmd)
                            self._pending_outbound.clear()
                        if msg.command == "PING":
                            token = msg.trailing or (msg.params[0] if msg.params else "")
                            self._send_now(f"PONG :{token}")
                            continue
                        item = parse_list_numeric(line)
                        if item is not None:
                            self._emit("list_item", item)
                            continue
                        names_item = parse_names_numeric(line)
                        if names_item is not None:
                            channel, names = names_item
                            buf = self._names_buf.setdefault(channel, set())
                            for n in names:
                                buf.add(n)
                            continue
                        elif msg.command == "323":
                            self._emit("list_end", None)
                            continue
                        elif msg.command == "366":
                            if len(msg.params) >= 2:
                                channel = msg.params[1]
                                names = sorted(self._names_buf.get(channel, set()))
                                self._names_buf.pop(channel, None)
                                self._emit("names", (channel, names))
                            continue
                        elif msg.command == "PRIVMSG":
                            self._emit("privmsg", msg)
                        else:
                            self._emit("raw", line)
                except socket.timeout:
                    pass
                except Exception as e:
                    self._emit("status", f"disconnected: {e}")
                    self._stop_event.set()
                    break

                time.sleep(0.01)
        finally:
            try:
                if self._sock:
                    self._sock.close()
            except Exception:
                pass
            self._emit("status", "stopped")


def run_self_test() -> int:
    cfg = select_irc_config(
        {
            "OA_IRC_HOST": "irc.example",
            "OA_IRC_PORT": "6667",
            "OA_IRC_USER": "me",
            "OA_IRC_REALNAME": "Me",
        }
    )
    assert cfg.host == "irc.example"
    assert cfg.port == 6667
    assert cfg.nick == "OAObserve"

    msg = parse_irc_line(":nick!u@h PRIVMSG #chan :hello world")
    assert msg.command == "PRIVMSG"
    assert msg.params == ["#chan"]
    assert msg.trailing == "hello world"

    item = parse_list_numeric(":irc.example 322 me #test 42 :topic here")
    assert item and item.channel == "#test" and item.users == 42

    names = parse_names_numeric(":irc.example 353 me = #test :@alice +bob carol")
    assert names and names[0] == "#test" and sorted(names[1]) == ["alice", "bob", "carol"]
    return 0


def _build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Simple Tkinter IRC client for monitoring an IRC server configured by .env (OA_IRC_* / VR_OFFICES_IRC_*)."
    )
    p.add_argument("--self-test", action="store_true", help="Run a no-network self-test and exit.")
    return p


def main(argv: Optional[list[str]] = None) -> int:
    args = _build_arg_parser().parse_args(argv)
    if args.self_test:
        return run_self_test()

    load_repo_dotenv(override=False)
    cfg = select_irc_config(os.environ)
    if not cfg.host:
        raise SystemExit("Missing IRC host. Set VR_OFFICES_IRC_HOST or OA_IRC_HOST in .env.")

    import tkinter as tk
    from tkinter import messagebox, ttk

    root = tk.Tk()
    root.title("IRC Monitor (Tk)")

    status_var = tk.StringVar(value="disconnected")
    host_var = tk.StringVar(value=cfg.host)
    port_var = tk.StringVar(value=str(cfg.port))
    tls_var = tk.BooleanVar(value=cfg.tls)
    nick_var = tk.StringVar(value=cfg.nick)
    password_var = tk.StringVar(value=cfg.password)

    inbound: "queue.Queue[tuple[str, object]]" = queue.Queue()
    outbound: "queue.Queue[str]" = queue.Queue()
    stop_event = threading.Event()
    io_thread: IrcIoThread | None = None

    channels: list[ListItem] = []
    topic_var = tk.StringVar(value="")

    def ui_log(line: str) -> None:
        out_text.configure(state="normal")
        out_text.insert("end", line + "\n")
        out_text.see("end")
        out_text.configure(state="disabled")

    def set_status(s: str) -> None:
        status_var.set(s)

    def current_config() -> IrcConfig:
        nick = nick_var.get().strip() or "OAObserve"
        user = (os.environ.get("OA_IRC_USER") or "").strip() or nick
        realname = (os.environ.get("OA_IRC_REALNAME") or "").strip() or "OpenAgentic Tk IRC"
        return IrcConfig(
            host=host_var.get().strip(),
            port=_parse_int(port_var.get(), 6667),
            tls=bool(tls_var.get()),
            password=password_var.get(),
            nick=nick,
            user=user,
            realname=realname,
        )

    def connect() -> None:
        nonlocal io_thread
        if io_thread and io_thread.is_alive():
            messagebox.showinfo("Already connected", "Disconnect first.")
            return
        stop_event.clear()
        channels.clear()
        chan_list.delete(0, "end")
        out_text.configure(state="normal")
        out_text.delete("1.0", "end")
        out_text.configure(state="disabled")

        try:
            c = current_config()
            if not c.host:
                messagebox.showerror("Missing host", "Set host first.")
                return
            set_status("connecting…")
            io_thread = IrcIoThread(config=c, inbound=inbound, outbound=outbound, stop_event=stop_event)
            io_thread.start()
        except Exception as e:
            set_status("disconnected")
            messagebox.showerror("Connect failed", str(e))

    def disconnect() -> None:
        outbound.put("QUIT :bye")
        stop_event.set()
        set_status("disconnecting…")

    def list_channels() -> None:
        if not io_thread or not io_thread.is_alive():
            messagebox.showerror("Not connected", "Connect first.")
            return
        channels.clear()
        chan_list.delete(0, "end")
        topic_var.set("")
        outbound.put("LIST")
        ui_log(">> LIST")

    def join_selected() -> None:
        if not io_thread or not io_thread.is_alive():
            messagebox.showerror("Not connected", "Connect first.")
            return
        sel = chan_list.curselection()
        if not sel:
            messagebox.showerror("No selection", "Select a channel from the list.")
            return
        item = channels[sel[0]]
        outbound.put(f"JOIN {item.channel}")
        outbound.put(f"NAMES {item.channel}")
        ui_log(f">> JOIN {item.channel}")

    def on_channel_select(_evt: object = None) -> None:
        sel = chan_list.curselection()
        if not sel:
            topic_var.set("")
            return
        item = channels[sel[0]]
        topic_var.set(item.topic)

    def on_channel_activate(_evt: object = None) -> None:
        on_channel_select()
        try:
            join_selected()
        except Exception:
            pass

    def refresh_names() -> None:
        if not io_thread or not io_thread.is_alive():
            messagebox.showerror("Not connected", "Connect first.")
            return
        sel = chan_list.curselection()
        if not sel:
            messagebox.showerror("No selection", "Select a channel from the list.")
            return
        item = channels[sel[0]]
        outbound.put(f"NAMES {item.channel}")
        ui_log(f">> NAMES {item.channel}")

    def pump_inbound() -> None:
        processed = 0
        while processed < 400:
            try:
                kind, payload = inbound.get_nowait()
            except queue.Empty:
                break

            if kind == "status":
                set_status(str(payload))
                ui_log(f"** {payload}")
            elif kind == "raw":
                ui_log(payload)  # type: ignore[arg-type]
            elif kind == "list_item":
                item = payload  # type: ignore[assignment]
                assert isinstance(item, ListItem)
                channels.append(item)
                chan_list.insert("end", f"{item.channel} ({item.users})")
            elif kind == "list_end":
                ui_log("** LIST done")
            elif kind == "privmsg":
                msg = payload  # type: ignore[assignment]
                assert isinstance(msg, IrcMessage)
                target = msg.params[0] if msg.params else ""
                who = (msg.prefix or "").split("!", 1)[0] if msg.prefix else ""
                text = msg.trailing or ""
                ui_log(f"[{target}] <{who}> {text}")
            elif kind == "names":
                channel, names = payload  # type: ignore[assignment]
                if isinstance(channel, str) and isinstance(names, list):
                    sel = chan_list.curselection()
                    if sel:
                        idx = sel[0]
                        if 0 <= idx < len(channels) and channels[idx].channel == channel:
                            users_list.delete(0, "end")
                            for n in names:
                                users_list.insert("end", n)
            processed += 1

        root.after(10 if processed >= 400 else 50, pump_inbound)

    top = ttk.Frame(root, padding=8)
    top.pack(fill="both", expand=True)

    row = 0
    ttk.Label(top, text="Host").grid(row=row, column=0, sticky="w")
    ttk.Entry(top, textvariable=host_var, width=28).grid(row=row, column=1, sticky="we")
    ttk.Label(top, text="Port").grid(row=row, column=2, sticky="w", padx=(8, 0))
    ttk.Entry(top, textvariable=port_var, width=8).grid(row=row, column=3, sticky="w")
    ttk.Checkbutton(top, text="TLS", variable=tls_var).grid(row=row, column=4, sticky="w", padx=(8, 0))

    row += 1
    ttk.Label(top, text="Nick").grid(row=row, column=0, sticky="w")
    ttk.Entry(top, textvariable=nick_var, width=20).grid(row=row, column=1, sticky="we")
    ttk.Label(top, text="Password").grid(row=row, column=2, sticky="w", padx=(8, 0))
    ttk.Entry(top, textvariable=password_var, width=20, show="*").grid(row=row, column=3, columnspan=2, sticky="we")

    row += 1
    ttk.Button(top, text="Connect", command=connect).grid(row=row, column=0, sticky="we", pady=(6, 0))
    ttk.Button(top, text="Disconnect", command=disconnect).grid(row=row, column=1, sticky="we", pady=(6, 0))
    ttk.Button(top, text="LIST", command=list_channels).grid(row=row, column=2, sticky="we", pady=(6, 0))
    ttk.Button(top, text="JOIN selected", command=join_selected).grid(row=row, column=3, columnspan=2, sticky="we", pady=(6, 0))

    row += 1
    ttk.Label(top, textvariable=status_var).grid(row=row, column=0, columnspan=5, sticky="w", pady=(6, 0))

    row += 1
    paned = ttk.PanedWindow(top, orient="horizontal")
    paned.grid(row=row, column=0, columnspan=5, sticky="nsew", pady=(8, 0))

    left = ttk.Frame(paned, padding=(0, 0, 8, 0))
    right = ttk.Frame(paned)
    paned.add(left, weight=1)
    paned.add(right, weight=3)

    ttk.Label(left, text="Channels").pack(anchor="w")
    chan_list = tk.Listbox(left, height=18)
    chan_list.pack(fill="both", expand=True)
    chan_list.bind("<Double-Button-1>", on_channel_activate)
    chan_list.bind("<Return>", on_channel_activate)
    chan_list.bind("<<ListboxSelect>>", on_channel_select)
    ttk.Label(left, textvariable=topic_var, wraplength=260).pack(anchor="w", pady=(6, 0))
    ttk.Button(left, text="NAMES (selected)", command=refresh_names).pack(fill="x", pady=(8, 0))
    ttk.Label(left, text="Users").pack(anchor="w", pady=(8, 0))
    users_list = tk.Listbox(left, height=10)
    users_list.pack(fill="both", expand=False)

    ttk.Label(right, text="Messages / Raw").pack(anchor="w")
    out_text = tk.Text(right, height=18, width=100, state="disabled")
    out_text.pack(fill="both", expand=True)

    top.columnconfigure(1, weight=1)
    top.rowconfigure(row, weight=1)

    root.after(50, pump_inbound)
    root.protocol("WM_DELETE_WINDOW", lambda: (stop_event.set(), root.destroy()))
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

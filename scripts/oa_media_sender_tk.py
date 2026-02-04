#!/usr/bin/env python3
import os
import subprocess
import sys
import tkinter as tk
from tkinter import filedialog, messagebox


def run_cli(file_path: str, base_url: str, token: str, caption: str, irc_host: str, irc_port: str, irc_channel: str, irc_nick: str) -> str:
    cmd = [
        sys.executable,
        os.path.join(os.path.dirname(__file__), "oa_media_sender.py"),
        "--file",
        file_path,
        "--media-base-url",
        base_url,
        "--token",
        token,
    ]
    if caption.strip():
        cmd += ["--caption", caption.strip()]
    if irc_host.strip():
        cmd += ["--irc-host", irc_host.strip(), "--irc-port", str(int(irc_port)), "--irc-channel", irc_channel.strip(), "--irc-nick", irc_nick.strip()]
    else:
        cmd += ["--print-only"]
    out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
    return out.strip()


def main() -> int:
    root = tk.Tk()
    root.title("OpenAgentic Media Sender")

    file_var = tk.StringVar()
    base_var = tk.StringVar(value=os.environ.get("OPENAGENTIC_MEDIA_BASE_URL", "http://127.0.0.1:8788"))
    token_var = tk.StringVar(value=os.environ.get("OPENAGENTIC_MEDIA_BEARER_TOKEN", ""))
    caption_var = tk.StringVar()

    irc_host_var = tk.StringVar()
    irc_port_var = tk.StringVar(value="6667")
    irc_channel_var = tk.StringVar(value="#test")
    irc_nick_var = tk.StringVar(value="oa_sender")

    def pick_file() -> None:
        p = filedialog.askopenfilename()
        if p:
            file_var.set(p)

    def send() -> None:
        try:
            if not file_var.get().strip():
                messagebox.showerror("Missing file", "Choose a file first.")
                return
            if not base_var.get().strip() or not token_var.get().strip():
                messagebox.showerror("Missing config", "Set media base URL and token.")
                return
            line = run_cli(
                file_var.get().strip(),
                base_var.get().strip(),
                token_var.get().strip(),
                caption_var.get(),
                irc_host_var.get(),
                irc_port_var.get(),
                irc_channel_var.get(),
                irc_nick_var.get(),
            )
            out_text.delete("1.0", "end")
            out_text.insert("1.0", line + "\n")
        except subprocess.CalledProcessError as e:
            out_text.delete("1.0", "end")
            out_text.insert("1.0", e.output)
            messagebox.showerror("Send failed", "See output for details.")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    frm = tk.Frame(root)
    frm.pack(fill="both", expand=True, padx=8, pady=8)

    out_text = tk.Text(frm, height=6, width=80)

    row = 0
    tk.Label(frm, text="File").grid(row=row, column=0, sticky="w")
    tk.Entry(frm, textvariable=file_var, width=60).grid(row=row, column=1, sticky="we")
    tk.Button(frm, text="Browse…", command=pick_file).grid(row=row, column=2, sticky="e")

    row += 1
    tk.Label(frm, text="Media Base URL").grid(row=row, column=0, sticky="w")
    tk.Entry(frm, textvariable=base_var, width=60).grid(row=row, column=1, columnspan=2, sticky="we")

    row += 1
    tk.Label(frm, text="Bearer Token").grid(row=row, column=0, sticky="w")
    tk.Entry(frm, textvariable=token_var, width=60, show="*").grid(row=row, column=1, columnspan=2, sticky="we")

    row += 1
    tk.Label(frm, text="Caption").grid(row=row, column=0, sticky="w")
    tk.Entry(frm, textvariable=caption_var, width=60).grid(row=row, column=1, columnspan=2, sticky="we")

    row += 1
    tk.Label(frm, text="IRC Host (optional)").grid(row=row, column=0, sticky="w")
    tk.Entry(frm, textvariable=irc_host_var, width=30).grid(row=row, column=1, sticky="we")
    tk.Entry(frm, textvariable=irc_port_var, width=8).grid(row=row, column=2, sticky="e")

    row += 1
    tk.Label(frm, text="IRC Channel").grid(row=row, column=0, sticky="w")
    tk.Entry(frm, textvariable=irc_channel_var, width=30).grid(row=row, column=1, sticky="we")
    tk.Entry(frm, textvariable=irc_nick_var, width=12).grid(row=row, column=2, sticky="e")

    row += 1
    tk.Button(frm, text="Upload (and send if IRC host set)", command=send).grid(row=row, column=0, columnspan=3, sticky="we", pady=(8, 4))

    row += 1
    tk.Label(frm, text="Output (OAMEDIA1 line)").grid(row=row, column=0, sticky="w")
    row += 1
    out_text.grid(row=row, column=0, columnspan=3, sticky="nsew")

    frm.columnconfigure(1, weight=1)
    frm.rowconfigure(row, weight=1)

    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

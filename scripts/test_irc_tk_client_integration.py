import os
import queue
import socket
import sys
import threading
import time
import unittest


SCRIPTS_DIR = os.path.dirname(__file__)
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)


def _recv_lines(conn: socket.socket, buf: bytearray) -> list[str]:
    try:
        chunk = conn.recv(4096)
    except socket.timeout:
        return []
    if not chunk:
        raise ConnectionError("client closed")
    buf.extend(chunk)
    out: list[str] = []
    while b"\n" in buf:
        raw, _, rest = buf.partition(b"\n")
        del buf[: len(raw) + 1]
        raw = raw.rstrip(b"\r")
        out.append(raw.decode("utf-8", errors="replace"))
    return out


def _send_line(conn: socket.socket, line: str) -> None:
    conn.sendall((line.rstrip("\r\n") + "\r\n").encode("utf-8"))


class _MiniIrcServer(threading.Thread):
    def __init__(self) -> None:
        super().__init__(daemon=True)
        self.ready = threading.Event()
        self.stop = threading.Event()
        self.error: Exception | None = None

        self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._sock.bind(("127.0.0.1", 0))
        self._sock.listen(1)
        self.port = self._sock.getsockname()[1]

    def run(self) -> None:
        try:
            self.ready.set()
            conn, _addr = self._sock.accept()
            with conn:
                conn.settimeout(0.2)
                buf = bytearray()

                saw_nick = False
                saw_user = False
                saw_pong = False

                deadline = time.time() + 5
                while time.time() < deadline and not (saw_nick and saw_user):
                    for line in _recv_lines(conn, buf):
                        if line.startswith("NICK "):
                            saw_nick = True
                        if line.startswith("USER "):
                            saw_user = True
                    time.sleep(0.01)

                if not (saw_nick and saw_user):
                    raise AssertionError("did not receive NICK/USER handshake")

                _send_line(conn, ":irc.example 001 me :welcome")
                _send_line(conn, "PING :pingtoken")

                saw_list = False
                saw_join = False
                saw_names_req = False

                deadline = time.time() + 5
                while time.time() < deadline and not (saw_pong and saw_list and saw_join and saw_names_req):
                    for line in _recv_lines(conn, buf):
                        if line == "PONG :pingtoken":
                            saw_pong = True
                        if line == "LIST":
                            saw_list = True
                            _send_line(conn, ":irc.example 322 me #chan1 5 :topic1")
                            _send_line(conn, ":irc.example 322 me #chan2 2 :topic2")
                            _send_line(conn, ":irc.example 323 me :End of /LIST")
                        if line == "JOIN #chan1":
                            saw_join = True
                            _send_line(conn, ":alice!u@h PRIVMSG #chan1 :hello")
                        if line == "NAMES #chan1":
                            saw_names_req = True
                            _send_line(conn, ":irc.example 353 me = #chan1 :@alice +bob carol")
                            _send_line(conn, ":irc.example 366 me #chan1 :End of /NAMES list.")
                    time.sleep(0.01)

                if not saw_pong:
                    raise AssertionError("did not receive PONG response to PING")
                if not saw_list:
                    raise AssertionError("did not receive LIST")
                if not saw_join:
                    raise AssertionError("did not receive JOIN")
                if not saw_names_req:
                    raise AssertionError("did not receive NAMES")

                while not self.stop.is_set():
                    time.sleep(0.05)
        except Exception as e:
            self.error = e
        finally:
            try:
                self._sock.close()
            except Exception:
                pass


class TestIrcIoThreadIntegration(unittest.TestCase):
    def test_list_and_join_and_ping_pong(self) -> None:
        import irc_tk_client as m

        server = _MiniIrcServer()
        server.start()
        self.assertTrue(server.ready.wait(timeout=2))

        inbound: "queue.Queue[tuple[str, object]]" = queue.Queue()
        outbound: "queue.Queue[str]" = queue.Queue()
        stop_event = threading.Event()

        cfg = m.IrcConfig(
            host="127.0.0.1",
            port=server.port,
            tls=False,
            password="",
            nick="me",
            user="me",
            realname="Me",
        )

        t = m.IrcIoThread(config=cfg, inbound=inbound, outbound=outbound, stop_event=stop_event)
        t.start()

        connected = False
        deadline = time.time() + 5
        while time.time() < deadline and not connected:
            try:
                kind, payload = inbound.get(timeout=0.2)
            except queue.Empty:
                continue
            if kind == "status" and payload == "connected":
                connected = True
        self.assertTrue(connected)

        outbound.put("LIST")
        outbound.put("JOIN #chan1")

        list_items: list[m.ListItem] = []
        saw_list_end = False
        saw_privmsg = False
        saw_names = False

        deadline = time.time() + 5
        while time.time() < deadline and not (saw_list_end and saw_privmsg and saw_names):
            try:
                kind, payload = inbound.get(timeout=0.2)
            except queue.Empty:
                continue
            if kind == "list_item":
                assert isinstance(payload, m.ListItem)
                list_items.append(payload)
            elif kind == "list_end":
                saw_list_end = True
            elif kind == "privmsg":
                assert isinstance(payload, m.IrcMessage)
                self.assertEqual(payload.params, ["#chan1"])
                self.assertEqual(payload.trailing, "hello")
                saw_privmsg = True
            elif kind == "names":
                channel, names = payload  # type: ignore[assignment]
                self.assertEqual(channel, "#chan1")
                self.assertEqual(sorted(names), ["alice", "bob", "carol"])
                saw_names = True

        stop_event.set()
        server.stop.set()
        t.join(timeout=2)
        server.join(timeout=2)

        if server.error:
            raise server.error

        self.assertTrue(saw_list_end)
        self.assertTrue(saw_privmsg)
        self.assertTrue(saw_names)
        self.assertEqual([i.channel for i in list_items], ["#chan1", "#chan2"])


if __name__ == "__main__":
    unittest.main()

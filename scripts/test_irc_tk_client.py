import os
import sys
import unittest


SCRIPTS_DIR = os.path.dirname(__file__)
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)


class TestEnvConfig(unittest.TestCase):
    def test_selects_vr_offices_over_oa_defaults(self) -> None:
        import irc_tk_client as m

        cfg = m.select_irc_config(
            {
                "OA_IRC_HOST": "oa.example",
                "OA_IRC_PORT": "6667",
                "VR_OFFICES_IRC_HOST": "vr.example",
                "VR_OFFICES_IRC_PORT": "6697",
                "VR_OFFICES_IRC_TLS": "1",
            }
        )
        self.assertEqual(cfg.host, "vr.example")
        self.assertEqual(cfg.port, 6697)
        self.assertTrue(cfg.tls)

    def test_defaults_port_and_nick(self) -> None:
        import irc_tk_client as m

        cfg = m.select_irc_config({"OA_IRC_HOST": "irc.local"})
        self.assertEqual(cfg.host, "irc.local")
        self.assertEqual(cfg.port, 6667)
        self.assertEqual(cfg.nick, "OAObserve")

    def test_ignores_env_nick(self) -> None:
        import irc_tk_client as m

        cfg = m.select_irc_config({"OA_IRC_HOST": "irc.local", "OA_IRC_NICK": "NotThis"})
        self.assertEqual(cfg.nick, "OAObserve")


class TestIrcLineParsing(unittest.TestCase):
    def test_parse_privmsg(self) -> None:
        import irc_tk_client as m

        msg = m.parse_irc_line(":nick!u@h PRIVMSG #chan :hello world")
        self.assertEqual(msg.prefix, "nick!u@h")
        self.assertEqual(msg.command, "PRIVMSG")
        self.assertEqual(msg.params, ["#chan"])
        self.assertEqual(msg.trailing, "hello world")

    def test_parse_ping(self) -> None:
        import irc_tk_client as m

        msg = m.parse_irc_line("PING :server.example")
        self.assertIsNone(msg.prefix)
        self.assertEqual(msg.command, "PING")
        self.assertEqual(msg.params, [])
        self.assertEqual(msg.trailing, "server.example")


class TestListParsing(unittest.TestCase):
    def test_parse_list_322(self) -> None:
        import irc_tk_client as m

        item = m.parse_list_numeric(":irc.example 322 me #test 42 :topic here")
        self.assertIsNotNone(item)
        assert item is not None
        self.assertEqual(item.channel, "#test")
        self.assertEqual(item.users, 42)
        self.assertEqual(item.topic, "topic here")

    def test_parse_list_non_322_is_none(self) -> None:
        import irc_tk_client as m

        self.assertIsNone(m.parse_list_numeric(":irc.example 323 me :End of /LIST"))


if __name__ == "__main__":
    unittest.main()

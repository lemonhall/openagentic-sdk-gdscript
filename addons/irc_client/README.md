# IRC Client (GDScript) — v16 Core

This folder contains a pure-GDScript IRC client addon for Godot 4.6.

## Minimal usage

```gdscript
var IrcClient := preload("res://addons/irc_client/IrcClient.gd")

var irc: Node

func _ready() -> void:
	irc = IrcClient.new()
	add_child(irc)

	irc.connected.connect(func(): print("irc connected"))
	irc.disconnected.connect(func(): print("irc disconnected"))
	irc.error.connect(func(e: String): push_error(e))
	irc.message_received.connect(func(msg: RefCounted): print(msg.command, " ", msg.params, " ", msg.trailing))

	irc.set_nick("my_nick")
	irc.set_user("my_user", "0", "*", "My Real Name")
	irc.connect_to("irc.example.org", 6667)

func _process(_dt: float) -> void:
	irc.poll()
```

Then you can call:

- `irc.join("#channel")`
- `irc.privmsg("#channel", "hello")`
- `irc.quit("bye")` (or `irc.close_connection()`)

Versioning (project plans):

- v16: core IRC over plain TCP (no TLS, no IRCv3).
- v17: TLS + IRCv3 basics (CAP/SASL/tags).
- v18: client UX (reconnect/state/CTCP/history).

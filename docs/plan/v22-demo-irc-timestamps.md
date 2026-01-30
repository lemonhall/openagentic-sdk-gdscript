# v22 Plan — Demo IRC (Timestamps)

## Goal

Add a timestamp prefix to `demo_irc` chat log lines so debugging server replies and user actions is easier.

## Scope

- Prefix every appended chat line with a timestamp in local time: `[HH:MM:SS]`.
- Use a pure helper to keep formatting testable and avoid Node dependencies.

## Non-Goals (v22)

- Persisting timestamps into history.
- Timezone selection / 12h format.
- Separate timestamp per message type.

## Acceptance

- Appending any log line results in: `[HH:MM:SS] <original line>`.
- Timestamp uses BBCode-safe literal brackets (`[lb]` / `[rb]`) so it renders correctly in `RichTextLabel` with BBCode enabled.

## Files

Create:
- `demo_irc/DemoIrcLogFormat.gd`
- `tests/test_demo_irc_timestamp_format.gd`

Modify:
- `demo_irc/Main.gd`

Docs:
- `docs/plan/v22-index.md`
- `docs/plan/v22-demo-irc-timestamps.md`

## Steps (塔山开发循环)

### 1) Red

- Add `tests/test_demo_irc_timestamp_format.gd`:
  - Given `time_str="01:02:03"` and `line="Hello"`, output should be `[color=gray][lb]01:02:03[rb][/color] Hello`.
- Run headless; expect FAIL.

### 2) Green

- Implement `DemoIrcLogFormat.format_prefix(time_str)` and `prepend(time_str, line)`.
- Update `Main.gd` to call `Time.get_time_string_from_system()` and prefix lines before appending.
- Re-run; expect PASS.

### 3) Verify

- Run `tests/test_demo_irc_*.gd` headless.


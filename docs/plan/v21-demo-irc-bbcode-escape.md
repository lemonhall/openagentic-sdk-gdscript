# v21 Plan — Demo IRC (BBCode Escaping Fix)

## Goal

Fix `demo_irc` diagnostic rendering so raw/numeric IRC lines containing `[` / `]` display correctly in a `RichTextLabel` with BBCode enabled.

## Scope

- Fix `demo_irc/DemoIrcInbound.gd` BBCode escaping implementation.
- Add a regression test that fails with the current broken escaping and passes after the fix.

## Non-Goals (v21)

- UI redesign.
- Any IRC protocol changes.

## Acceptance

- Escaping `[432] Nickname too long` results in a string that renders brackets correctly via BBCode escape tags.
- The escape routine must not rewrite the tags it introduces.

## Files

Modify:
- `demo_irc/DemoIrcInbound.gd`

Create tests:
- `tests/test_demo_irc_bbcode_escape.gd`

Docs:
- `docs/plan/v21-index.md`
- `docs/plan/v21-demo-irc-bbcode-escape.md`

## Steps (塔山开发循环)

### 1) Red

- Add `tests/test_demo_irc_bbcode_escape.gd` to assert escaping:
  - Input: `[432] Nickname too long`
  - Output: `[lb]432[rb] Nickname too long` (no malformed tokens like `[lb[rb]`)
- Run headless; expect FAIL.

### 2) Green

- Implement safe escaping using placeholders (or equivalent) so introduced tags are not re-escaped.
- Re-run test; expect PASS.

### 3) Verify

- Run `tests/test_demo_irc_*.gd` headless.

## Risks

- Godot BBCode escaping rules: keep the test focused on the exact escape format used by RichTextLabel.


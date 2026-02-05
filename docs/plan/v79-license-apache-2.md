# v79 — Add Apache-2.0 license

## Goal

Make licensing explicit for publishing to the Godot Asset Library.

## Scope

- Add `LICENSE` with the full Apache License 2.0 text
- Update root README(s) to:
  - state that code is Apache-2.0 licensed
  - clarify that third-party assets have their own licenses (Kenney CC0)

## Non-goals

- Adding a `NOTICE` file (only needed if we have required notices to carry)
- Changing file headers across the codebase
- Changing any runtime behavior

## Acceptance

- `LICENSE` exists at repo root and contains Apache 2.0
- `README.md` and `README.zh-CN.md` both clearly state Apache-2.0 for code and CC0 for Kenney assets

## Files

- Add: `LICENSE`
- Update:
  - `README.md`
  - `README.zh-CN.md`

## Verification / Evidence

- `rg -n "Apache-2\\.0|LICENSE" README.md README.zh-CN.md`

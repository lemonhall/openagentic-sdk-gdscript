<!--
  v51 — VR Offices: Dialogue attachment UI (send media from chat)
-->

# v51 — Dialogue Attachment UI (Send Media From Chat)

## Vision (this version)

Make multimedia messaging feel native in VR Offices:

- From the NPC dialogue overlay, a human can attach and send media directly (no external scripts required).
- Supports multi-select and drag-and-drop with a visible upload queue and progress.

## Milestones

| Milestone | Scope | DoD | Verify | Status |
|---|---|---|---|---|
| M1 | UI | Attach button + drag-drop; multi-file queue with progress/cancel; clear errors | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_attachments_ui.gd` | todo |
| M2 | Upload | Client uploads to media service and sends `OAMEDIA1`/`OAMEDIA1F` lines; no token/path leaks | `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vr_offices_dialogue_attachments_upload.gd` | todo |
| M3 | Docs | Player-facing doc explains how to use attachments in `DialogueOverlay` | `rg -n \"附件|Attach|拖拽\" docs/vr_offices/multimedia_messages.zh-CN.md` | todo |

## PRD Trace

- REQ-010, REQ-011, REQ-012 (in-chat attachment UI)

PRD: `docs/prd/2026-02-04-vr-offices-multimedia-messages.md`

## Plan Index

- `docs/plan/v51-vr-offices-dialogue-attachments-ui.md`

## Evidence

TBD.

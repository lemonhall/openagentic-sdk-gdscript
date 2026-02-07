# VR Offices: Meeting Room Mic + Group Chat PRD

## Vision

Meeting Rooms are meant for “group coordination” scenarios. Each Meeting Room should spawn with an interactive **microphone** on the meeting table. Double-clicking the microphone opens a dedicated **meeting room group chat overlay**.

The group chat UI should look like the existing NPC Dialogue overlay, but must be **independent** (no cross-talk with NPC chat sessions). Meeting-room chat does **not** include NPC skills management.

## Requirements

### REQ-001 — Auto-place microphone on meeting table

- When a Meeting Room is spawned (newly created or loaded), it should include:
  - `assets/meeting_room/mic.glb`
- Mic placement:
  - sits on the **table top**
  - placed near **one end** of the table
  - has a simple, exposed “yaw” parameter for manual rotation tuning (90° etc.)

### REQ-002 — Mic shows an always-on interaction indicator

- Mic should show a “green diamond” indicator (same visual language as NPC selection plumbob).
- The indicator:
  - is a reusable, independent scene/module (not a copy-paste inside meeting room code)
  - floats above the mic (bob up/down) and stays visible long-term

### REQ-003 — Meeting table blocks NPC movement (collision)

- The meeting table must have a physics collider so NPCs cannot walk through it.
- The collider should be derived from the table model bounds and follow the table transform.

### REQ-004 — Double-click mic opens Meeting Room group chat overlay

- Double-clicking the mic opens a meeting-room chat overlay.
- UI style:
  - reuse the existing `DialogueOverlay` look & feel
  - **no skills UI** (skills button hidden/disabled)
  - keep “clear session log” functionality (can be refined later)
- Session isolation:
  - Meeting-room chat must use a stable, deterministic chat identity derived from `meeting_room_id`
  - it must not interfere with NPC chat sessions or manager dialogue overlay
- Input behavior:
  - when the meeting-room chat overlay is open, camera controls should be disabled
  - closing the overlay restores camera controls

### REQ-005 — Regression tests

Add/adjust automated tests covering:

- Meeting room nodes include mic wrappers and indicator:
  - `Decor/Table/Mic`
  - `Decor/Table/Mic/InteractIndicator`
  - `Decor/Table/TableCollision`
- Double-clicking mic opens the meeting-room chat overlay, and skills UI is hidden.

## Non-Goals

- Real multi-user networking or participant management.
- Scheduling/booking rooms.
- Rich audio controls (mute/unmute, voice, spatial audio).
- Chairs/seating placement.
- Any “skills” / skill library UI for meeting-room chat.


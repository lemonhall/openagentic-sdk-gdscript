# v61 Plan — VR Offices: Shared Skill Library (ZIP download + validate + manage)

## Goal

Implement the “shared library” milestone:

- Download GitHub repo ZIP via `codeload.github.com` (try `main`, fallback `master`).
- Unzip safely into staging.
- Discover+validate skill directories containing `SKILL.md` with YAML frontmatter.
- Install valid skills into `shared/skill_library/<skill_name>/` and show them as “available”.
- Add a `Library` tab in `VendingMachineOverlay` to manage install/uninstall.

## PRD Trace

- REQ-001 ZIP download
- REQ-002 Safe unzip
- REQ-003 Discover skill dirs
- REQ-004 Validate SKILL.md
- REQ-005 Install + manifest
- REQ-006 Search tab install-from-selected
- REQ-007 Library tab CRUD (“manage”)
- REQ-008 Library local search/filter
- REQ-009 (Deferred) NPC assign UI only

## Scope

- Add shared library paths and storage helpers.
- Add validator for `SKILL.md` frontmatter and safe skill naming.
- Add installer that can accept a ZIP path/bytes and produce installed skills + manifest updates.
- Add the `Library` UI tab and wire it to installer APIs.

## Non-Goals

- No “teach NPC” implementation (only UI placeholder/affordance).
- No remote “direct SKILL.md URL” source.
- No updates/lockfiles.

## Acceptance (hard DoD)

- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_shared_skill_library_installs_zip.gd` passes.
- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skill_md_validator.gd` passes.
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_search_tab_install_and_repo_link.gd` passes.
- `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_library_tab_manage_and_filter.gd` passes.
- `scripts/run_godot_tests.sh --suite vr_offices` passes.

Anti-cheat clause:
- Tests must create a ZIP locally (ZIPPacker) and install from it (no real network), and must assert filesystem outputs + manifest + UI list count.

## Files (expected)

- Add:
  - `addons/openagentic/core/OASkillMdValidator.gd`
  - `vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd`
  - `vr_offices/core/skill_library/VrOfficesSharedSkillLibraryStore.gd`
  - `vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd`
  - `vr_offices/core/skill_library/VrOfficesGitHubZipSource.gd`
  - `tests/addons/openagentic/test_skill_md_validator.gd`
  - `tests/projects/vr_offices/test_shared_skill_library_installs_zip.gd`
  - `tests/projects/vr_offices/test_vending_machine_overlay_search_tab_install_and_repo_link.gd`
  - `tests/projects/vr_offices/test_vending_machine_overlay_library_tab_manage_and_filter.gd`
- Modify:
  - `vr_offices/ui/VendingMachineOverlay.tscn`
  - `vr_offices/ui/VendingMachineOverlay.gd`

## Steps (塔山开发循环)

### 1) Doc QA Gate

- Ensure every REQ above is referenced by at least one test in Acceptance.
- Ensure the plan lists exact file paths and exact test commands.

### 2) TDD Red — validator

1. Add failing test `tests/addons/openagentic/test_skill_md_validator.gd` that:
   - accepts a well-formed SKILL.md (UTF-8 + YAML frontmatter + required keys)
   - rejects missing header / missing keys / unsafe name
2. Run:
   - `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_skill_md_validator.gd`
   - Expect FAIL: missing `OASkillMdValidator.gd`

### 3) TDD Green — validator implementation

1. Implement `addons/openagentic/core/OASkillMdValidator.gd` with a minimal YAML-frontmatter parser.
2. Rerun the validator test and confirm PASS.

### 4) TDD Red — install ZIP into shared library

1. Add failing test `tests/projects/vr_offices/test_shared_skill_library_installs_zip.gd` that:
   - builds a minimal skill directory with `SKILL.md`
   - packs it into a zip using `ZIPPacker`
   - calls installer to unzip+discover+validate+install into `user://.../shared/skill_library/<name>/`
   - asserts manifest updated and SKILL.md exists at destination
2. Run:
   - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_shared_skill_library_installs_zip.gd`
   - Expect FAIL: missing installer/store scripts

### 5) TDD Green — installer/store

1. Implement:
   - safe unzip + staging cleanup
   - discovery scan for `SKILL.md`
   - install copy and manifest `index.json`
2. Rerun zip install test and confirm PASS.

### 6) TDD Red — VendingMachineOverlay Library tab CRUD

1. Add failing test `tests/projects/vr_offices/test_vending_machine_overlay_search_tab_install_and_repo_link.gd` that:
   - instantiates `VendingMachineOverlay`
   - injects a stub “selected skill” that includes a GitHub repo URL
   - presses `Install` and asserts installer is called and success status is shown
   - asserts the repo URL is visible in the detail UI (and is wired for click-open in non-headless mode)
2. Run:
   - `scripts/run_godot_tests.sh --one tests/projects/vr_offices/test_vending_machine_overlay_search_tab_install_and_repo_link.gd`
   - Expect FAIL: missing UI nodes/methods

### 7) TDD Green — UI wiring

1. Update `VendingMachineOverlay.tscn` to add `Library` tab with:
   - local filter/search input
   - installed list
   - uninstall button
   - status label
   - (disabled/placeholder) NPC assign UI
2. Update Search tab details area to show:
   - repo URL
   - `Install` button (uses selected skill repo URL)
2. Update `VendingMachineOverlay.gd` to call installer/store and refresh list.
3. Add and pass test `tests/projects/vr_offices/test_vending_machine_overlay_library_tab_manage_and_filter.gd`:
   - install a couple skills via store APIs
   - filter by query and assert list count changes
4. Rerun both UI tests and confirm PASS.

### 8) Verify — suite

- `scripts/run_godot_tests.sh --suite vr_offices`

### 9) Review — evidence + diffs

- Paste PASS evidence into `docs/plan/v61-index.md`.
- Record deferred items (REQ-007) explicitly.

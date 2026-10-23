# Tessarchy agent workspace

Use this document to understand the project, choose work, record a plan and hand
off a finished contribution. Add tasks as the project grows. Keep task IDs stable.

## Start here

1. Read [AGENTS.md](AGENTS.md) for repository rules. If available, read the local
   `.HANDOFF.local.md` for the current operational checkpoint.
2. Read [Operation Tessarchy](Operation-TESSARCHY.md) for product direction.
3. Check the working tree, remote branches and existing pull requests.
4. Choose one bounded task below. Record its owner, branch and acceptance criteria.
5. Implement, validate, document and submit a focused change.

```bash
git status --short
git worktree list
git fetch origin
git log -5 --oneline origin/main
gh pr list
```

`main` is the integration branch and the website's publication/activity source.
`build/live-iso` is a legacy development branch and does not deploy automatically.
Fetch current refs before starting; commit IDs in handoff records describe
checkpoints, not permanent branch positions.

## Product and design

Tessarchy is a touch-first Arch Linux session. Tessa is its Quickshell/QML UI.
Hyprland provides compositing and window management. The development target is
an x86_64 QEMU/KVM guest; the next product milestone is one physical reference
device, followed by a tablet pilot and phone-specific integration.

The selected design is **Quiet Edge**:

- Midnight navy, mint accents and the original glacier wallpaper.
- Shallow glass top bar, mobile clock and pull-down component controls.
- Floating translucent bottom navigation with icon actions.
- Touch Recents cards with previews; Alt+Tab uses centered app icons without a background.
- Automatic Phone/Tablet/Desktop layouts and a saved manual mode in the pull-down.
- Original geometric Tessarchy mark, finite assembly/rotation and reduced motion.

Keep visual language consistent. Reuse components and official icons. Preserve
visible navigation when adding gestures. Keep implementation details out of
product UI unless they help the user act.

## Current implementation and evidence

| Area | Current state | Evidence or next check |
| --- | --- | --- |
| Shell | Quiet Edge bars, launcher, settings, adaptive layouts, workspace controls and card switcher | Actual VM captures and [testing record](docs/testing.md) |
| Communications | Phone/Messages dock apps, local contacts/photos, ModemManager and SIM/eSIM controls | [Implementation and device acceptance](docs/communications.md) |
| Sounds | Five supplied VoidRing tracks, selection, previews and MP3 import | Real VM selection/photo/input tests; device alert acceptance next |
| PIN login | Four-digit Linux account-password entry through greetd/PAM | Real VM rejection, login and return-to-greeter checks passed |
| Startup | Greeter and desktop use `start-hyprland -- --config` | Tested user instance: empty config errors and warning list |
| Radios | rfkill power controls and airplane mode; BlueZ discovery and connection actions for already-paired devices | VM no-adapter state checked; physical radio checks are backlog work |
| Bluetooth pairing | External Bluetooth manager | Native pairing/passkey workflow is a future task |
| Audio/media | Optional PipeWire output/application controls and MPRIS controls integrated | Automated checks pass; real audio signal/output/touch acceptance passed; real player acceptance is next |
| Screenshots | Print and pull-down camera action; unique private PNGs | Helper tests pass; end-to-end VM action check is next |
| Keyboard | Optional squeekboard, private settings and focus-preserving toggle | Existing VM evidence; expand the application matrix |
| Published ISO | Alpha 4 Intel/AMD tablet pilot, x86_64 live session with autologin | BIOS and non-Secure-Boot UEFI VM boot evidence on its release |
| Physical device | Reference-device selection and bring-up are planned | [Device roadmap](docs/device-roadmap.md) |
| Website | GitHub Pages, twenty-one real VM captures, roadmap, branding and sharing | Desktop/phone browser checks and public asset checks passed |
| Baseline checks | 105 Python tests, 62 Qt Quick results and 4 website tests in the T73 audit | Run current checks and record current totals |

Alpha 3 adds the tablet package set, curated launcher and supplied boot video.
Its live account autologins; installed tablets retain their existing login.
Authentication starts a new session; session locking is a separate backlog item.

Public tester account details are in [Alpha login details](README.md#alpha-login-details).

## Repository map

| Path | Responsibility |
| --- | --- |
| `shell/shell.qml` | Panel composition, navigation and shell integration |
| `shell/components/` | Reusable controls, app switcher, quick settings, radio/audio/media panels and PIN UI |
| `shell/LayoutPolicy.js`, `shell/SwitcherPolicy.js` | Layout and switcher policy |
| `shell/helpers/radios.py` | Structured rfkill queries and actions |
| `shell/artwork/`, `shell/icons/` | Canonical branding, wallpaper and UI icons |
| `session/` | Namespaced launchers, Hyprland Lua, OSK, screenshot helper and greetd configuration |
| `packaging/` | `tessera-shell`, `tessarchy-session`, `tessarchy-greeter` Arch recipes |
| `iso/` | Live-image package list and overlay |
| `scripts/` | Checks, installation, packaging, VM, ISO, site and branding tools |
| `tests/` | Python integration tests, Qt Quick tests and Quickshell harnesses |
| `assets/screenshots/` | Actual development captures and provenance |
| `assets/roadmap/` | Selected publication artwork |
| `website/` | Static GitHub Pages source |
| `docs/testing.md` | Actual validation and planned/manual checks |
| `.HANDOFF.local.md` | Ignored local session journal; kept on the developer machine |
| `build/`, `dist/`, `vm/` | Ignored work products, packages and VM data |

## Working method

Use standard technical English. Write direct descriptions and keep comments to
one line. State capabilities and validation once in the relevant section; avoid
repeated caveats, generic warnings and speculative disclaimers.

Follow the concrete rules in AGENTS.md: scratch-HOME install tests, host-session
isolation, explicit dependency installation, argument-safe scripts, confirmed
close/exit and protected image-build operations. Keep private credentials out of Git,
documentation, command arguments and captures. Use project-relative paths and
generic account labels in public files; keep personal identifiers in local state.

Touch targets are at least 48 logical pixels in both dimensions, except the
owner-requested 32px-wide desktop quick-launch and tray controls (48px tall). The other approved
exception is on-screen keyboard width: narrower letter keys are allowed, with
height still at least 48 pixels. Navigation preserves application keyboard focus.

Create a branch or separate worktree for implementation. Preserve contributor
history and changes outside your task. The existing `build/integration` worktree
contains an unfinished PR #9 integration; leave its merge state intact. Inspect
current worktrees before choosing directories. Prefer additive, focused changes
over replacing collaborator implementations.

### Runtime details that save time

- API baseline: Hyprland 0.56 Lua, Quickshell 0.3.1 and Qt 6. Inspect installed
  QML type metadata before using a service property or method.
- `start-tessarchy` chooses a user development copy before `/usr/share/tessarchy`.
  Check `TESSARCHY_DATA_DIR` and the running process before claiming a package
  update was tested. The existing VM keeps its private development shell.
- The greeter uses the system package and its own compositor/account. Read
  [phone-login.md](docs/phone-login.md) before changing that startup path.
- Layout mode follows logical screen geometry, not a physical-device identifier.
  `LayoutPolicy.js` and the compositor policy must remain consistent.
- Shell preferences use `$XDG_CONFIG_HOME/tessarchy/shell.ini`; compositor
  preferences use the namespaced Lua preferences file.
- Optional services may disappear while a panel is open. Validate object/model
  membership and readiness at action time; release trackers/discovery you own.
- Treat names, titles and device labels as plain text. Pass subprocess arguments
  as arrays and keep compositor commands fixed or strictly numeric.
- Query `hyprctl -j instances` for the active instance. Old runtime directories
  can remain after a session ends.

## Commands and validation

Run from the repository root:

```bash
./scripts/check.sh
python3 scripts/build-site.py --output dist/site-agent-review
```

Choose a fresh site output directory for each build. `check.sh` runs Python,
Qt Quick and available syntax/API checks; its installer tests use scratch HOME.
Record skipped tools as well as passes. Ubuntu and Arch CI provide target
toolchain coverage. For visual behavior, test the affected VM workflow and attach
actual screenshots. Record the running source revision, display size and result.

Use [VM instructions](docs/vm.md), [package/build instructions](README.md) and
[ISO procedure](docs/iso.md) for those workflows. Building, booting and accepting
an ISO are separate results. A new tester release needs the exact source SHA,
package list, checksum and inspected BIOS/UEFI boot evidence.

## Claiming and extending tasks

All tasks below start **Open / unassigned**. Priority is an ordering aid:
P0 is the next practical work, P1 completes the mobile experience, P2 advances
hardware/releases, and P3 expands the project. Deferred PR tasks keep their
existing triage decision until a focused review resolves the named dependency.

Add a claim to the register before editing shared implementation files. Use
`Open`, `Claimed`, `In progress`, `Review`, `Blocked` or `Done`. A blocked entry
must name the missing input and a useful independent next step. Add new task IDs
after the last assigned ID; preserve existing IDs when reorganizing sections.

| Task ID | Status | Owner | Branch / PR | Next action or evidence |
| --- | --- | --- | --- | --- |
| T85 | In progress | Codex | fix/issue-78-current-main | Reconcile OSK gesture-strip fix with current main; retain VM evidence and inspect integration changes |
| T81 | In progress | Codex | fix/89-osk-dismiss-button | Add a 48px+ OSK toggle in the mobile status bar; check Phone and Tablet placement |
| T80 | In progress | Codex | feat/operation-tessa | Integrate #61/#85 and #58, cube/radial/launcher, VM acceptance |
| T79 | Review | Codex | docs/touch-window-tape | Native Hyprland scrolling prototype #61 |
| T78 | Review | Codex | integrate/vm-accepted-20261020 | Existing integration |
| T77 | Done | Codex | feat/osk-super-key | Existing OSK Super key |

| T73 | Done | Codex | review/audit-2026-10-19 | PR #52 merged; small PRs integrated, shell/site defects fixed, CI and live Pages verified |
| T74 | Done | Codex | PR #53 | Installer preflight safeguards merged into the feature branch; full installer integration and installed-disk acceptance remain open |
| T76 | Done | Codex | PR #55 | All 21 captures refreshed; public image/ZIP hashes and deployed package repository verified; shell/session revisions raised for installed updates |
| T75 | Done | Codex | PR #55 | Real phone previews and touch/close/empty-state checks passed at 390×844, 400×800 and 360×800; audio signal/UI checks passed, physical Wi-Fi untested |
| T05 | In progress | Codex | feat/vm-touch-refinement | VM touch drawer, scrolling, output switching and compact/wide layouts tested |
| T25 | In progress | Codex | feat/vm-touch-refinement | Virgl verified; reduced absent-service polling; 30s CPU samples recorded |
| T09 | Done | Codex | PR #18 | Guarded battery/power-profile integration; unavailable VM state verified |
| T08 | Done | Codex | VM/touch publication | Seventeen refreshed captures, three retained PIN captures and matching site/ZIP |
| T58 | Done | Codex | feat/tablet-install-readiness | x86 tablet profile, curated launcher, supplied splash video and inspected Alpha 3 BIOS/UEFI boots |
| T60 | Done | Codex | fix/mobile-status-tray | Mobile bar excludes desktop tray icons; actual VM home and drawer checked |
| T61 | Done | Codex | fix/osk-key-height | Portrait on-screen keys meet the 48px height floor at 400px and 360px widths |
| T62 | Done | Codex | feat/tessy-discord | Tessy posts commits, pull requests and releases to the project Discord channel |
| T63 | Done | Codex | feat/desktop-taskbar | Desktop mode uses a full-width taskbar with window tasks; the app tray left the status strip |
| T64 | Done | Codex | feat/xp-glass-taskbar | Windows-XP-style glass taskbar: Start pill, bevelled task buttons and a sunken tray |
| T65 | Done | Codex | feat/start-menu-windowed-desktop | XP-style Start menu opens above the Start button and toggles shut; Desktop windows open windowed by default with a Settings toggle for tiling |
| T66 | Done | Codex | fix/repository-audit | Fractional OSK scales, source-independent dev uninstall and bounded Tessy payloads; 97 Python / 49 Qt checks |
| T67 | Done | Codex | fix/desktop-window-resize | Desktop windows can be resized by dragging an edge (resize_on_border, wider grab area) |
| T68 | Done | Codex | feat/desktop-tray-indicators | The status strip's indicator cluster moves into the Desktop taskbar tray, beside the clock |
| T70 | Done | Codex | feat/desktop-taskbar-polish | Centered Start, floating menu icons, consistent tray glyphs, task overflow and dismissal; 1280×800 VM / 104 Python / 53 Qt checks |
| T71 | Done | Codex | feat/desktop-quick-switcher | Logo Start, weather by Start, pulldown-only top, uniform compact tray, icon-only Alt+Tab; VM keyboard and visual checks |
| T72 | Done | Codex | feat/desktop-window-controls | Title-bar minimize with taskbar/Alt+Tab restore, maximized/reload recovery, touch hit-testing patch; VM / 107 Python / 57 Qt checks |
| T69 | Done | Codex | feat/weather-status | Keyless current-conditions chip in the status strip, with an offline cache |
| T59 | Done | Codex / contributor | PR #28 | Offline BIOS/UEFI live boots passed; contributor history preserved |
| T57 | Done | Codex | feat/vm-touch-refinement | QEMU audio/touch test profile and host QMP gesture driver |

### P0 — Validate and finish the current integrations

| ID | Task | Completion result |
| --- | --- | --- |
| T01 | Exercise media controls with a real MPRIS player | Play/pause/next/previous and player disappearance recorded in VM |
| T02 | Exercise audio outputs and per-application volume | Output switching, mute, stream disappearance and missing-service behavior recorded |
| T03 | Exercise Print and pull-down screenshot actions | Unique PNG, correct framing, clean failure and notification behavior verified |
| T04 | Build a current runtime/source identity checklist | Each capture identifies dev/system source, SHA, service versions and geometry |
| T05 | Expand the mobile regression walkthrough | Home, launcher, switcher, settings, pull-down, OSK, close and exit recorded |
| T06 | Test PIN login across compact sizes and scale factors | Input, retry, timeout, focus and session transitions documented |
| T07 | Test optional-service lifecycle changes | Bluetooth/audio/player service loss and return leave usable panels |
| T08 | Refresh screenshots after accepted UI changes | Original captures, captions, ZIP and site content agree |

### P1 — Review existing pull requests in manageable pieces

Read [pr-triage.md](docs/pr-triage.md) and inspect current PR heads first.

| ID | Task | Completion result |
| --- | --- | --- |
| T09 | Review #18 power controls | Reliable service detection, supported modes and guarded writes |
| T10 | Review | — | `feat/screen-idle` / #21 | Reworked on current `main`: hypridle autostart through the Lua `hyprland.start` hook, explicit wake-input options, per-capture wake in the boot test; guest idle-to-blank-and-wake cycle verified over the serial console, Lua dispatch accepted both ways |
| T11 | Review #23 Wi-Fi connection workflow | Scan ownership, NetworkManager lifecycle, credentials agent and cancellation resolved |
| T12 | Review | — | `feat/rotation` / #22 | Reworked for Lua: generated `display.lua` plus recoverable `tessera-rotate` helper; guest rotation applied (transform 1, portrait shell capture) and reload-race retry added; hardware rotation pending |
| T13 | Review #13 notifications | Plain-text rendering, popup/history lifecycle, replacement and withdrawal checked |
| T14 | Review #19 brightness/night light | Hardware availability and owned-process lifetime handled correctly |
| T15 | Resume #9 theme integration in its preserved worktree | Reconcile current glass UI, app themes and keyboard without losing contributor work |
| T16 | Review #11 keyboard sizing after dependencies | Narrow key widths fit phone screens while preserving 48px height |
| T17 | Review #20 keyboard visibility incrementally | Reuse existing page/pull-down guards and verify focus behavior |
| T18 | Rework #12 tablet split around the current switcher | Two-app layout, focus, restore and mode transitions tested |
| T19 | Review #10 file dialogs as a dedicated integration | Portal/GTK lifecycle, save/overwrite, cancellation and IPC tested |
| T20 | Resolve #16 against the current card switcher | Retain useful incremental work and document overlap with existing previews |

### P1 — Complete the mobile interaction layer

| ID | Task | Completion result |
| --- | --- | --- |
| T21 | Add configurable navigation gestures | — | `feat/nav-gestures` (stacked on #48) | In progress: edge-strip swipes for Home, Recents (hold) and Back, handle pill, Settings → Navigation Gestures/Buttons fallback; guest swipes verified with uinput touch, hardware touchscreen pending |
| T22 | Refine switcher transitions | Smooth card movement, stable selection and rapid window-close handling |
| T23 | Expand the keyboard/application matrix | Foot, browser forms, passwords, multiline fields and dialogs tested |
| T24 | Audit scaling and accessibility | Logical target sizes, readable contrast, text scaling and accessible names checked |
| T25 | Measure and reduce shell overhead | Reproducible CPU/RAM/frame measurements and a measured improvement |
| T26 | Define native Bluetooth pairing scope | Passkey/confirmation/cancellation design and a tested BlueZ agent path |
| T27 | Improve settings organization | Clear groups, persisted values, sensible defaults and reset behavior |
| T28 | Propose touch-friendly default applications | Narrow-screen evaluation, resource measurements and an approved package list |
| T29 | Test multi-output behavior | Per-output Auto sizing, global override and window navigation agree |
| T30 | Improve empty, busy and failure states | Concise actionable messages without simulated hardware state |

### VM test environment

| ID | Task | Completion result |
| --- | --- | --- |
| T57 | Add usable VM audio, touch and accelerated graphics | Basic profile, guest audio stack, QMP gestures and actual signal validation |

### P2 — Move to a physical reference device

| ID | Task | Completion result |
| --- | --- | --- |
| T31 | Produce a reference-hardware comparison | Exact models, primary support sources, boot access and component matrix |
| T32 | Select one reference device with the owner | Documented target, required firmware and recovery route |
| T33 | Plan its architecture/build port | Kernel, boot chain, root filesystem and packaging dependencies mapped |
| T34 | Bring up graphics and touch | Native display, acceleration, coordinate mapping and input verified |
| T35 | Validate connectivity and audio | Real Wi-Fi/Bluetooth, speaker/microphone and headset results |
| T36 | Validate power, charging and thermals | Recorded battery reporting, charge behavior, temperature and runtime measurements |
| T37 | Validate suspend, wake and rotation | Repeatable cycles, recovery and touch remapping results |
| T38 | Validate the ModemManager stack on hardware | Chosen stack, permissions, audio routing and device test matrix |
| T39 | Define phone acceptance requirements | Network/operator, emergency-use and recovery requirements assigned to explicit validation |
| T40 | Run the first daily-use pilot | Repeatable image, install guide, field log and prioritized defects |

### P2 — Provisioning, updates and releases

| ID | Task | Completion result |
| --- | --- | --- |
| T41 | Design first-boot account and PIN enrollment | No repository credential, cancellation/retry and recovery tested |
| T42 | Integrate enrolled login into a new tester image | Account setup and actual greeter boot flow accepted in a VM |
| T43 | Design and implement session locking separately | Wayland lock protocol, session lifecycle and recovery tests |
| T44 | Design signed updates and rollback | Package/image trust model, interrupted update and rollback drills |
| T45 | Scope data protection for the reference device | Storage/enrollment/recovery design with explicit implementation tests |
| T46 | Improve build provenance | Version pinning strategy, package ownership, source SHA and complete manifests |
| T47 | Prepare the next tester release | Checks, checksum, reviewed boot captures, release notes and matching site content |
| T48 | Review the live-image service footprint | Enabled service inventory and intentional network exposure documented |

### P3 — Documentation, website and contributor experience

| ID | Task | Completion result |
| --- | --- | --- |
| T49 | Keep this task register current | Ownership, PR links, dependencies and completed evidence updated |
| T50 | Add structured feature/release status data | One reviewed data source for site capabilities and release differences |
| T51 | Add a lightweight site link/content check | Missing assets, broken anchors and release-download regressions caught |
| T52 | Expand share and accessibility checks | Native mobile sharing, keyboard gallery use and social previews checked |
| T53 | Maintain the official brand kit | Canonical SVG identity, export sizes, animation and reproducible manifest |
| T54 | Maintain the device roadmap | Gates and artwork updated after accepted product milestones |
| T55 | Improve issue and contribution templates | Reproduction/source/device details and concise review guidance |
| T56 | Publish a tester feedback guide | Simple install/test/report path and useful bug-report examples |
| T59 | Do not gate the live boot on an NTP sync | Releng enables `systemd-time-wait-sync`; with no network and no battery clock it waits forever (`no limit`), so the staged profile removes it and the staging test asserts the removal |

## Contribution completion record

Add public validation evidence to docs/testing.md. Keep local operational notes
in the ignored `.HANDOFF.local.md`. A contribution record includes:

- Task ID, outcome and affected files.
- Branch, commit and PR URL.
- Commands run, actual results and skipped/manual checks.
- Screenshots for visual changes and source/device identity for runtime work.
- Remaining follow-up tasks and the next useful action.

Lead PR descriptions with the concrete problem and resulting behavior. Preserve
the author's history when integrating an existing contribution. After a merge,
verify the GitHub result, synchronize the relevant public branches, and confirm
the Pages deployment when website content changed.

## Project links

- [Website](https://thediamondsaint.github.io/tessarchy/)
- [Repository and pull requests](https://github.com/thediamondsaint/tessarchy)
- [Tester ISO](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.3)
- [Official logo kit and spinning GIF](https://github.com/thediamondsaint/tessarchy/releases/tag/brand-kit-20261017)
- [Roadmap image](https://thediamondsaint.github.io/tessarchy/assets/tessarchy-device-roadmap.png)

T58: prepare the Intel/AMD tablet package/profile, primary-app picker and supplied video splash. Host and current development VM stay unchanged.

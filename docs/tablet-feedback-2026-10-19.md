# Tablet feedback: complete report and acceptance plan

Collected from community feedback supplied on 2026-10-19. Source excerpts below
preserve the tester’s wording, including uncertainty and suggestions. Two compound
comments are split into separate actionable items, giving 17 items in six groups.
The original posts included relative timestamps; their exact posting date is not
established here.

These are reported observations, not independently reproduced results. Device
model, image/build version, display scale, orientation sensor support and logs
were not supplied. Related PRs identify overlap, not confirmed fixes. All items
remain unchecked until implementation and relevant validation are complete.

## Reported working baseline

> Basic hardware discovery seems fine.
> WiFi audio keyboard and touch all work out of the box.

Preserve these working paths while fixing the reported UI problems. Working Wi-Fi
hardware/connectivity and broken shell network indicators are separate observations.
There is no claim here that cellular service or sensor support was validated.

## Coverage index

| Group | Items |
| --- | --- |
| Hardware and rotation | R01: rotation |
| On-screen keyboard | K01: bottom placement; K02: split thumb layout; K03: Super |
| Networking | N01: real status; N02: tappable indicators; N03: connection management |
| Touch window management and navigation | W01: close/resize; W02: gestures; W03: workspace moves; W04: pill hide/reveal |
| Split-screen layout and resizing | S01: animation; S02: spacing; S03: divider overlap |
| Visual consistency and content clipping | V01: glyph scale; V02: margins; V03: rounded corners |

Acceptance checks below translate the report into reviewable outcomes. Additional
edge-case checks are implementation recommendations, not extra tester requests.

## Hardware and rotation

### R01 — Screen rotation

- [ ] Implement and validate R01.

Tester wording:

> Screen rotation not working

Reported behavior: Rotation is reported as broken. The report does not establish whether manual rotation, automatic sensor rotation, or both fail.

Requested outcome: Working screen rotation. Manual and sensor-driven paths should be evaluated separately.

Acceptance checks:

- On the affected hardware, test manual portrait and landscape rotation and record the result for each orientation.
- If a supported orientation sensor is present, test automatic rotation and rotation lock.
- Verify touch coordinates, shell layout, keyboard placement and application geometry after each rotation.

Related work: #22; backlog T37.

## On-screen keyboard

### K01 — Bottom placement

- [ ] Implement and validate K01.

Tester wording:

> Onscreen keyboard floats above bottom pill and is centered in tablet mode instead of being split for thumbs.

Reported behavior: The keyboard appears to float above the bottom navigation pill. This is a separate placement complaint from the requested split layout.

Requested outcome: A keyboard position that fits the bottom navigation and tablet layout coherently. The tester did not specify an exact inset or whether the pill should move.

Acceptance checks:

- Check keyboard placement with the pill shown and hidden, including reveal transitions.
- Remove unintended empty space and prevent keyboard, navigation and application controls from obscuring one another.
- Check portrait, landscape and keyboard show/hide while preserving input focus.

Related work: #20; backlog T23.

### K02 — Split layout for thumbs

- [ ] Implement and validate K02.

Tester wording:

> Onscreen keyboard floats above bottom pill and is centered in tablet mode instead of being split for thumbs.

Reported behavior: The tablet keyboard is centered, making it unsuitable for the requested two-thumb use.

Requested outcome: A split keyboard layout in tablet mode, with reachable left and right key groups.

Acceptance checks:

- Verify typing while holding the tablet with both hands in portrait and landscape.
- Keep letters, modifiers, space, backspace and enter usable in the split layout.
- Preserve at least 48 logical pixels of key height and verify layout-mode changes do not strand focus.

Related work: Backlog T23.

### K03 — Super key

- [ ] Implement and validate K03.

Tester wording:

> OSK lacking super key

Reported behavior: The on-screen keyboard does not expose Super.

Requested outcome: An accessible Super key for touch users.

Acceptance checks:

- Verify Super press and release reach the focused application or compositor as appropriate.
- Verify supported Super combinations can be entered using only the on-screen keyboard.
- Ensure cancellation, keyboard dismissal and layout changes cannot leave Super stuck.

Related work: Backlog T23.

## Networking

### N01 — Wi-Fi and cellular status

- [ ] Implement and validate N01.

Tester wording:

> WiFi & cellular indicators don't function, and tapping on them does nothing.

Reported behavior: The tester reports nonfunctional Wi-Fi and cellular indicators, despite working Wi-Fi hardware.

Requested outcome: Indicators that reflect actual connectivity.

Acceptance checks:

- Verify Wi-Fi disconnected, connecting and connected states against the backend.
- Verify cellular state with suitable hardware; show an honest unavailable state when no modem is present.
- Confirm indicators update after connection changes without restarting the shell.

Related work: #54 and #23.

### N02 — Interactive network indicators

- [ ] Implement and validate N02.

Tester wording:

> WiFi & cellular indicators don't function, and tapping on them does nothing.

Reported behavior: Tapping either network indicator has no visible effect.

Requested outcome: Touch interaction that opens the relevant network controls.

Acceptance checks:

- Tap Wi-Fi and cellular indicators and confirm the corresponding controls open.
- Provide adequate touch targets and clear unavailable, busy and error states.
- Confirm opening and dismissing controls works without a mouse or keyboard.

Related work: #54 and #23.

### N03 — Accessible connection management

- [ ] Implement and validate N03.

Tester wording:

> Difficult to access network connections, had to open a terminal and use nmtui

Reported behavior: The tester resorted to terminal-based nmtui to manage connections.

Requested outcome: Discoverable graphical network management usable entirely by touch.

Acceptance checks:

- Find available Wi-Fi networks, select one, enter credentials with the OSK and connect.
- Verify disconnect/reconnect and clear authentication or connection failure feedback.
- Check that connection controls are discoverable from the shell and do not require terminal commands.

Related work: #54 and #23.

## Touch window management and navigation

### W01 — Close and resize undecorated windows

- [ ] Implement and validate W01.

Tester wording:

> General touch based window management is odd. windows like foot have no chrome for closing or resizing. and gestures seem not to work?

Reported behavior: Applications such as foot lack visible chrome for close and resize operations.

Requested outcome: Discoverable touch controls for basic window management, including clients without decorations.

Acceptance checks:

- Open foot and another client without decorations; close and resize each using touch only.
- Keep controls reachable in maximized, floating and split layouts where supported.
- Follow the existing close-confirmation policy, including the established immediate-dismissal exception in Recents.

Related work: docs/window-controls.md; backlog T18 and T21.

### W02 — Working and discoverable gestures

- [ ] Implement and validate W02.

Tester wording:

> General touch based window management is odd. windows like foot have no chrome for closing or resizing. and gestures seem not to work?

Reported behavior: The tester is unsure whether gestures work. This does not establish a specific broken gesture or root cause.

Requested outcome: Gestures that work reliably and are discoverable to a touch user.

Acceptance checks:

- List supported gestures and their required finger count, direction and starting region.
- Verify the documented actions on physical touch hardware, including interference from application scrolling.
- Retain accessible visible controls and record unsupported gestures explicitly.

Related work: #49; backlog T21.

### W03 — Move windows between workspaces

- [ ] Implement and validate W03.

Tester wording:

> no way to move windows to other workspaces with touch alone

Reported behavior: The tester cannot move an application window to another workspace using touch alone.

Requested outcome: A discoverable way to select a window and move it to another workspace without a physical keyboard.

Acceptance checks:

- Move foot and another application from one workspace to another with touch alone.
- Verify the correct window moves and remains reachable on the destination workspace.
- Check cancellation, an empty destination workspace and moving a window out of split screen.

Related work: Backlog T21.

### W04 — Auto-hide and reveal the bottom pill

- [ ] Implement and validate W04.

Tester wording:

> WM pill at the bottom should probably hide when windows are open with a way to pop it up over the windows

Reported behavior: The tester proposes auto-hiding the window-management pill when application windows are open.

Requested outcome: Hide the pill while windows are open and provide a way to reveal it over those windows. This was phrased as a proposal, rather than a confirmed defect.

Acceptance checks:

- Define which open-window states trigger hiding, and the touch action or control that reveals the pill.
- Verify the pill appears above applications, remains usable and can hide again without blocking application input.
- Check recovery without a physical keyboard and reconcile the proposal with the current visible-navigation fallback policy before implementation.

Related work: #49; backlog T21.

## Split-screen layout and resizing

### S01 — Smooth resizing

- [ ] Implement and validate S01.

Tester wording:

> Resizing split screen windows works but doesn't animate cleanly.

Reported behavior: Split-screen resizing functions, but its animation is visually rough.

Requested outcome: Smooth, stable resizing feedback.

Acceptance checks:

- Record dragging the divider slowly, quickly and repeatedly in both orientations.
- Check for jumps, flicker, stale frames, geometry mismatch and layout changes at release.
- Verify reduced-motion behavior and record the tested hardware and display scale.

Related work: #12; backlog T18.

### S02 — Balanced inner and outer spacing

- [ ] Implement and validate S02.

Tester wording:

> we have a huge gap between windows in split screen but nothing at the edges, which feels odd.

Reported behavior: The inner gap is large while windows have no comparable spacing at the display edges.

Requested outcome: An intentional balance between the central gap and outer margins. No exact pixel sizes were requested.

Acceptance checks:

- Compare inner and outer spacing in portrait and landscape on a tablet.
- Check that spacing remains consistent when resizing or changing scale.
- Verify usable window area and divider touchability after adjusting the spacing.

Related work: #12; backlog T18.

### S03 — Divider must not cover content

- [ ] Implement and validate S03.

Tester wording:

> split screen divider covers window contents

Reported behavior: The divider overlaps application content.

Requested outcome: Keep the visible divider and its interaction region from obscuring or stealing input from client content.

Acceptance checks:

- Check text and interactive controls beside the divider in both applications.
- Verify content stays visible while dragging and after release.
- Reserve suitable layout space or otherwise prevent overlap while retaining a usable divider touch target.

Related work: #12; backlog T18.

## Visual consistency and content clipping

### V01 — Consistent top-bar glyph scaling

- [ ] Implement and validate V01.

Tester wording:

> Inconsistent glyph scaling on top bar

Reported behavior: Top-bar glyphs have inconsistent apparent sizes.

Requested outcome: Consistent perceived glyph sizing and alignment.

Acceptance checks:

- Compare every top-bar glyph at supported display scales and layout modes.
- Check baseline, centering, stroke appearance and clipping rather than only nominal icon dimensions.
- Preserve approved touch-target dimensions independently of visual glyph size.

Related work: Backlog T24.

### V02 — Consistent container margins

- [ ] Implement and validate V02.

Tester wording:

> Generally UI margins are inconsistent with objects and text pressing hard against bottom and left sides of their containers

Reported behavior: Objects and text crowd the bottom and left container edges; overall margins are inconsistent.

Requested outcome: Consistent padding and alignment, especially at the bottom and left edges.

Acceptance checks:

- Audit shell panels, settings, menus and controls for all four content insets.
- Check labels, glyphs and control contents in Phone, Tablet and Desktop modes and at supported scales.
- Capture before/after comparisons and verify text does not clip or collide with adjacent controls.

Related work: Backlog T24.

### V03 — Rounded corners must preserve content

- [ ] Implement and validate V03.

Tester wording:

> curved corners cut off window content, need to find a way to add padding to contents

Reported behavior: Rounded window corners clip application contents. The tester specifically suggests padding as a remedy.

Requested outcome: Protect content near rounded corners; evaluate padding or another treatment that preserves full client content.

Acceptance checks:

- Check terminal edge cells and application controls in every corner.
- Verify maximized and split windows, including after resize and rotation.
- Evaluate client/content insets or corner treatment without assuming shell padding can inset arbitrary application content.

Related work: #47; backlog T24.

## Validation and completion evidence

For each item, record the implementation PR, tested build, device, layout mode,
orientation, display scale, reproduction steps and actual result in
`docs/testing.md`. Include before/after images for glyphs, margins, corner clipping,
keyboard placement and split spacing; use short recordings for gestures, pill
reveal and resize animation.

Run the repository’s required `./scripts/check.sh` for implementation changes.
Automated checks alone do not establish physical rotation, modem operation,
thumb reachability or touch gesture behavior. Record those device checks separately.
Test foot plus another application, including terminal edge content and touch
controls, to avoid accepting a fix that only works with decorated clients.

Documentation validation for this tracking change: checked all supplied complaint
lines against the 17 items and preserved the positive hardware observations.
`git diff --check` passed. No runtime implementation or device acceptance was
performed by this documentation change.

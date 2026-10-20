# Tablet feedback checklist

Collected from community feedback supplied on 2026-10-19. These are reported
observations and requested behaviors; they have not been independently reproduced.
Device model, image version, display scale and logs were not supplied.
Unchecked items remain open even when a related implementation PR exists.

## Working baseline

The tester reports that basic hardware discovery, Wi-Fi, audio, keyboard and touch
work out of the box. Wi-Fi connectivity works, while its shell indicators and
connection controls are reported below as unusable.

## 1. Screen rotation

- [ ] **Rotation does not work.** Verify manual rotation and sensor-driven rotation
  separately on the affected device. Acceptance: supported orientations work,
  touch coordinates follow the display, and rotation lock behaves consistently.
  Related: [#22](https://github.com/thediamondsaint/tessarchy/pull/22), T37.

## 2. On-screen keyboard

- [ ] **Keyboard floats above the bottom navigation pill.** Acceptance: keyboard
  placement uses consistent bottom spacing and avoids overlap with navigation.
- [ ] **Tablet keyboard is centered instead of split for thumbs.** Acceptance:
  provide a thumb-friendly split layout in tablet mode and verify reachability
  in landscape and portrait.
- [ ] **Keyboard lacks a Super key.** Acceptance: expose Super and verify that
  supported Super combinations work from touch alone.

Related: [#20](https://github.com/thediamondsaint/tessarchy/pull/20), T23.
Keyboard keys must remain at least 48 logical pixels tall.

## 3. Networking status and access

- [ ] **Wi-Fi and cellular indicators do not function.** Acceptance: show actual
  connection state and handle missing hardware and disconnected states.
- [ ] **Tapping network indicators does nothing.** Acceptance: tapping opens
  relevant network controls with usable touch targets.
- [ ] **Connections are difficult to access; the tester needed terminal nmtui.**
  Acceptance: discover and connect to Wi-Fi through the shell without a terminal,
  including authentication and actionable connection errors.

Related: [#54](https://github.com/thediamondsaint/tessarchy/pull/54),
[#23](https://github.com/thediamondsaint/tessarchy/pull/23).

## 4. Touch window management and navigation

- [ ] **Windows such as foot lack chrome for closing or resizing.** Acceptance:
  provide discoverable touch controls for close and resize, including clients
  without their own window decorations; preserve required close confirmation.
- [ ] **Window-management gestures appear not to work.** Acceptance: document
  supported gestures, verify them with physical touch and retain visible controls.
- [ ] **Windows cannot be moved between workspaces using touch alone.** Acceptance:
  select a window and move it to another workspace without a physical keyboard.
- [ ] **Bottom navigation pill should hide while windows are open.** Requested
  behavior: hide automatically and provide a discoverable touch action to reveal
  it over windows. Resolve this proposal against the current visible-navigation
  policy before implementation; verify recovery without gestures or a keyboard.

Related: [#49](https://github.com/thediamondsaint/tessarchy/pull/49), T21.

## 5. Split-screen layout and resizing

- [ ] **Resizing works but animates poorly.** Acceptance: divider dragging remains
  visually smooth and stable, with no jumps or flicker; honor reduced motion.
- [ ] **Large inner gap contrasts with no outer edge spacing.** Acceptance: use
  consistent, intentional inner and outer spacing in portrait and landscape.
- [ ] **Split-screen divider covers window contents.** Acceptance: reserve divider
  space outside client content while retaining an adequate touch target.

Related: [#12](https://github.com/thediamondsaint/tessarchy/pull/12), T18.

## 6. Visual consistency and content clipping

- [ ] **Top-bar glyph sizes are inconsistent.** Acceptance: normalize perceived
  icon size and alignment across supported display scales.
- [ ] **Margins are inconsistent; text and objects press against container bottoms
  and left sides.** Acceptance: apply consistent content insets and check labels,
  controls and containers across Phone, Tablet and Desktop layouts.
- [ ] **Rounded window corners cut off content.** Acceptance: protect client
  content from clipping, including terminal edge cells, using suitable layout,
  corner or inset treatment; verify both tiled and maximized windows.

Related: [#47](https://github.com/thediamondsaint/tessarchy/pull/47), T24.

## Follow-up evidence

For each fix, record the affected device, build, layout mode, display scale,
reproduction steps and actual result in docs/testing.md. Capture before/after
images for spacing and clipping, and short recordings for resizing and gestures.
Hardware rotation and physical-touch acceptance remain manual device checks.

# Start menu: installed applications and automatic refresh

## Problem

Installed graphical applications can be missing from Start. The menu is labelled
"ALL APPS", but `shell/shell.qml` supplies `Apps.majorApplications(...)` from
`shell/AppPolicy.js`. That policy accepts only a fixed list of desktop-entry IDs
and selects one installed application per role. An application outside that
list is excluded; a second browser or terminal can also be excluded.

PR #2 introduced desktop-entry discovery and is already merged. It does not
resolve the current role-filtering limitation or cover the requested live-update acceptance checks.
The missing-app report has not been reproduced on a physical device here.
The code-level exclusion above is confirmed by inspection of current main.

## Requested behavior

- [ ] Show every installed, launchable graphical application that is eligible
  for the current desktop session, including applications outside the primary
  role list and multiple applications in the same role.
- [ ] Keep any curated primary-app selection separate from the complete All Apps
  inventory. Do not label a curated subset "ALL APPS".
- [ ] Use Quickshell's built-in desktop-entry monitoring and application model
  updates to keep Start current. No periodic polling timer or custom rescan on
  opening Start is required. Verify change propagation on the supported version.
- [ ] Add newly installed applications without requiring logout or a shell
  restart; remove uninstalled applications and update changed names/icons.
- [ ] Present applications in a clean, consistent layout: clear category
  headings from desktop-entry metadata, alphabetical ordering within categories,
  and an Other category for applications without a recognized category.
- [ ] Keep all eligible applications reachable when many are installed:
  scrolling, readable labels, consistent icon sizing and spacing, keyboard
  navigation, and touch targets at least 48 logical pixels.
- [ ] Preserve desktop-entry visibility rules and precedence. Respect Hidden,
  NoDisplay, OnlyShowIn, NotShowIn, and TryExec where supported by the discovery
  API. Deduplicate by desktop-entry identity, not display name; preserve separate
  applications with the same name.
- [ ] Include standard system and per-user application locations and supported
  Flatpak/Snap export locations through the session's XDG data directories.
  Terminal-only packages without desktop entries need no launcher tile.
- [ ] Launch through the desktop-entry execution API; do not construct shell
  commands from names or Exec strings. Handle missing icons and entries removed
  during refresh without breaking the menu.
- [ ] Keep refresh asynchronous and inexpensive. Do not query package managers
  repeatedly or rebuild an unchanged menu. Preserve scroll position and keyboard
  focus across background updates where possible.

## Acceptance checks

1. Open Start, install a graphical application outside the current role list,
   and confirm it appears after Quickshell reports the desktop-entry change,
   without restarting the shell. Repeat with Start closed, then reopen it.
2. Install two browsers or terminals and verify both appear in All Apps.
3. Uninstall an application while Start is open; verify its tile disappears and
   attempting to launch a stale selection fails gracefully.
4. Add, change, hide and remove a per-user desktop entry. Verify its name, icon,
   visibility and launch behavior update correctly.
5. Verify duplicate system/user desktop-entry IDs honor user precedence,
   including a user Hidden override; unrelated equal-name apps remain visible.
6. Verify supported Flatpak/Snap entries appear when their export directories
   are available to the session.
7. Verify categories, alphabetical ordering, missing-category/icon fallback and
   a large inventory. Check keyboard and touch navigation, long labels, scrolling
   and narrow layouts wherever the shared app inventory is used.
8. Confirm repeated application-change events do not duplicate entries, move focus unnecessarily,
   block interaction, or noticeably increase idle resource use.
9. Run `./scripts/check.sh` for the implementation. Add regression coverage for
   unrestricted eligible-app discovery, filtering/precedence, ordering,
   additions/removals and refresh lifecycle; record actual VM/device results in
   `docs/testing.md`.

## Quickshell reuse audit

Source inspected: Quickshell tags v0.3.1 and v0.3.2,
[src/core/desktopentry.cpp](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/core/desktopentry.cpp),
[desktopentry.hpp](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/core/desktopentry.hpp),
and [desktopentrymonitor.cpp](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/core/desktopentrymonitor.cpp).
This is source inspection, not runtime acceptance.

| Requirement | Existing support | Tessarchy work |
| --- | --- | --- |
| Complete installed-app inventory | DesktopEntries.applications supplies discovered application entries | Remove the role whitelist/one-per-role restriction; keep a nonempty-command guard |
| Curated versus All Apps | Inventory is not role-limited | Use the full inventory in All Apps; no need to add a separate curated section |
| Automatic updates | Directory watcher, 100 ms debounce, background rescan and applicationsChanged | Bind the organized menu to model and metadata changes; no extra scanner or polling |
| Install/remove/name/icon changes | Updates existing entry properties and diffs additions/removals | Verify menu propagation, re-sorting/regrouping, and stale activation handling |
| Categories and alphabetical order | Provides localized names, category lists and keywords | Choose category mapping/order, sort by name with stable ID tie-break, provide Other |
| Reachability and presentation | QML controls exist; current Start already uses ScrollView, grid and focusable tiles | Reuse current controls; adapt category layout and verify overflow, focus and target sizes |
| Visibility and duplicate IDs | Hidden masking, NoDisplay filtering, ID precedence across XDG directories | Preserve upstream inventory; do not deduplicate by display name. OnlyShowIn, NotShowIn and TryExec are not enforced or exposed as dedicated properties in these versions; defer that extra compliance work from the core fix |
| System/user/Flatpak/Snap locations | Reads XDG_DATA_HOME and XDG_DATA_DIRS, with standard defaults | Verify session export directories; correct session configuration only if missing, without a parallel discovery backend |
| Launching and icons | Parsed command, working directory, execute(), icon metadata and icon lookup | Keep existing execute() path and tile styling; verify missing/broken icon fallback and stale selection |
| Efficient updates | Rescans run in a thread pool; overlapping requests are queued and the model is diffed | Avoid unnecessary derived-menu rebuilds; preserve focus and scroll where practical |

Important limits to test rather than duplicate preemptively:

- The watcher tracks existing application directories and their immediate
  subdirectories plus parents at startup. A missing directory at startup is
  skipped; later-created directories and deeper nesting need explicit tests.
- It observes directory changes, not individual file content changes. Installation
  through new/replaced files and in-place metadata edits are distinct tests.
- XDG search paths are cached for the process. Newly introduced export paths may
  require session environment setup and a restart; existing configured paths do
  not need a custom Flatpak/Snap scanner.
- execute() ignores Terminal=true handling and Exec field-code expansion in these
  versions. Do not implement a replacement command parser as part of this
  missing-graphical-app fix; record any affected application separately.
- Metadata updates can occur without model membership changing. Derived category
  and sort views must react to name/category changes, not just list length.

Implementation order: remove the restrictive filter and sort the full inventory;
add category headings using existing tiles; verify native install/remove/metadata
updates and focus/scroll behavior. Add a compatibility workaround only for a
reproduced gap required by this scope. Do not reimplement the desktop-entry parser,
watcher, scanner, ID precedence, or process-launching backend.

## Implementation status

The PR now removes the role whitelist, uses the full Quickshell inventory and
sorts names alphabetically. Start uses category headings and the existing
StartMenuTile controls inside its existing scroll area. A stable-ID ListModel
changes only affected rows, preserves unaffected tiles, and restores focused
application identity after changes. Activation looks up the current desktop ID
before executing so removed/hidden entries are not launched from a stale object.
The shared Phone/Tablet app inventory also shows all eligible apps alphabetically.
Missing/broken Start icons fall back to the bundled glyph.

Native application-change notifications invalidate the derived inventory even
when only metadata changes. There is no polling timer, duplicate scanner or
custom Exec parser. Unrelated unmerged theme work is outside this change.

Source commit 7303182 passed Ubuntu and Arch source checks, including 67 Qt
results and the native Quickshell desktop-entry create/change/hide/remove test.
Package generation passed. Visual VM review, actual package installation/removal,
Flatpak/Snap session acceptance and physical-device checks remain pending.
The checklist above remains the acceptance target, not a claim that all runtime
behavior has been verified.

Validation for this tracking document: checked the current AppPolicy.js through
GitHub, reviewed its Start-menu use and the existing merged PR #2, and confirmed
the checklist distinguishes requested behavior from verified code observations.

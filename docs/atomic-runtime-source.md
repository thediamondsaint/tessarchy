# Package-safe active source (#75)

## Problem and source contract

Package-owned payloads are currently active watched sources:

- `packaging/tessera-shell/PKGBUILD:15–17` copies QML into the live tree.
- `packaging/tessarchy-session/PKGBUILD:15–20` installs the Lua entrypoint and
  adjacent dependencies there.
- `session/tessera-shell:3–9,21` selects that QML pathname for startup and IPC.
- `session/start-tessarchy:10–13,26–29` exports the data directory and starts
  Hyprland against its Lua pathname.

Staging a package archive does not stop the package manager from removing the
old installed files before extraction. Moving payloads to versioned package
paths alone also fails: the old package manifest still owns/removes old paths.
A post-transaction restoration is too late for a running watcher.

The complete dependency closure matters, not just two entrypoints: adjacent
`window-controls.lua`, relative QML/Python imports and ringtone assets, hypridle
configuration and generated wallpaper references. Static `0.1.0` dependency
versions do not establish matching payload content across package releases.

## Bounded proposed implementation

Pacman can own the installed program and source payload. Separating active
runtime copies from that payload is the proposed design, not an established
requirement of pacman. The scratch ownership control establishes exposure to
missing files under removal/repopulation; it does not rule out a package-owned
active-source design with transaction/reloader coordination. Such an alternative
must also protect lazy imports, helpers and assets and handle failed transactions.
The source review's absolute "must stop" wording overstates what was established.

1. Package complete candidates plus content/compatibility manifests, separately
   from active watched source. Validate a coherent candidate before publication.
2. Make actual copies into a non-pacman-owned, session deployment area. No active
   source or lazy dependency may resolve back into package-managed candidates.
3. Give each session stable regular QML/Lua bootstrap pathnames and stable IPC
   identity. Stage immutable complete generations; each bootstrap pins one exact
   retained generation. QML component wrapping needs a real software-Quickshell
   prototype before committing to a particular loader arrangement.
4. Activate explicitly, in-process: Quickshell `reload(false)` with generation
   acknowledgment and reload success/failure; compositor config-only reload with
   checked configerrors. Never call session startup or restart services as an
   activation mechanism. Two processes do not switch simultaneously: specify
   compatible sequential activation and rollback, not cross-process atomicity.
5. Retain all referenced generations until logout initially. Preserve explicit
   development-source selection, installed local modifications and preferences;
   do not silently replace a modified deployment with a stock package tree.

Installed Quickshell metadata exposes `reload(bool)`, `watchFiles`,
`reloadCompleted` and `reloadFailed`; shellRoot/shellDir are readonly constants.
[Upstream API reference](https://quickshell.org/docs/v0.3.2/types/Quickshell/Quickshell/).
A successful copy, atomic symlink switch or mtime change is not an activation
acknowledgment. Per-file atomic writes alone permit mixed-generation imports.

## Migration contract — accepted 2026-10-22 UTC

Owner response to the first-adoption migration question:
> Accept a one-time voluntary logout for first adoption

This permits requiring a voluntary logout before the first package transaction
that adopts protected runtime source. It does not authorize restarting the current
device, compositor/GPU work, or native/VM/package acceptance tests.

An already-running legacy session retains its original config pathname and
environment. Updating a launcher or systemd environment does not retarget it;
no supported in-process root-retarget API has been established. A guard installed
by the first transaction cannot be assumed to protect that same transaction.

The bounded safe proposal is a voluntary, one-time logout before adopting the
new launch contract, then in-process live upgrades on subsequent sessions.
Detect/refuse destructive upgrades of active legacy-owned sources, including
plain pacman paths, rather than killing apps or claiming transparent migration.
A zero-logout bridge is separate design work requiring actual package-manager
proof. The owner accepted the voluntary first-adoption logout allowance above.
No restart, package upgrade or runtime-path migration on the reference device.

## Executed ownership control, 2026-10-22 UTC

The actual `package()` recipes were run into a scratch package root. Their 153
generated files were removed and repopulated without invoking pacman, Quickshell
or Hyprland. All four selected QML/helper/Lua paths were absent during removal;
all four actual retained-copy controls survived unchanged. Repopulation restored
the original bytes. [Raw result](evidence/issue75-source-ownership.json).
This is a filesystem/recipe control, not real transaction or watcher acceptance.
The upstream reload API reference was also read: `reload(false)` attempts window
reuse, not a process restart; actual generation activation still needs proof.

## Real isolated pacman control, 2026-10-22 UTC

`python3 scripts/probe-package-replacement.py` runs real pacman under fakeroot
with private root/database/config/cache/log/GPG directories. All installed hooks
are masked in a private hook directory; no host or device package is changed.

Observed with three synthetic source files and three package versions:

- Ordinary upgrade: inotify DELETE events for all three originals, followed by
  CREATE/CLOSE_WRITE events; the selected source changed to version 2.
- `NoUpgrade`: no original-file deletion during replacement, all three originals
  stayed at version 1 and version 2 arrived as `.pacnew` files. A helper dropped
  by version 3 also remained on disk. The private package DB advanced to version 3.

This demonstrates that pacman **can** retain ownership while preserving active
files. It does not provide activation: `.pacnew` content must be deliberately
validated/promoted, dropped files cleaned up safely, and local edits preserved.
Reboot-time promotion is a potentially simpler alternative to runtime generations;
it changes the policy from live activation to activation on the next boot.
No real Quickshell/Hyprland watcher was started by this probe.

## Architecture comparison, 2026-10-22 UTC

| Route | Active source/lazy reads | Interruption and rollback | Assessment |
| --- | --- | --- | --- |
| Ordinary package replacement plus post-transaction reload | Missing/mixed paths remain exposed to watchers and helper launches. | Post hooks are skipped on failure/interruption; a reload is not transaction rollback. | Insufficient for uninterrupted updates. |
| Disable both reloaders around ordinary replacement | Suppresses parsing, not helper/asset reads or filesystem imports. | Requires independent restoration after a failed transaction; still no coherent old source tree. | Insufficient by itself. |
| `NoUpgrade` plus controlled activation | Existing matching paths survive and replacements become `.pacnew`; newly introduced paths still install normally. | Needs staged-file validation, local-edit reconciliation, stale/unowned-file cleanup and a recoverable promotion boundary. | Real preservation mechanism, now reproduced; not a complete activation design. |
| Package-owned sources, inactive-session updates | No Tessarchy consumer may remain active while package sources change. Session startup and updates need shared exclusion, not just a process check. | Failed/interrupted transactions must keep session admission blocked until repair/coherence checks. Downgrades run under the same guard. | Smallest defensible candidate **if recurring logout/offline updates are acceptable**. |
| Retained runtime generations | Keeps a full old dependency/helper/asset closure readable while package payload changes. Both consumers need a proven activation interface. | Retaining the old tree enables source rollback; it does not roll back an interrupted package transaction or changed system libraries. | Candidate for uninterrupted updates, with additional lifecycle/retention machinery. Not mandatory merely because pacman owns files. |

Source checks: libalpm 7.1.0 [`remove.c:589–595`](https://gitlab.archlinux.org/pacman/pacman/-/blob/v7.1.0/lib/libalpm/remove.c#L589-595),
[`add.c:248–250,302–350`](https://gitlab.archlinux.org/pacman/pacman/-/blob/v7.1.0/lib/libalpm/add.c),
[`trans.c:201–239`](https://gitlab.archlinux.org/pacman/pacman/-/blob/v7.1.0/lib/libalpm/trans.c),
and `alpm-hooks(5)` / `pacman.conf(5)` were read. Lazy helper consumers include
`CommunicationBackend.qml:49`, `RadioBackend.qml:10`, `PowerBackend.qml:17`, and
`WeatherBackend.qml:11`; watcher suppression cannot prevent their file reads.

**Policy boundary:** the accepted one-time first-adoption logout does not establish
permission to require logout for every future update. Rebooting the reference
device also does not make a later package transaction offline. The remaining
owner decision is recurring inactive-session updates versus uninterrupted updates;
no recurring-reboot policy or generation architecture has been adopted here.
The isolated probe is not device/package acceptance, a running-watcher test, or
an authorization to upgrade the reference device.

## Acceptance plan

- RED: scratch-only file removal/replacement reproduces legacy missing sources;
  mixed-generation and symlink-retarget controls reject incomplete guarantees.
- CPU-only GREEN: stable startup/IPC paths; complete-generation coherence;
  validation/activation fault injection; rollback; locking; retention; local-edit
  refusal; helper, theme and wallpaper resolution; legacy-upgrade refusal.
- Private software-Quickshell: stable PID, import/helper resolution and real
  reload acknowledgments/rollback. No compositor/GPU or personal-session access.
- Separately authorized VM acceptance: real package transactions with both
  watchers active, repeated upgrade/downgrade/interruption, unchanged process/app
  identities, no missing-file/parser errors and functional IPC/screenshots.

## Boundaries and dependencies

Independent branch from current upstream. #72/#74 app-lifetime work is related,
not an excuse to restart a legacy shell. Preserve #71/#73 and other installed
integration differences when eventual deployment is prepared; this branch is
not a replacement image for the reference device. No #77/native shutdown work,
plugin build/load, scaling, OSK gesture or touchpad changes. No host/system or
personal configuration changes. No native, VM or device package tests in this
scope-publication checkpoint. Keep #75 and the draft PR open.

AI-assisted source review and scope. The migration allowance is accepted; the
active-source ownership architecture remains a proposal, not a proven necessity.

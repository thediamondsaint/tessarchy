# Native shutdown repair overlay — partial implementation

This directory contains the first native components of the shutdown repair.
It is not installed by the Tessarchy package and is not a completed compositor
shutdown fix.

## Implemented

- `ScopedReadable.hpp`: event-loop-owned registrations with move-only cancellation
  handles, monotonic registration IDs and weak manager identity. Invalid FDs,
  poll errors and registration failures are explicit results. Readable completion
  takes/detaches its record before notification. Error/hangup takes precedence over
  readability. Closing the registry detaches its map before destroying closures,
  so closure destruction can safely cancel peers.
- `event-loop.patch`: adds this API to the actual `CEventLoopManager`, without
  changing ordinary `doOnReadable` callers (including eventfd-backed timelines).
- `TerminalDelivery.hpp`: shared per-request identity, revocation, metadata while
  pending, and terminal consumption before notification. Callback state stays
  alive if notification destroys its owner.
- `terminal-delivery.patch`: binds ext-image-copy-capture completion to the
  specific frame resource rather than raw owner `this` or a mutable current-frame
  member. Cursor callback/returned-error paths share one terminal state. Capture
  is marked requested before native share, terminal resources ignore subsequent
  non-destroy requests, and native ordinary-frame completion commits copied state
  and takes its callback before invoking it.

- `SubmittedWork.hpp`: renderer-owned payloads independent of scoped readable
  registrations. Cancelling delivery or closing the event registry leaves source,
  destination and render-target ownership in the queue. Native sync-file status
  is checked with `SYNC_IOC_FILE_INFO`; readiness alone is not success. Errors and
  failed registration retain their payload without delivering success. Drain
  passes one absolute deadline to every wait, retains ownership on timeout/error,
  and refuses unresolved-owner destruction.
- `renderer-retirement.patch`: moves explicit-sync submissions into that queue,
  with non-release-point source locks, a separate copy-destination lock/storage,
  renderbuffer and current/main/output framebuffer references captured before GL
  end resets them. Existing explicit source release-point import and ordinary
  output in-fence paths remain in place. Failed fence creation retains all source
  locks and destination resources instead of reporting a successful copy. The
  new renderer drain checks EGL binding, actual current display/context and reset
  status before retiring records. An early renderer destructor guard prevents
  member teardown with unresolved submissions.

- `ShutdownSequence.hpp` and `cleanup-integration.patch`: compositor cleanup now
  quiesces capture producers after plugin unload, cancels submitted delivery, then
  drains with one deadline before explicit framebuffer release and dependency
  teardown. Managed unique owners survive quiescence; stop/erase signals are not
  emitted during global cancellation. Timers and internal producer listeners are
  cancelled, and the lazy manager remains present but inert during client/monitor
  teardown. Ordinary parent-resource destruction now uses separate listener/resource
  detachment and retains its native session until the child frame dies. Cursor
  frames retain a separate shared native-state holder rather than parent resources.
- Submitted-work retirement has a checked-context release gate. Permission-snapshot
  framebuffers transfer to the submission instead of calling `release()` while
  their queued texture reads may still be pending. Full-fake and non-output-
  explicit-sync rendering now attempt native-fence retirement as well; the old
  unsupported `glFinish`/immediate-success branch is removed. Missing native fence
  support quarantines ownership and makes shutdown fail rather than claiming a
  bounded implicit drain. Existing synchronous SHM readback is not made bounded.
- Cleanup failure, exceptions and recursive cleanup exit nonzero with `_Exit`
  before unresolved owners unwind. Normal main cleanup and destructor fallback
  use the same sequence, independent of the earlier `m_isShuttingDown` flag.
  A destructor entered after the global compositor identity has disappeared
  fails closed instead of invoking dependency callbacks through that identity.
  The watchdog `end` marker moves after successful teardown. Packaged launcher
  exit-status handling is still separate work.

- `child-lifetime.patch`: ordinary protocol frames strongly retain their session
  wrapper and therefore its unique native session. Parent destruction detaches
  constraint/stopped listeners and destroys the parent Wayland resource immediately,
  without stopping the child. The frame still owns its independent delivery token;
  frame destruction cancels delivery before native-frame/session destruction.

- `cursor-lifetime.patch`: cursor frames become independently registered protocol
  owners. A shared holder keeps the unique native cursor session and source alive
  after either parent resource is destroyed. Parent listeners detach without
  cancelling frames. Source-stopped notification no longer erases its own native
  owner while emitting the signal. Frame destruction cancels only that frame's
  delivery; a later frame cannot receive an earlier frame's completion. Capture
  after source loss fails once instead of dereferencing an expired source window.
  The one-capture-session rule remains enforced even after that resource is destroyed.

This is a source overlay and CPU-tested partial repair, not compositor runtime
acceptance. Native EGL/GL, driver behavior, SHM readback timing and protocol
end-to-end GPU lifetime cases have not been executed.

## Verify without starting a compositor

Set `CHECKOUT` to this checkout and `HYPRLAND_SOURCE` to the matching configured
Hyprland source tree with `build/compile_commands.json`, then run:

```sh
python3 "$CHECKOUT/tests/native-fit/build-core.py" --source "$HYPRLAND_SOURCE"
python3 "$CHECKOUT/tests/native-fit/verify-core-controls.py"
python3 "$CHECKOUT/tests/native-fit/verify-retirement-controls.py"
python3 "$CHECKOUT/tests/native-fit/verify-shutdown-controls.py"
python3 "$CHECKOUT/tests/native-fit/verify-shutdown-methods.py"
```

The first command compiles and executes the real C++ primitives under ASan/UBSan,
using libwayland-server event loops, eventfd and pipes. It then creates a private
source overlay, applies the combined patch with `git apply --check`, and runs the
actual configured compiler's syntax checks for `EventLoopManager.cpp`,
`ImageCopyCapture.cpp`, `ScreenshareFrame.cpp`, `GLRenderer.cpp`,
`ScreenshareManager.cpp` and `Compositor.cpp`. The thirteen patched input
files are hashed before/after. This does not build/link the full compositor.

Output, combined `native-shutdown.patch`, source/header/patch hashes and a success
receipt live under `build/native-fit/core-shutdown`. The receipt is removed before
each invocation, so a failed run cannot retain an earlier green receipt.

The second command compiles deliberately broken **scratch copies** of the two
headers. It requires the map-clear variant to fail with the specific ASan
use-after-free in peer cancellation, and the non-consuming terminal variant to
fail the duplicate-delivery assertion. An unrelated error or compiler failure is
not accepted as RED. Production header hashes must remain unchanged. Neither
command launches Hyprland, a plugin, a GUI, or a GPU workload.

Previous cleanup-checkpoint execution: 14 shutdown-sequence cases and the 13 submitted-work
regressions passed under ASan/UBSan; the latter were rerun because their queue
header changed. Two new GREEN/RED controls distinguish failed-drain fallthrough
and bypassed explicit-release context validation; the two retirement controls
also still reject their exact defects. All six actual translation units passed
syntax checks, and twelve original input files were hash-unchanged.

`verify-shutdown-methods.py` extracts the exact quiesce/release and context/retire
method bodies from the verified overlay and compiles them against explicit CPU
mocks. Four groups pass under ASan/UBSan with real Hyprutils unique/weak ownership;
EGL binding, reset status and framebuffer release are mocked, not GPU evidence.
The extraction and overlay source hashes are recorded separately. The sequence
suite uses real Wayland scheduling and injected native-fence completion, plus
actual kernel rejection of eventfd/invalid FD as sync_file.

Reproduce this focused checkpoint with `--test test-shutdown-sequence --test
test-submitted-work` on build-core, then the shutdown-controls, retirement-controls
and shutdown-methods scripts above. Earlier scoped-readable/terminal cases and
their controls were not rerun unchanged. No compositor, EGL/GL workload or full
compositor link was executed.

The parent/frame checkpoint has a separate focused entry point, without rerunning
unchanged primitive suites:

```sh
python3 "$CHECKOUT/tests/native-fit/verify-child-lifetime.py" --source "$HYPRLAND_SOURCE"
```

Executed: eight ordinary ownership cases, sixteen cursor ownership cases and a
cursor source-stop/replacement group pass ASan/UBSan. The test compiles extracted
production declarations, ordinary frame methods, cursor constructor/frame methods
and destruction paths with the actual generated ext-image-copy-capture protocol,
real libwayland-server socket dispatch and real Hyprutils owners/signals. Native
capture/render dependencies and constraint generation are explicit CPU mocks.
Tests cover parent destruction before/after capture, request versus server-side
ordinary parent destruction, either cursor parent, source loss, child destruction
before completion, duplicate completion, detached source signals and old completion
after frame replacement. They assert the destroyed parent resource disappears
immediately while native state survives.

Five scratch RED variants fail their named assertions: parent stop, weak parent
ownership, retained parent resource, premature cursor-native reset and source-stop
erasing the capture parent. Six real compositor translation units syntax-check;
fifteen original inputs, including generated protocol source/header, are unchanged.
Current receipt: `build/native-fit/child-lifetime/verification.json`; full log:
`build/native-fit/child-lifetime-build.log`. Its patch/header/source/test hashes
are checked. This focused run invalidates the older core success receipt rather
than presenting unchanged primitive runs as new verification.

## Render-submission wiring checkpoint

```sh
python3 "$CHECKOUT/tests/native-fit/verify-render-submission.py" --source "$HYPRLAND_SOURCE"
```

This focused runner extracts the exact current overlay `endRender` and
`retireResources` methods, compiles/executes them under ASan/UBSan with real
Hyprutils ownership and Wayland scheduling, then syntax-checks the six actual
compositor translation units. No unchanged primitive suites run.

Executed: 96 cases covering four render modes, output explicit-sync on/off,
absent/invalid/valid mocked native-fence manager, rejected/accepted release
context, and ordinary delivery/cancelled delivery. Assertions cover source and
destination locks/storage, current/main/output/transient framebuffer retention,
renderbuffer retention, explicit source release-point imports, output in-fences,
exactly-once explicit FB release and failure quarantine. Four scratch RED controls
reject Full Fake early return, implicit immediate success, omitted release-point
import and discarded transient FB at named assertions.

Successful fence status and GL/EGL operations are injected, not native-driver
proof. Actual kernel ioctl independently rejects the scheduling eventfd as a
sync_file. Thirteen original source inputs remain unchanged. Current receipt:
`build/native-fit/render-submission/verification.json`; complete log:
`build/native-fit/render-submission-build.log`. The runner hashes extracted
methods, tests, itself, patches, headers and overlay and invalidates stale core
success evidence before preparing the overlay.

## Cancellation reentrancy checkpoint

```sh
python3 "$CHECKOUT/tests/native-fit/verify-teardown-producers.py" --source "$HYPRLAND_SOURCE"
```

Production cancellation marks **all** ordinary/cursor owners stopped and all
pending frames failed before listener/timer/callback destruction can release or
reenter peers. Listener/timer detachment precedes completion-closure cancellation;
managed unique owners remain retained through checked drain.

Executed: 14 ASan/UBSan CPU cases run extracted actual manager quiesce/release
methods through `CShutdownSequence`, with real Hyprutils unique/weak owners and
signals plus actual Wayland timers. Twelve closure-phase/peer-destruction cases
assert inert peers, recursive quiescence, cancelled timers, detached signals,
pre-drain owner retention and exactly-once FB release before dependency loss.
Two subprocess cases require failed/throwing drain exit 1 with no owner unwind,
explicit FB release or dependency teardown. Native resources and drain outcomes
are injected, not GL/GPU evidence. Three scratch controls delaying session stop,
cursor stop and frame failure each fail the matching assertion.

Six actual translation units syntax-check; thirteen original inputs remain
unchanged. Current receipt: `build/native-fit/teardown-producers/verification.json`;
complete log: `build/native-fit/teardown-producers-build.log`. Current runner/test,
extracted method, header, patch and overlay hashes are recorded. Unchanged earlier
suites were not rerun; the core success receipt is invalidated before preparation.

## Continue implementation

1. Execute actual generated protocol owner destruction with the cleanup barrier,
   then extend producer admission coverage beyond capture-manager cancellation.
2. Repair packaged-launcher child failure separately, retaining existing
   safe-mode restart and lock policy. The private harness owns a direct child.
3. Native driver/fence availability and synchronous SHM readback bounds remain
   outside runtime acceptance. Missing native fence support stays fail-closed.

Preserve existing plugin incoming-argument ownership and reverse-unhook fixes.
Compositor launches remain disabled during this implementation stage.

## Upstream material

The patch context is derived from Hyprland's BSD-3-Clause-licensed source.
`LICENSE.upstream` preserves its copyright and terms. Applied base-file hashes
are recorded in the verification receipt; a directory name alone is not revision
proof.

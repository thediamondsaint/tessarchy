# Isolated native-window fitting proof

This is a **synthetic native Wayland fixture**, not a mobile-ready desktop-app result. Nothing here is installed by Tessarchy's packages/session. The compositor extension uses exact-version private hooks and must not be loaded into a user's live compositor.

## Build and run

Required, already-installed tools/libraries: C/C++ compilers, `pkg-config`, Wayland client headers, `wayland-scanner`, `wayland-protocols`, exact matching Hyprland headers/runtime, `hyprctl`, `grim`, and Pillow for screenshot assertions. The scripts do not install dependencies or edit personal/system configuration.

From a checkout, with absolute paths substituted:

```sh
python3 /path/to/tessarchy/tests/native-fit/build.py \
  --plugin \
  --pointer-xml /path/to/pinned-Hyprland-source/protocols/wlr-virtual-pointer-unstable-v1.xml
python3 /path/to/tessarchy/tests/native-fit/nested.py --seconds 900
```

The second command stays running for the bounded session. In another terminal:

```sh
python3 /path/to/tessarchy/tests/native-fit/verify.py
python3 /path/to/tessarchy/tests/native-fit/verify-touch.py
```

`--pointer-xml` must point to the inspected upstream protocol, not a fabricated protocol stub. The proof was exercised against Hyprland `efb50993780079460b0cbed1363e2166a2de1d9f` / 0.56.2. Compositor ABI hash mismatch is rejected.

The harness discovers the real parent display, but creates a private HOME, XDG directories, short runtime, invalid private D-Bus/seatd socket addresses, separate compositor instance, and headless `FIT-1` output. It disables session-manager environment export and does not use the parent's control socket. Virtual input additionally verifies the Wayland server's PID/UID with `SO_PEERCRED` before creating a pointer. No physical input is injected. A terminal signal stops only the tracked child processes; evidence stays in the ignored `build/native-fit/nested-*` directory.

## What the fixture proves

- Server allocation: 410×800. Client deliberately commits 832×800, ignoring the too-small configure to model the measured native-layout mismatch.
- Baseline: the rightmost red marker is clipped.
- Fit: the full native client is proportionally displayed, including all four edge markers; unused allocation is letterboxed.
- A real virtual-pointer click at screen `(400,200)` reaches the actual client at approximately `(811.707,405.855)`. The expected inverse transform is independently calculated from the dimensions and checked within Wayland coordinate quantization tolerance.
- Five repeat captures keep the right edge visible and the original client alive.
- Disable, unload, reload and second unload are exercised. Baseline pixels are restored exactly and input mapping returns to unscaled coordinates.

`proof.json` contains actual execution measurements; `comparison.png` places the real before/fit captures side by side. Neither substitutes for real-application acceptance.

## Failures caught while building this proof

1. **Optimized C++ hook ownership:** never assign/reset/move-from the UV hook's incoming shared-pointer parameter. The installed caller saves its original control-block pointer and decrements it after the call. Resetting the intercepted parameter causes another decrement, destroying a still-listed window. The proof now creates a separate forwarding value. This was confirmed by disassembly and core control-block data, not fixed by hiding null-window errors elsewhere.
2. **Reload lifetime:** module globals can survive a load/unload cycle. Hyprland owns hook objects; retain no pointers to them after unload. A failed second unload exposed a vector holding ten entries, including five freed old hooks. Exit/error paths now clear the vector, and the test includes a second complete load/unload.
3. **Isolation details:** `vfr` lives under `debug` in this compositor version; `configerrors` may return `[""]` for no errors. Long runtime paths break the event IPC socket's AF_UNIX length limit. Plugin loading reloads Lua, so headless/output-disable policy must be persisted in the private config rather than only evaluated transiently.

## Single-contact touch proof

`verify-touch.py` creates a compositor-local synthetic Aquamarine touch source, registers it through the normal touch-device manager and checks events received by the actual client `wl_touch` listener. It never creates a kernel/uinput device or injects into the parent compositor. This exercises the compositor input pipeline, not physical hardware or libinput calibration.

- Baseline and disabled fitting preserve unscaled down/motion/up.
- With fitting active, screen down `(300,100)` arrives at native `(608.781,202.926)` and motion `(350,150)` arrives at `(710.242,304.391)`, within 0.01 of independently calculated coordinates.
- A deliberate motion-correction-off control produces `(658.781,252.926)` instead, demonstrating why down-only hit testing is insufficient.
- Repeat contacts, unload during an active contact, capability removal, reload and second device removal pass. A strong wrapper reference is retained during device teardown; pointer listeners are detached before destroying the synthetic AQ source.
- Receipt: `touch-proof.json` in the session directory, also published as [the touch execution receipt](../../docs/native-window-fit-touch-proof.json).
- Harness startup waits for IPC readiness before creating its headless output; a nested Wayland output is not required to be present first.

## Noninteractive letterbox gate

The touch verifier also tests a new contact and pointer click in visually black padding, followed by positive contacts/clicks in displayed content as event-order barriers. Before the outer-selection fix, padding delivered a bogus touch-down at `(0,0)` and a pointer click at `(100,600)` to the app. The [actual RED observation](../../docs/native-window-fit-letterbox-red.json) records that failed gate. Rejecting a surface hit alone was insufficient: `InputManager.cpp` falls back to the selected window's root surface when `windowSurfaceAt` returns null. The outer `windowAt` hook now rejects padding first. Both input types are absent from the client log in the updated touch receipt; content remains interactive.

After rebuilding a plugin, start a **fresh private compositor**. Unload/reload may retain the old DSO/code even after the file is atomically replaced. This was confirmed by `/proc/<child>/maps` retaining the deleted old inode, distinct from the rebuilt file. Both verifiers now reject a mapped plugin inode that differs from the current build.

## Not yet accepted

Physical/multicontact touch, cancellation, pointer grabs/drags/scrolling, nonzero window geometry origins, subsurfaces/popups, rotation, fractional output scaling, OSK/IME cursor rectangles, incremental damage/occlusion, real native applications, and real-device use remain separate gates. Letterboxed padding now rejects new pointer/touch input in the fixture. This does not establish overlapping-window click-through or popup behavior. Fitting also shrinks application controls; it does not guarantee 48dp targets or responsive reflow. Do not ship this prototype as the completed #77 fix.

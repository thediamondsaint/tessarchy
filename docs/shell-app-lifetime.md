# Application lifetime independent of shell — issue #72

Verified regression: systemd's default KillMode=control-group stops applications
launched inside tessera-shell.service. Quickshell.execDetached does not escape
that cgroup; the device showed Foot/Fish and Discord in the shell's cgroup.
Forking or exec alone is not an isolation mechanism.

## Scope before implementation

Use independent systemd user application units/scopes for app launches, preserving
argument boundaries, working environment, normal session shutdown and useful
logging without inheriting shell output lifetime. Keep supervision of the shell
and its own helpers. Do not weaken KillMode globally as a substitute for ownership.
Coordinate with runtime PR #62, which introduces shell service supervision.

QML changes should normally use Quickshell live reload, not process restart.
Verify reload success, unchanged shell PID and surviving apps. Still prove app
survival across a deliberate restart and crash in the VM, because live reload
alone cannot fix app ownership on failures. The Discord write EIO connection is
unverified and must not be presented as established.

## Acceptance / takeover

Publish the minimal fix, focused tests and full integrated checks. In the VM,
launch real apps through the shell, inspect independent cgroups, verify unchanged
app PIDs/windows across QML live reload, shell service restart and shell failure.
Check output lifetime and preserve safe session cleanup. Back up and restore the
VM files/settings atomically. No ASUS mutation or restart during development.

Current integration is on `fix/issue-72-app-lifetime`, based on current `main`.
`tessarchy-launch` starts transient user services (Type=exec, journal output)
with argv and caller environment intact; DesktopEntry launches pass their parsed
`command` and `workingDirectory`. eSIM Manager also uses the launcher.
Application units are `PartOf=tessarchy-apps.target`; session services start that
target and `start-tessarchy` stops it on compositor exit, without coupling it to
shell-service restarts. `graphical-session.target` refused explicit manual starts
in the earlier VM test, so the dedicated target is also PartOf the standard
graphical-session target. `systemd-run` is required; failure is reported rather
than falling back to shell-owned `execDetached`.

On the integration of #62/#63/#64/#67/#68, full `scripts/check.sh` passed 227
Python tests; the upstream-only branch passed 218 Python tests. QEMU verified
Foot and Firefox launched from actual shell tiles in separate service cgroups;
PIDs and window addresses survived QML reload, deliberate shell service restart
and SIGKILL shell crash/recovery. Output in the surviving Foot remained usable.
A transient test application with PartOf=tessarchy-apps.target stopped when the
session target was stopped, while shell and older app units were unaffected.
Details and restore evidence are in `docs/testing.md`.

The existing PR #74 QEMU run covers the preceding source branch. The current-main
launcher wiring passes the recorded source checks, but still needs this branch's
own QEMU restart/crash retest before issue #72 is ready to close. Physical session
exit remains separate acceptance.

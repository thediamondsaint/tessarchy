# Honest status indicators (#73)

Scope: correct the existing status presentation without replacing communications,
network or power backends. Preserve dimensions, touch targets and click/focus
behavior. Unavailable cellular must never imply reception; normalized reported
strength must select a corresponding glyph. Battery presentation must show level
and actual charging, with an explicit unavailable state and accessible detail.

Based on current upstream main, independent of #71 / PR #87. Coordinate with
PR #68 (native Wi-Fi binding) and #54 (networking backend): neither is a dependency;
this change preserves existing backend ownership and does not implement network
configuration. Wi-Fi measurement remains a separate integration where unavailable.

Acceptance began with focused regression RED/GREEN, safe constituent checks,
and actual before/after offscreen Qt Quick software rendering. The initial
implementation checkpoint did not include deployment. Subsequent owner-authorized
reference-device integration is recorded below; native compositor/GPU work and
package installation remain outside this issue's deployment scope.

Status: implemented in draft PR #88. Existing cellular device/service flags now
gate reception; normalized signals select five levels without a fabricated
fallback. Battery glyph shows level and actual Charging, with explicit unknown
data and accessible/hover detail. Both shell locations pass ready/presence/state.
No backend replacement or geometry change.

Actual verification: focused RED/GREEN; 103 offscreen/software Qt results,
26 relevant Python tests (one skipped for missing GI), QML lint exit 0 with
integration metadata warnings, Bash and Lua syntax passes. `check.sh` was not
run because its compositor verifier is forbidden in this scope. Fish/ShellCheck
are unavailable; desktop validation has only the documented DesktopNames
diagnostic. See [testing record](testing.md#honest-status-indicators-73-2026-10-22)
and [before/after fixture capture](evidence/issue73-status-before-after.png).

## Reference-device integration, 2026-10-22 UTC

Integrated on the separate public `sync/status-20261022` branch with PR #87's
vertical centring and the previously installed native Wi-Fi/app-lifetime changes.
The complete installed source matched that integration except for the intended
status changes. Full source and private preference backups were verified locally
and remotely before deployment. Only 16 status source/assets were replaced,
dependencies first and root last, using atomic replacement and preserved ownership.

Actual integration checks: 151 offscreen/software Qt results passed; selected
status/power/communications Python suites passed with one GObject skip. The live
shell logged `Reloading configuration` then `Configuration Loaded`, with no new
warnings/errors. Shell, compositor and existing application identities survived;
compositor configerrors were empty and private preferences remained byte-identical.

The real UPower display device reported 95% discharging before deployment and
92% discharging at the post-deployment check; the inspected live bar showed 92%
and a corresponding filled battery, without a charging bolt. The ModemManager
service had no system-bus owner (the CLI was unavailable); cellular now renders
unavailable rather than the old invented reception. This establishes service
unavailability, not a hardware modem inventory or RF-strength test. Native Wi-Fi
binding remains intact. Both captures were already in a touch layout; no layout,
scaling or personal-app settings were changed.

Physical charging/unplug transitions and modem RF acceptance remain outstanding.
Keep this PR draft and #73 open pending owner review/upstream integration. See
[device integration record](https://github.com/Person1873/tessarchy/blob/sync/status-20261022/docs/status-device-integration.md).

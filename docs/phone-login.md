# Phone PIN sign-in

The owner selected a four-digit PIN as the Linux account password. greetd/PAM authenticates a new session. The login page
has the Quiet Edge wallpaper, Tessarchy mark, mobile clock, four masked dots,
glass numeric keys and an icon for deletion. The fourth digit submits once;
keyboard digits, Backspace, Escape and Enter are supported. Keys remain at least
48 logical pixels wide and tall; compact layouts scroll if needed.

`PinScreen.qml` handles entry without writing a PIN to disk. `PinLoginController`
creates a greetd session for the configured account, responds to exactly one
secret challenge, clears its pending value, and launches the fixed
`/usr/bin/start-tessarchy` command only after authentication succeeds. Visible
or additional secret challenges and passwordless success are rejected. Attempts
time out after 30 seconds. Failure clears pending input and delays retry for
three seconds; PAM remains responsible for system account policies and rate
limits. If cancellation cannot return the backend to idle, the greeter exits
and greetd can restart it. The controller keeps submitted PINs out of command arguments, environment,
settings and logs. Private credentials stay outside the repository. Session locking, storage protection and first-boot enrollment have separate
implementation tasks in AGENT-README.md.

Both login paths use the installed start-hyprland watchdog with explicit config
arguments. The separate greeter Hyprland configuration loads no user preferences or
application-launch bindings. It starts only the greeter. The launcher exits
that compositor when Quickshell exits, allowing greetd to start the authenticated
session. greetd uses its packaged PAM configuration; no custom PAM module or
permissive PAM stack is shipped. `source_profile=false` avoids login-profile
side effects before the explicit session command.

## Review and package layout

UI preview: `qs --path shell/login-preview.qml`. The preview is labelled and
sign-in is disabled.
The actual entry point is `shell/greeter.qml`, launched through greetd.

`scripts/package.sh` now also builds the opt-in `tessarchy-greeter` package.
It depends on greetd and the normal Tessarchy session packages. It installs a
namespaced `/etc/greetd/tessarchy.toml`, `/etc/tessarchy/login-user`, the greeter
launcher/config, and a greetd systemd drop-in selecting that config. It does not
enable or start the service. It does not overwrite `/etc/greetd/config.toml`.
The public account-name file defaults to `tess` and contains no credential.
The package creates /var/lib/tessarchy-greeter with private greeter ownership
and uses it as HOME, including on systems where greetd's account home is /.
For a fixed kiosk display, set TESSARCHY_GREETER_OUTPUT and TESSARCHY_GREETER_MODE
in the greetd command environment. Their default is the preferred native mode;
only the development VM explicitly selects Virtual-1 at 390x844@60.

The existing ISO continues to use its locked live account and autologin. This
experimental greeter is not enabled in ISO staging: enabling it without a
provisioned account password would strand testers. Published Alpha 2 is unchanged.
First-boot PIN enrollment for disposable/live media remains future work.

## VM activation procedure

1. Keep a VM snapshot and the current SSH connection/recovery TTY available.
2. After explicit owner permission, install greetd in the VM and the three local
   Tessarchy packages. No host package/configuration change is needed. Built
   candidate packages are under ignored `build/phone-login-packages-v4/`.
3. Set `/etc/tessarchy/login-user` to `arch` for the current development VM.
4. Have the owner choose a four-digit account password. Set it directly in the
   VM through standard password tooling; do not save it in source, shell command
   arguments, transcripts, scripts or build images. Existing account-password
   recovery and PAM policy still apply. The current password must change before
   this numeric-only greeter can authenticate the account.
5. Back up and remove only the known development tty1 autologin override, and
   disable tty1 getty autologin. Preserve another recovery TTY. Check the package
   PAM stack, greeter account/home permissions and graphical default target.
6. Enable greetd for the next boot. Starting it immediately conflicts with tty1
   getty and can end the current session; get explicit confirmation before that
   session exit/reboot. Preserve user applications until then.
7. Verify a wrong PIN does not start Tessa, the chosen PIN starts the session,
   and session exit returns to the phone greeter. Inspect logs without recording
   secrets. Verify the recovery path before declaring boot-time login complete.

Rollback: disable greetd, restore the saved tty1 configuration, then re-enable
that previous login path. Rollback does not silently restore the old password.
Do not claim secure locking: this feature authenticates a new session and does
not protect an already-running session with a Wayland session lock.

## References

- [Quickshell 0.3.1 Greetd API](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Greetd/Greetd/)
- [greetd configuration](https://man.archlinux.org/man/greetd.5.en)
- [greetd IPC protocol](https://man.archlinux.org/man/greetd-ipc.7.en)

## Actual development VM result

The owner approved dependency installation and one VM restart. greetd and the
local packages were installed, the selected four-digit account password applied
through hidden stdin, and greetd enabled in place of tty1 getty. The original
systemd configuration is backed up under /root/tessarchy-login-before/systemd.
No host configuration or package was changed and the stock PAM stack is intact.

A wrong PIN was rejected by real PAM and did not start Tessa. The chosen PIN
started the user session. Confirmed session exit returned to the phone greeter.
After both launch paths switched to start-hyprland, the greeter and authenticated
desktop had no launcher warnings; the desktop's configerrors result was empty.
The final native 400x800 display and real greeter/rejection/home captures were
inspected. These are development-VM checks, not a new ISO boot test or locking
claim. The private development Tessa copy remains the user session's selected
source; the greeter itself runs the installed system package.

## Public alpha demo

The owner-designated public demo account is documented in
[Alpha login details](../README.md#alpha-login-details). Private user-selected
credentials continue to stay outside source and logs.

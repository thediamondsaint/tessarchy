# Tessa AI and SSH control

Tessa exposes a local, named IPC surface for an approved AI client. The
`tessa-ai` helper delegates to the running Quickshell instance and accepts only
whitelisted operations: opening pages, launching installed desktop entries,
themes, radios, volume, mute, screenshots, keyboard visibility, window
switching, and native scrolling. It does not evaluate arbitrary shell text or
grant root access.

Examples:

```sh
tessa-ai open settings
tessa-ai launch chromium
tessa-ai radio wifi
tessa-ai tape next
```

The `ai` Quickshell IPC target is intentionally local to the user session. A
remote model must authenticate through the user's own SSH session before it
can call it; Tessa does not expose the shell IPC socket to the network.

SSH support is packaged through OpenSSH but remains opt-in. `tessarchy-ssh
check` validates the effective configuration; `sudo tessarchy-ssh enable`
creates missing host keys, validates `sshd`, and enables the service. The
default drop-in disables root login, X11 forwarding, agent forwarding, and
keyboard-interactive authentication while retaining password login for first
boot setup. After installing a key, set `PasswordAuthentication no` in a
machine-local drop-in and run `sudo systemctl reload sshd`.

The live ISO carries OpenSSH but does not enable `sshd` automatically. This
keeps a disposable image closed until the operator explicitly starts it.

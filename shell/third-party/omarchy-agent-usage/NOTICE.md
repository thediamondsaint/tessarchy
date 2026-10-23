# Omarchy agent usage bridge

Tessa adapts the read-only Codex app-server exchange used by Omarchy's agent
usage plugin. The upstream implementation is MIT licensed:

<https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-agent-usage-codex>

Tessa keeps the same `account/read` and `account/rateLimits/read` requests and
adds the current official `account/usage/read` request. Credentials remain in
the official CLI/app; Tessa never reads or stores them.

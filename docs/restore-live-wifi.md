# Restore live Wi-Fi signal binding

The owner's working on-device shell used Quickshell.Networking to locate the
Wi-Fi device and read the connected network's measured signalStrength. A package
refresh overwrote that uncommitted live change with the upstream -1 placeholder.
The original implementation was recovered from the verified pre-update backup.

## Implemented recovery

Restored the same native Networking approach for the indicator, with safe
no-device/no-connection fallbacks and regression coverage for reactive strength
and disconnect updates. Quickshell v0.3.2 documents signalStrength as 0.0–1.0;
there is no percentage conversion. No radio configuration is changed.

Coordinate with #54, which implements a broader networking backend using a
different mechanism. This is minimal recovery, not a new connection manager.

## Actual validation

Feature checks and integrated checks passed. The integrated run executed 222
Python tests (one skipped) and 88 Qt test results, zero failures. Pure policy
coverage includes absent hardware, disconnected networks, zero/full signal,
selection of the connected network, and live signal/disconnection updates.

On the real ASUS, a separate read-only Quickshell probe reported a connected
Wi-Fi network with signalStrength 0.58. Confirmed no altered installed package
files before the recovery; backed up and verified the full working shell tree
and settings again. Installed shell 0.1.0-6 on the integration branch, restarted
only the shell, and verified active service with zero automatic restarts, loaded
configuration, and no Hyprland configuration errors. Inspected the resulting
screenshot: the top bar shows the connected Wi-Fi icon. No RF disconnect or
reassociation was performed, so real connection transitions remain untested.

## Takeover

The integration branch contains this recovery alongside #62/#63/#64. The original
private backup is retained but not published. Preserve and compare live source
edits against the installed package before every future upgrade, not only settings.
The next product work remains #65 Desktop gap, then #66 Recents button.

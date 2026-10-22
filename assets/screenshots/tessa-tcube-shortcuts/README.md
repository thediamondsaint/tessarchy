# T cube touch shortcuts — actual VM captures

These are unedited QMP screendumps from the existing Tessarchy QEMU guest after
commit `38427ec` was installed. The tablet home capture shows the persistent
Phone/Messages/Keyboard bottom dock removed. The expanded T cube capture shows
those icon-only actions in the themed glass action grid.

- `tablet-home-no-dock.png`: 1024×768 tablet home, Tessa aurora-fold wallpaper.
- `tablet-cube-shortcuts.png`: 1024×768 tablet, expanded T cube with Phone,
  Messages and Keyboard controls.

The VM uses the existing qcow2 disk and a temporary `std` video device because
the default host `virtio-vga` initialization crashed QEMU. No guest disk was
replaced or reset. Physical touchscreen latency remains untested.

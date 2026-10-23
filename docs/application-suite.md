# Tessa application suite

The tablet profile and live ISO preload a small set of everyday applications:

| Role | Application |
| --- | --- |
| Browser | Chromium (Chrome-compatible) |
| Terminal | Foot |
| Files and removable media | Nautilus, GVFS, udisks2 |
| Text and office documents | GNOME Text Editor, LibreOffice |
| PDF documents | Papers |
| Images | Loupe |
| Touch notes | Rnote |
| Digital painting | Krita |
| Media | mpv, Celluloid, Amberol |
| Archives | File Roller |
| Calculator | GNOME Calculator |

Tessa owns the launcher, quick controls, screenshot path, touch file-dialog
integration, audio controls and window navigation. That keeps the base image
small while avoiding duplicate browsers, file managers and background daemons.
Applications are discovered through their installed desktop entries, so the
preloaded set and later user-installed applications use the same launcher path.
The suite also installs a **ChatGPT** desktop entry. It opens `chatgpt.com` in
Chromium app mode, with the Tessa cube shortcut using the same browser path when
the optional native ChatGPT client is absent.

The roles follow the essential browser, file manager, editor and calculator
bindings in [Omarchy](https://github.com/omacom/omarchy/blob/quattro/default/hypr/bindings/applications.lua),
and the terminal, media, screenshot and audio categories used by
[Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots/wiki/Packages_Required).
No source code was copied from either project.

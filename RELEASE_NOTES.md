TouchCursor with two activation keys
==================================

This fork implements the second activation-key request in upstream issue #7 and PR #24.
Choose an optional second activation key in Configure, General. Both keys activate
the same mappings. Set the second selector to None to keep the original behavior.
Tapping either activation key still types that key; existing key mappings and
version-6 settings remain supported.

The configuration window sizes itself to show both selectors and their dropdowns.
This revision fixes a clipped second selector found while reviewing the first
build's screenshot.

Download and extract the Windows x86 ZIP into one folder. Keep the EXE and DLL files
together. Exit any running TouchCursor before starting this version. Run
touchcursor.exe, then open Configure from its tray icon. The x86 application also
runs on 64-bit Windows. The files are unsigned.

Back up %APPDATA%\TouchCursor\settings.cfg before trying a new version. This build
uses archive version 7. Restoring the backed-up configuration allows a rollback
to the previous version.

The build runs the actual hook's synthetic keyboard regression suite, settings
round-trip and version-6 migration tests, and a configuration-window smoke check
on a Windows runner. Physical-keyboard behavior on the recipient's own Windows
installation remains a final acceptance check.

Source: https://github.com/kalidatuna/touchcursor
Upstream PR: https://github.com/martin-stone/touchcursor/pull/24
License: GNU GPL v3 or later, see COPYING.txt. Dependency licenses are bundled.
wxWidgets 3.2.6 and Boost 1.86.0 are built from their published source releases.

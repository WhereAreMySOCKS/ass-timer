# Patched desktop plugins

These packages are pinned locally so Windows stability fixes remain reproducible:

- `tray_manager` 0.5.3: zero-initializes Win32 notification structures,
  validates tray icon creation, and safely releases native resources.
- `desktop_multi_window` 0.3.0: guards `WM_FONTCHANGE` during engine teardown.

The original package licenses are retained in each package directory. Reapply
and verify these patches before upgrading either upstream dependency.

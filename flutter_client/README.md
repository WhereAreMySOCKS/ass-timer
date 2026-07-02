# Ass-Timer Flutter Client

Ass-Timer 2.x Flutter desktop client for macOS 13+ (Apple Silicon) and Windows 10/11
(x64). The Swift client remains next to this directory as the rollback build.

```bash
flutter pub get
flutter test
flutter run -d macos
```

Production API URLs default to `https://api.guiji.online/ass-timer`. Override
them for local development with `--dart-define=ASS_TIMER_API_URL=...` and
`--dart-define=ASS_TIMER_WS_URL=...`.

## Architecture

- The pet/root engine is the only owner of timers, persistence, HTTP and the
  WebSocket connection.
- Bubble and control-center windows are separate Flutter engines. They receive
  revisioned snapshots and send commands through `desktop_multi_window`.
- `DesktopHost` is the only layer that calls desktop window/tray plugins.
- macOS keeps the legacy `Paul.----` bundle identifier so UserDefaults and
  `Application Support/AssTimer` data can be migrated in place.

## Release builds

macOS arm64 DMG:

```bash
./tool/build_macos_release.sh
```

Windows x64 portable ZIP (run from PowerShell on Windows 10/11):

```powershell
.\tool\build_windows_release.ps1
```

Both scripts run dependency resolution, static analysis and tests before
packaging. The applications only open the platform-specific browser download;
they never install updates in-app.

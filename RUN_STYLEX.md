## Stylex local run commands

This project lives under a path with spaces (`Work Files`), which breaks some
Flutter native asset hooks. Use the helper scripts in this folder.

### Option 1: start a ready-made shell

```powershell
.\tools\stylex-shell.cmd
```

Then run:

```powershell
flutter clean
flutter pub get
flutter run
```

### Option 2: run Flutter directly through the wrapper

```powershell
.\tools\flutter.cmd --version
.\tools\flutter.cmd clean
.\tools\flutter.cmd pub get
.\tools\flutter.cmd run
```

Both scripts map the workspace root to `X:` and run Flutter from there so the
build does not use the original path with spaces.

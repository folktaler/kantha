# Kantha studio

The Flutter app behind [kantha.app/studio](https://kantha.app/studio) and the Android and iPhone apps.
One code base for all 3. Everything runs on the device: the pattern solver, colour measuring, the PDF
and the photo. Boxes, photos and designs are kept in a local database (drift, SQLite).

| Path | What it holds |
|---|---|
| `lib/solver/` | Geometry, patterns, colour and the solver. No network, no database. |
| `lib/data/`, `lib/backup/` | The local database, and the backup file. |
| `lib/studio/` | The screens. |
| `lib/l10n/` | The word files, made from `../messages/en.json` by `tool/l10n_from_messages.dart`. Do not edit them by hand. |
| `integration_test/` | The 2 journeys, run in Chrome by `tool/journeys.sh`. |
| `tool/` | The web build (`build_web.sh`), the journeys, and the scripts that make generated files. |

Flutter 3.47.6:

```bash
flutter pub get
flutter run -d chrome
flutter analyze
flutter test --exclude-tags pixels
./tool/build_web.sh    # the web build, into build/web
```

How to contribute, and every check to run: `../CONTRIBUTING.md`.

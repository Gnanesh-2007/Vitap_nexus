# VITAP Nexus (Flutter app)

This folder is the Flutter app. For what it does, screenshots of the widgets, architecture and credits, see the [main README](../README.md).

```bash
flutter pub get
flutter run
```

Needs Flutter (Dart `^3.12.2`), a Rust toolchain, and Android NDK `28.2.13676358`.

| Path | What is in it |
| :--- | :--- |
| `lib/screens` | One file per screen |
| `lib/providers` | Riverpod state: auth, theme, cached VTOP data |
| `lib/services` | VTOP client wrapper, storage and cache, widget sync |
| `rust/` | `lib_vtop`, the on-device VTOP engine (Apache-2.0, see its LICENSE) |
| `android/app/src/main/kotlin` | Home-screen widgets (`WidgetRender.kt`, `WidgetUpdater.kt`) |

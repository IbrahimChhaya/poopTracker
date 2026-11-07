# morrow

A private, local-only personal journal for iOS and Android, built with Flutter.

- Engineering rules and scope: [CLAUDE.md](CLAUDE.md)
- Implementation plan and milestones: [docs/implementation-plan.md](docs/implementation-plan.md)
- Designs: [Figma](https://www.figma.com/design/k5nqDgD29IrWJ3nuKYdOLS/poopTracker), organised by journey

## Toolchain

| Tool | Version |
|---|---|
| Flutter | 3.47.9 (stable, framework revision c197ca5199) |
| Dart | 3.13.7 |
| Platforms | Android, iOS (deployment target 15.0) |
| JDK | OpenJDK 24.0.1 |
| Android SDK | Platform android-36, build-tools 36.0.0, platform-tools 37.0.1, command-line tools 23.0 |

The Android SDK path must not contain spaces (NDK tools fail), so it lives at `C:\Android\Sdk` (`flutter config --android-sdk`). Command-line tools 23.0 replace `sdkmanager` with `android sdk install <package>`, where package names use `/` (for example `platforms/android-36`).

`pubspec.lock` is committed. Do not upgrade packages across major versions without review.

## Checks

Run these before reporting any change as complete:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

`flutter test` doesn't exercise native security, biometrics, notifications or OS backup behaviour. Those need the physical-device checks listed in the plan.

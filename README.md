# flutter_application_1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local QA helpers

### Web smoke test

```bash
scripts/web_smoke_test.sh
```

This runs: `flutter pub get` -> `flutter analyze` -> `flutter test` -> `flutter build web --release`.

### Wireless ADB setup (Tailscale)

```bash
# First time: enable tcp mode while USB is connected
adb tcpip 5555

# Then connect via Tailscale IP
scripts/adb_wireless_setup.sh <tailscale-device-ip> 5555
```

After this, you can run mobile checks remotely with `adb devices -l`.

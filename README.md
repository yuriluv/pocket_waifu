# Pocket Waifu

Architecture and feature reference docs now live under `docs/`.

Start here:
- `docs/QUICK_CONTEXT.md`
- `docs/START_HERE.md`
- `docs/SYSTEM_ARCHITECTURE.md`
- `docs/EXTENSION_PLAYBOOK.md`

## Local QA Helpers

### Web smoke test

```bash
scripts/web_smoke_test.sh
```

### Wireless ADB setup (Tailscale)

```bash
adb tcpip 5555
scripts/adb_wireless_setup.sh <tailscale-device-ip> 5555
```

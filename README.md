# SpeedVPS

VPN client for Windows, built with Flutter and sing-box (VLESS + Reality).

## Features

- 4 live-switchable UI themes: Emerald, Black + Green, Mono Dark, Mono Light (sidebar theme picker, persisted in settings)
- Connect / Servers / Subscription / Settings screens with glassmorphism design
- VLESS+Reality config generator (`lib/vpn/config/config_generator.dart`)
- sing-box binary resolver and runtime validation (`lib/vpn/services/singbox_binary_service.dart`)
- Windows VPN runtime process manager (`lib/vpn/windows_vpn.dart`)
- Split tunneling app discovery (`Get-StartApps`)
- Server repository with CRUD/selection and latency probing
- Session logging and centralized error model
- Unit tests for config generation and Windows status parsing

## Project structure

```
lib/
  core/
    errors/
    logging/
    state/
  services/
  ui/
    screens/
    theme/
    widgets/
  vpn/
    config/
    lifecycle/
    models/
    services/
test/
assets/binaries/windows/
```

## Notes

- Windows only: `wintun.dll`, `sing-box.exe` and `libcronet.dll` live in `assets/binaries/windows/`.
- Build with `flutter build windows`.

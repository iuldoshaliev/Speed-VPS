# SpeedVPS

VPN-клиент для Windows, созданный на Flutter и sing-box (VLESS + Reality).

## Возможности

- 4 переключаемые на лету темы интерфейса: Emerald, Black + Green, Mono Dark, Mono Light (выбор темы на боковой панели, сохраняется в настройках)
- Экраны Connect / Servers / Subscription / Settings в дизайне glassmorphism
- Генератор конфигурации VLESS+Reality (`lib/vpn/config/config_generator.dart`)
- Поиск бинарника sing-box и проверка при запуске (`lib/vpn/services/singbox_binary_service.dart`)
- Менеджер процессов VPN-рантайма Windows (`lib/vpn/windows_vpn.dart`)
- Обнаружение приложений для раздельного туннелирования (`Get-StartApps`)
- Репозиторий серверов с CRUD/выбором и проверкой задержки
- Логирование сессий и централизованная модель ошибок
- Модульные тесты для генерации конфигурации и разбора статуса Windows

## Структура проекта

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

## Примечания

- Только для Windows: `wintun.dll`, `sing-box.exe` и `libcronet.dll` находятся в `assets/binaries/windows/`.
- Сборка: `flutter build windows`.

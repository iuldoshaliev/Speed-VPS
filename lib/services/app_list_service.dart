// lib/services/app_list_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class InstalledApp {
  const InstalledApp({
    required this.id,
    required this.displayName,
    required this.processName,
  });

  final String id;
  final String displayName;
  final String processName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'processName': processName,
  };

  factory InstalledApp.fromJson(Map<String, dynamic> json) => InstalledApp(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    processName: json['processName'] as String,
  );
}

class AppListService {
  static const String _selectedAppsKey = 'selected_apps';
  static const String _customAppsKey = 'custom_apps';
  static const String _cachedSystemAppsKey = 'cached_system_apps';

  List<InstalledApp>? _cache;

  /// Возвращает полный список приложений (системные + кастомные).
  Future<List<InstalledApp>> getInstalledApps({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    final customApps = await _loadCustomApps();

    if (Platform.isWindows) {
      // Пытаемся загрузить кэшированный список системных приложений,
      // если не требуется принудительное обновление.
      List<InstalledApp> systemApps;
      if (!forceRefresh) {
        systemApps = await _loadCachedSystemApps();
      } else {
        systemApps = [];
      }

      // Если кэша нет или был запрошен forceRefresh, выполняем полное сканирование.
      if (systemApps.isEmpty) {
        systemApps = await _getWindowsApps();
        await _saveCachedSystemApps(systemApps);
      }

      // Объединяем системные и кастомные приложения.
      final allApps = <InstalledApp>[];
      final seenIds = <String>{};
      for (final app in [...customApps, ...systemApps]) {
        if (!seenIds.contains(app.id)) {
          seenIds.add(app.id);
          allApps.add(app);
        }
      }

      allApps.sort((a, b) => a.displayName.compareTo(b.displayName));
      _cache = allApps;
      return _cache!;
    }

    _cache = <InstalledApp>[];
    return _cache!;
  }

  // ---------- Кэширование системных приложений ----------
  Future<List<InstalledApp>> _loadCachedSystemApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_cachedSystemAppsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((e) => InstalledApp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedSystemApps(List<InstalledApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(apps.map((a) => a.toJson()).toList());
    await prefs.setString(_cachedSystemAppsKey, jsonString);
  }

  // ---------- Получение системных приложений Windows ----------
  Future<List<InstalledApp>> _getWindowsApps() async {
    final apps = <InstalledApp>[];

    // 1. Быстрый запрос через Get-StartApps
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Get-StartApps | Select-Object Name,AppID | ConvertTo-Json -Compress',
    ], runInShell: true);

    if (result.exitCode == 0) {
      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        // Исправление: убираем final и присваиваем внутри try/catch
        List<dynamic> jsonList = <dynamic>[];
        try {
          jsonList = jsonDecode(output) as List<dynamic>;
        } catch (_) {
          final single = jsonDecode(output);
          jsonList = [single];
        }

        for (var item in jsonList) {
          final name = item['Name'] as String? ?? '';
          final appId = item['AppID'] as String? ?? '';
          if (name.isEmpty || appId.isEmpty) continue;

          String? exePath;
          if (appId.length >= 2 && appId[1] == ':') {
            exePath = appId;
          } else {
            continue; // пропускаем UWP/неточные пути
          }

          if (File(exePath).existsSync()) {
            final processName = exePath.split('\\').last;
            apps.add(
              InstalledApp(
                id: exePath,
                displayName: name,
                processName: processName,
              ),
            );
          }
        }
      }
    }

    // 2. Добавляем базовые системные утилиты
    final systemApps = [
      {'name': 'Notepad', 'path': r'C:\Windows\System32\notepad.exe'},
      {'name': 'Calculator', 'path': r'C:\Windows\System32\calc.exe'},
      {'name': 'Command Prompt', 'path': r'C:\Windows\System32\cmd.exe'},
      {
        'name': 'PowerShell',
        'path': r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
      },
    ];
    for (final sa in systemApps) {
      if (File(sa['path']!).existsSync()) {
        apps.add(
          InstalledApp(
            id: sa['path']!,
            displayName: sa['name']!,
            processName: sa['path']!.split('\\').last,
          ),
        );
      }
    }

    // Удаляем дубликаты по id
    final unique = <String, InstalledApp>{};
    for (final app in apps) {
      unique[app.id] = app;
    }
    return unique.values.toList();
  }

  // ---------- Управление кастомными приложениями ----------
  Future<void> addCustomApp(InstalledApp app) async {
    final current = await _loadCustomApps();
    if (current.any((a) => a.id == app.id)) return;
    current.add(app);
    await _saveCustomApps(current);
    _cache = null; // сбрасываем кэш
  }

  /// Удаляет кастомное приложение по id
  Future<void> removeCustomApp(String id) async {
    final current = await _loadCustomApps();
    current.removeWhere((a) => a.id == id);
    await _saveCustomApps(current);
    _cache = null;
  }

  Future<List<InstalledApp>> _loadCustomApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_customAppsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((e) => InstalledApp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCustomApps(List<InstalledApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(apps.map((a) => a.toJson()).toList());
    await prefs.setString(_customAppsKey, jsonString);
  }

  // ---------- Сохранение / загрузка выбранных приложений ----------
  Future<void> saveSelectedApps(Set<String> selectedAppIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedAppsKey, selectedAppIds.toList());
  }

  Future<Set<String>> loadSelectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_selectedAppsKey) ?? [];
    return list.toSet();
  }
}

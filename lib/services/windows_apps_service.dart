// lib/services/windows_apps_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowsAppInfo {
  final String appId;
  final String displayName;
  final String executablePath;
  final String processName;

  WindowsAppInfo({
    required this.appId,
    required this.displayName,
    required this.executablePath,
    required this.processName,
  });

  String get iconCacheKey => 'app_icon_${appId.hashCode}';
}

class WindowsAppsService {
  static const String _selectedAppsKey = 'selected_apps';

  /// Надёжный скрипт PowerShell для получения списка приложений.
  Future<List<WindowsAppInfo>> getInstalledApps() async {
    final script = r'''
$apps = @()

# 1. Пытаемся получить Win32 приложения из реестра
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $uninstallPaths) {
    Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.DisplayName -and $_.DisplayName -notmatch '^\{|Update|Driver|Package|Microsoft (Visual|\.NET|ASP)|Windows (SDK|Driver)') {
            $exe = $_.DisplayIcon
            if (-not $exe) { $exe = $_.InstallLocation }
            if ($exe -and ($exe -match '\.exe')) {
                $exePath = $exe -replace ',[0-9]+$',''
                if (Test-Path $exePath) {
                    $apps += [PSCustomObject]@{
                        AppId = $exePath
                        DisplayName = $_.DisplayName
                        ExecutablePath = $exePath
                    }
                }
            }
        }
    }
}

# 2. Если реестр не дал результатов, добавляем системные приложения вручную
if ($apps.Count -eq 0) {
    $systemApps = @(
        @{ Name='Notepad'; Path='C:\Windows\System32\notepad.exe' },
        @{ Name='Calculator'; Path='C:\Windows\System32\calc.exe' },
        @{ Name='Command Prompt'; Path='C:\Windows\System32\cmd.exe' },
        @{ Name='PowerShell'; Path='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' },
        @{ Name='Task Manager'; Path='C:\Windows\System32\Taskmgr.exe' }
    )
    foreach ($app in $systemApps) {
        if (Test-Path $app.Path) {
            $apps += [PSCustomObject]@{
                AppId = $app.Path
                DisplayName = $app.Name
                ExecutablePath = $app.Path
            }
        }
    }
}

# 3. Удаляем дубликаты и выводим JSON
$apps | Sort-Object DisplayName | Select-Object -Unique | ConvertTo-Json -Compress
''';

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ], runInShell: true);

      if (result.exitCode != 0) {
        throw Exception('PowerShell error: ${result.stderr}');
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(output);
      final apps = <WindowsAppInfo>[];

      for (var item in jsonList) {
        final exePath = item['ExecutablePath'] as String? ?? '';
        if (exePath.isEmpty) continue;

        final processName = exePath.split('\\').last;
        apps.add(
          WindowsAppInfo(
            appId: item['AppId'] as String,
            displayName: item['DisplayName'] as String,
            executablePath: exePath,
            processName: processName,
          ),
        );
      }

      return apps;
    } catch (e) {
      // Если совсем ничего не получилось, возвращаем пустой список
      print('Error getting installed apps: $e');
      return [];
    }
  }

  /// Временно отключаем извлечение иконок
  Future<String?> getAppIconBase64(String executablePath) async {
    return null;
  }

  Future<File?> getCachedIconFile(WindowsAppInfo app) async {
    try {
      final cacheKey = app.iconCacheKey;
      final fileInfo = await DefaultCacheManager().getFileFromCache(cacheKey);
      if (fileInfo != null) return fileInfo.file;

      final base64 = await getAppIconBase64(app.executablePath);
      if (base64 == null) return null;

      final bytes = base64Decode(base64);
      return await DefaultCacheManager().putFile(
        cacheKey,
        bytes,
        fileExtension: 'png',
      );
    } catch (e) {
      return null;
    }
  }

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

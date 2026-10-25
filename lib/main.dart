// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/logging/session_logger.dart';
import 'services/app_list_service.dart';
import 'services/config_storage.dart';
import 'services/server_repository.dart';
import 'services/theme_service.dart';
import 'config/app_config.dart';
import 'ui/app_controller.dart';
import 'ui/screens/connect_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/subscription_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final themeService = ThemeService(prefs);

  runApp(SpeedVpsApp(themeService: themeService));
}

class SpeedVpsApp extends StatefulWidget {
  const SpeedVpsApp({super.key, required this.themeService});

  final ThemeService themeService;

  @override
  State<SpeedVpsApp> createState() => _SpeedVpsAppState();
}

class _SpeedVpsAppState extends State<SpeedVpsApp> {
  late final AppController _controller;
  late final SessionLogger _logger;
  int _index = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _logger = SessionLogger();
    _controller = AppController(
      serverRepository: ServerRepository(logger: _logger),
      appListService: AppListService(),
      logger: _logger,
    );
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    final storage = ConfigStorage();
    final savedServers = await storage.loadServers();
    for (final server in savedServers) {
      _controller.serverRepository.upsert(server.toProfile());
    }
    if (_controller.servers.isNotEmpty && _controller.selectedServer == null) {
      _controller.selectServer(_controller.servers.first.id);
    }
    await _controller.initialize();

    // ── Initialize payment & server APIs ─────────────────────
    _controller.initYooKassa(AppConfig.yookassaShopId, AppConfig.yookassaSecretKey);
    _controller.initX3UI(AppConfig.serverBaseUrl, AppConfig.serverApiToken);

    setState(() => _initialized = true);
    _controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'SpeedVPS',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.dark(),
          darkTheme: AppThemes.dark(),
          themeMode: ThemeMode.dark,
          home: _initialized
              ? AnimatedBuilder(
                  animation: AppColors.listenable,
                  builder: (context, _) {
                    return AdaptiveScaffold(
                      selectedIndex: _index,
                      onNavigationChanged: (value) =>
                          setState(() => _index = value),
                      themeService: widget.themeService,
                      navigationItems: const [
                        AdaptiveNavigationItem(
                          iconSymbol: '◈',
                          label: 'Панель управления',
                        ),
                        AdaptiveNavigationItem(
                          iconSymbol: '◎',
                          label: 'Серверы',
                        ),
                        AdaptiveNavigationItem(
                          iconSymbol: '◉',
                          label: 'Подписка',
                        ),
                        AdaptiveNavigationItem(
                          iconSymbol: '◆',
                          label: 'Настройки',
                        ),
                      ],
                      bodyBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return ConnectScreen(controller: _controller);
                          case 1:
                            return ServersScreen(controller: _controller);
                          case 2:
                            return SubscriptionScreen(controller: _controller);
                          case 3:
                            return SettingsScreen(controller: _controller);
                          default:
                            return ConnectScreen(controller: _controller);
                        }
                      },
                    );
                  },
                )
              : Scaffold(
                  backgroundColor: AppColors.bg,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.emerald,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// lib/ui/screens/settings_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/logging/session_logger.dart';
import '../../services/app_list_service.dart';
import '../../vpn/models/server_models.dart';
import '../app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _overrideDomainController =
      TextEditingController();
  String _searchQuery = '';

  bool _autoStart = false;
  bool _autoConnect = false;
  String _selectedProtocol = 'VLESS';
  bool _killSwitch = false;
  final TextEditingController _dnsController = TextEditingController();

  final List<String> _protocols = const [
    'VLESS',
    'VMess',
    'Trojan',
    'Shadowsocks',
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _domainController.dispose();
    _overrideDomainController.dispose();
    _dnsController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    if (!widget.controller.splitTunnelingSupported) return;
    setState(() => _loading = true);
    await widget.controller.refreshInstalledApps();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _addCustomApp() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        title: Text(
          'Добавить приложение',
          style: TextStyle(color: AppColors.text),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: Platform.isWindows
                ? r'C:\Path\To\app.exe'
                : '/Applications/App.app',
            hintStyle: TextStyle(color: AppColors.textDark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppColors.textDim),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await widget.controller.addCustomApp(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgPanel,
          content: Text(
            'Приложение добавлено',
            style: TextStyle(color: AppColors.text),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgPanel,
          content: Text(
            'Ошибка: $e',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
    }
  }

  Future<void> _addDomain() async {
    final rawInput = _domainController.text.trim();
    final domain = _normalizeDomain(rawInput);
    if (domain.isEmpty) return;
    if (!_isValidDomain(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgPanel,
          content: Text(
            'Введите корректный домен',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
      return;
    }
    widget.controller.addExcludedDomain(domain);
    _domainController.clear();

    print('[DEBUG] Added excluded domain: $domain');
    print('[DEBUG] All excluded: ${widget.controller.excludedDomains}');
  }

  bool _isValidDomain(String domain) {
    if (domain.isEmpty) return false;
    // Проверяем wildcard
    if (domain.startsWith('*.')) {
      final suffix = domain.substring(2);
      return suffix.isNotEmpty && suffix.contains('.');
    }
    return domain.contains('.');
  }

  String _normalizeDomain(String input) {
    var domain = input.trim().toLowerCase();

    // Убираем http:// и https://
    if (domain.startsWith('https://')) {
      domain = domain.substring(8);
    } else if (domain.startsWith('http://')) {
      domain = domain.substring(7);
    }

    // Убираем www.
    if (domain.startsWith('www.')) {
      domain = domain.substring(4);
    }

    // Убираем путь после /
    domain = domain.split('/').first;

    // Убираем порт если есть (:8080)
    domain = domain.split(':').first;

    return domain;
  }

  void _showDebugLogs(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _DebugLogsDialog(logger: widget.controller.logger),
    );
  }

  List<InstalledApp> get _filteredApps {
    final apps = widget.controller.installedApps;
    if (_searchQuery.isEmpty) return apps;
    return apps.where((app) {
      return app.displayName.toLowerCase().contains(_searchQuery) ||
          app.id.toLowerCase().contains(_searchQuery) ||
          app.processName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final splitSupported = controller.splitTunnelingSupported;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTitle('Настройки'),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.bug_report,
                      color: AppColors.textDim,
                    ),
                    onPressed: () => _showDebugLogs(context),
                    tooltip: 'Отладка',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // General
              _buildSectionTitle('Общие'),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    _buildToggle(
                      'Автозапуск',
                      'Запускать при старте Windows',
                      _autoStart,
                      (v) => setState(() => _autoStart = v),
                    ),
                    _buildToggle(
                      'Автоподключение',
                      'Подключаться автоматически при запуске',
                      _autoConnect,
                      (v) => setState(() => _autoConnect = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // VPN
              _buildSectionTitle('VPN'),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Протокол',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSelect(),
                    const SizedBox(height: 16),
                    _buildToggle(
                      'Kill Switch',
                      'Блокировать интернет при разрыве VPN',
                      _killSwitch,
                      (v) => setState(() => _killSwitch = v),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Пользовательский DNS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDnsInput(),
                    const SizedBox(height: 8),
                    Text(
                      'Например: 1.1.1.1, 8.8.8.8',
                      style: TextStyle(fontSize: 12, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Split Tunneling
              if (splitSupported) ...[
                _buildSectionTitle('Split Tunneling'),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<SplitTunnelMode>(
                        segments: const [
                          ButtonSegment(
                            value: SplitTunnelMode.disabled,
                            label: Text('Выкл'),
                            icon: Icon(Icons.block),
                          ),
                          ButtonSegment(
                            value: SplitTunnelMode.excludeSelectedApps,
                            label: Text('Исключить'),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                          ButtonSegment(
                            value: SplitTunnelMode.includeOnlySelectedApps,
                            label: Text('Только'),
                            icon: Icon(Icons.check_circle_outline),
                          ),
                        ],
                        selected: {controller.splitMode},
                        onSelectionChanged: (modes) =>
                            controller.setSplitMode(modes.first),
                        style: SegmentedButton.styleFrom(
                          backgroundColor: AppColors.inputFill,
                          selectedBackgroundColor: AppColors.emerald.withOpacity(
                            0.2,
                          ),
                          selectedForegroundColor: AppColors.emerald,
                          foregroundColor: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              type: MaterialType.transparency,
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: AppColors.text),
                                decoration: InputDecoration(
                                  hintText: 'Поиск приложений...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textDark,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: AppColors.textDark,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: AppColors.textDim,
                            ),
                            onPressed: _loadApps,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addCustomApp,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить приложение'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 300,
                        child: _loading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.emerald,
                                ),
                              )
                            : _AppsList(
                                controller: controller,
                                apps: _filteredApps,
                                splitMode: controller.splitMode,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Domains
                _buildSectionTitle('Исключённые домены'),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              type: MaterialType.transparency,
                              child: TextField(
                                controller: _domainController,
                                style: TextStyle(color: AppColors.text),
                                decoration: InputDecoration(
                                  hintText: 'example.com или *.ru',
                                  hintStyle: TextStyle(
                                    color: AppColors.textDark,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                ),
                                onSubmitted: (_) => _addDomain(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addDomain,
                            child: const Text('Добавить'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller.excludedDomains.map((domain) {
                          return Material(
                            // ← ДОБАВИТЬ
                            type: MaterialType.transparency,
                            child: Chip(
                              label: Text(
                                domain,
                                style: TextStyle(
                                  color: AppColors.emerald,
                                ),
                              ),
                              deleteIcon: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.emerald,
                              ),
                              onDeleted: () =>
                                  controller.removeExcludedDomain(domain),
                              backgroundColor: AppColors.emerald.withOpacity(
                                0.1,
                              ),
                              side: BorderSide(color: AppColors.emerald),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Advanced Routes
                _buildSectionTitle('Продвинутые маршруты'),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              type: MaterialType.transparency,
                              child: TextField(
                                controller: _overrideDomainController,
                                style: TextStyle(color: AppColors.text),
                                decoration: InputDecoration(
                                  hintText: '*.google.com',
                                  hintStyle: TextStyle(
                                    color: AppColors.textDark,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: Material(
                              type: MaterialType.transparency,
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                ),
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 13,
                                ),
                                dropdownColor: AppColors.bgPanel,
                                items: controller.availableServers.map((s) {
                                  return DropdownMenuItem(
                                    value: s.id,
                                    child: Text(
                                      s.name,
                                      style: TextStyle(
                                        color: AppColors.text,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {},
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: controller.canAddDomainOverride
                                ? () => _addDomainOverride(controller)
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...controller.domainOverrides.map((override) {
                        return _DomainOverrideRow(
                          domainOverride: override,
                          servers: controller.availableServers,
                          onUpdate: (serverId) =>
                              controller.updateDomainOverride(
                                override.domain,
                                outboundServerId: serverId,
                              ),
                          onDelete: () =>
                              controller.removeDomainOverride(override.domain),
                          onToggle: (enabled) =>
                              controller.updateDomainOverride(
                                override.domain,
                                enabled: enabled,
                              ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: AppColors.warning,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Split tunneling доступен только на Windows',
                        style: TextStyle(color: AppColors.textDim),
                      ),
                    ],
                  ),
                ),
              ],

              // About
              _buildSectionTitle('О приложении'),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(
                        Icons.rocket_launch,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SpeedVPS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Версия 1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String text) {
    // page-title: linear-gradient(180deg, text, accent-dim)
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.text, AppColors.emeraldDim],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.emerald,
        shadows: [
          Shadow(
            color: AppColors.emerald.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: value
                    ? LinearGradient(
                        colors: [AppColors.emerald, AppColors.emeraldDim],
                      )
                    : null,
                color: value ? null : AppColors.inputFill,
                border: Border.all(
                  color: value
                      ? AppColors.emerald.withOpacity(0.4)
                      : AppColors.borderSubtle,
                ),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelect() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.glassFillLight2,
                AppColors.emerald.withOpacity(0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.emerald.withOpacity(0.15),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProtocol,
                isDense: true,
                isExpanded: true,
                dropdownColor: AppColors.bgPanel,
                style: TextStyle(color: AppColors.text, fontSize: 14),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textDim,
                ),
                onChanged: (v) => setState(() => _selectedProtocol = v!),
                items: _protocols
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDnsInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.glassFillLight2,
                AppColors.emerald.withOpacity(0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.emerald.withOpacity(0.15),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: _dnsController,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                color: AppColors.text,
              ),
              decoration: InputDecoration(
                hintText: '1.1.1.1, 8.8.8.8',
                hintStyle: TextStyle(color: AppColors.textDark),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addDomainOverride(AppController controller) async {
    final domain = _overrideDomainController.text.trim();
    if (domain.isEmpty) return;
    if (!_isValidDomain(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgPanel,
          content: Text(
            'Введите корректный домен',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
      return;
    }
    final conflict = controller.checkDomainConflict(domain);
    if (conflict != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgPanel,
          content: Text(
            conflict,
            style: TextStyle(color: AppColors.warning),
          ),
        ),
      );
    }
    final servers = controller.availableServers;
    if (servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgPanel,
          content: Text(
            'Нет доступных серверов',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
      return;
    }
    final error = controller.addDomainOverride(domain, servers.first.id);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgPanel,
          content: Text(
            error,
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
    } else {
      _overrideDomainController.clear();
    }
  }
}

class _DomainOverrideRow extends StatelessWidget {
  const _DomainOverrideRow({
    required this.domainOverride,
    required this.servers,
    required this.onUpdate,
    required this.onDelete,
    required this.onToggle,
  });

  final DomainOverride domainOverride;
  final List<ServerProfile> servers;
  final void Function(String) onUpdate;
  final VoidCallback onDelete;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  domainOverride.isWildcard
                      ? Icons.star_outline
                      : Icons.language,
                  size: 16,
                  color: domainOverride.isWildcard
                      ? AppColors.warning
                      : AppColors.emerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    domainOverride.domain,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      decoration: domainOverride.enabled
                          ? null
                          : TextDecoration.lineThrough,
                      color: domainOverride.enabled
                          ? AppColors.text
                          : AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Material(
              type: MaterialType.transparency,
              child: DropdownButton<String>(
                value: domainOverride.outboundServerId,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppColors.bgPanel,
                style: TextStyle(color: AppColors.text),
                items: servers.map((server) {
                  return DropdownMenuItem(
                    value: server.id,
                    child: Text(
                      server.name,
                      style: TextStyle(
                        color: domainOverride.enabled
                            ? AppColors.text
                            : AppColors.textDark,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) onUpdate(value);
                },
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Switch(
                  value: domainOverride.enabled,
                  onChanged: onToggle,
                  activeColor: AppColors.emerald,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.error,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppsList extends StatelessWidget {
  const _AppsList({
    required this.controller,
    required this.apps,
    required this.splitMode,
  });

  final AppController controller;
  final List<InstalledApp> apps;
  final SplitTunnelMode splitMode;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Center(
        child: Text(
          'Приложения не найдены',
          style: TextStyle(color: AppColors.textDark),
        ),
      );
    }
    if (splitMode == SplitTunnelMode.disabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 48, color: AppColors.textDark),
            SizedBox(height: 16),
            Text(
              'Split tunneling отключён',
              style: TextStyle(color: AppColors.textDark),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = controller.selectedApps.contains(app.id);
        final isCustom = app.id.endsWith('.exe');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  app.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text),
                ),
                subtitle: Text(
                  app.processName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textDim),
                ),
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (value) =>
                      controller.toggleAppSelection(app.id, value ?? false),
                  activeColor: AppColors.emerald,
                ),
                trailing: isCustom
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        onPressed: () {
                          controller.removeCustomApp(app.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.bgPanel,
                              content: Text(
                                '${app.displayName} удалено',
                                style: TextStyle(color: AppColors.text),
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DebugLogsDialog extends StatefulWidget {
  const _DebugLogsDialog({required this.logger});

  final SessionLogger logger;

  @override
  State<_DebugLogsDialog> createState() => _DebugLogsDialogState();
}

class _DebugLogsDialogState extends State<_DebugLogsDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.logger.entries.reversed.toList();
    return AlertDialog(
      backgroundColor: AppColors.bgPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      title: Row(
        children: [
          Icon(Icons.bug_report, size: 24, color: AppColors.emerald),
          const SizedBox(width: 8),
          Text('Отладка', style: TextStyle(color: AppColors.text)),
          const Spacer(),
          Text(
            '${logs.length} записей',
            style: TextStyle(color: AppColors.textDark, fontSize: 12),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: logs.isEmpty
            ? Center(
                child: Text(
                  'Нет записей',
                  style: TextStyle(color: AppColors.textDark),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final color = switch (log.level) {
                    'ERROR' => AppColors.error,
                    'WARN' => AppColors.warning,
                    'DEBUG' => AppColors.textDark,
                    _ => AppColors.textDim,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      log.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Закрыть',
            style: TextStyle(color: AppColors.textDim),
          ),
        ),
      ],
    );
  }
}

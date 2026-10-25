// lib/ui/screens/servers_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/server_config.dart';
import '../../vpn/models/server_models.dart';
import '../add_server_page.dart';
import '../app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServerProfile> get _filteredServers {
    final servers = widget.controller.servers;
    if (_searchQuery.isEmpty) return servers;
    return servers.where((s) {
      return s.name.toLowerCase().contains(_searchQuery) ||
          s.host.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _importFromLink(BuildContext context) async {
    final linkController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        title: Text(
          'Импорт VLESS ссылки',
          style: TextStyle(color: AppColors.text),
        ),
        content: TextField(
          controller: linkController,
          style: TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'vless://...',
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
            onPressed: () => Navigator.pop(ctx, linkController.text.trim()),
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final config = ServerConfig.fromVlessUri(result);
      final profile = config.toProfile();
      widget.controller.serverRepository.upsert(profile);
      if (widget.controller.servers.length == 1) {
        widget.controller.selectServer(profile.id);
      }
      await widget.controller.saveServersToStorage();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bgPanel,
            content: Text(
              'Сервер "${config.name}" добавлен',
              style: TextStyle(color: AppColors.text),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bgPanel,
            content: Text(
              'Неверная VLESS ссылка: $e',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ServerProfile server,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        title: Text(
          'Удалить сервер',
          style: TextStyle(color: AppColors.text),
        ),
        content: Text(
          'Удалить "${server.name}"?',
          style: TextStyle(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppColors.textDim),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.controller.serverRepository.remove(server.id);
      await widget.controller.saveServersToStorage();
      if (widget.controller.selectedServer?.id == server.id) {
        if (widget.controller.servers.isNotEmpty) {
          widget.controller.selectServer(widget.controller.servers.first.id);
        }
      }
    }
  }

  String _getFlag(String host) {
    final h = host.toLowerCase();
    if (h.contains('ru')) return '🇷🇺';
    if (h.contains('de')) return '🇩🇪';
    if (h.contains('us')) return '🇺🇸';
    if (h.contains('uk') || h.contains('gb')) return '🇬🇧';
    if (h.contains('fr')) return '🇫🇷';
    if (h.contains('nl')) return '🇳🇱';
    if (h.contains('jp')) return '🇯🇵';
    if (h.contains('sg')) return '🇸🇬';
    if (h.contains('ca')) return '🇨🇦';
    return '🌐';
  }

  String _getCity(String host) {
    final h = host.toLowerCase();
    if (h.contains('ru')) return 'Россия';
    if (h.contains('de')) return 'Германия';
    if (h.contains('us')) return 'США';
    if (h.contains('uk') || h.contains('gb')) return 'Великобритания';
    if (h.contains('fr')) return 'Франция';
    if (h.contains('nl')) return 'Нидерланды';
    if (h.contains('jp')) return 'Япония';
    if (h.contains('sg')) return 'Сингапур';
    if (h.contains('ca')) return 'Канада';
    return 'Международный';
  }

  @override
  Widget build(BuildContext context) {
    final servers = _filteredServers;
    final selectedId = widget.controller.selectedServer?.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import_link',
            backgroundColor: AppColors.emerald,
            foregroundColor: AppColors.bg,
            onPressed: () => _importFromLink(context),
            child: const Icon(Icons.link),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_server',
            backgroundColor: AppColors.emerald,
            foregroundColor: AppColors.bg,
            onPressed: () async {
              final newConfig = await Navigator.push<ServerConfig>(
                context,
                MaterialPageRoute(builder: (_) => const AddServerPage()),
              );
              if (newConfig != null) {
                final profile = newConfig.toProfile();
                widget.controller.serverRepository.upsert(profile);
                if (widget.controller.servers.isEmpty) {
                  widget.controller.selectServer(profile.id);
                }
                await widget.controller.saveServersToStorage();
              }
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isWide ? 2 : 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitle('Серверы'),
                        const SizedBox(height: 24),
                        _buildSearch(),
                        const SizedBox(height: 24),
                        ...servers.map((s) => _buildServerItem(s, selectedId)),
                        if (servers.isEmpty)
                          Center(
                            child: Text(
                              'Нет серверов',
                              style: TextStyle(color: AppColors.textDark),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isWide && selectedId != null) ...[
                  VerticalDivider(width: 1, color: AppColors.glassBorder),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: _ServerDetails(
                      server: widget.controller.selectedServer!,
                      onDelete: () => _confirmDelete(
                        context,
                        widget.controller.selectedServer!,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
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

  Widget _buildSearch() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 600,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.glassFillLight2,
                AppColors.glassFillAccent,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: AppColors.textDark),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Поиск серверов...',
                      hintStyle: TextStyle(color: AppColors.textDark),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerItem(ServerProfile s, String? selectedId) {
    final isSelected = s.id == selectedId;
    final isHighLoad = (s.id.hashCode.abs() % 100) > 60;
    final ping = s.latencyMs ?? 0;
    final load = s.id.hashCode.abs() % 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        onTap: () => widget.controller.selectServer(s.id),
        child: Row(
          children: [
            Text(_getFlag(s.host), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getCity(s.host),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '${ping} ms',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                    color: ping < 100 ? AppColors.emerald : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Пинг',
                  style: TextStyle(fontSize: 11, color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                Text(
                  '$load%',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                    color: isHighLoad ? AppColors.warning : AppColors.emerald,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Нагрузка',
                  style: TextStyle(fontSize: 11, color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(width: 24),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Активен',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bg,
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: () => widget.controller.selectServer(s.id),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.emerald),
                  foregroundColor: AppColors.emerald,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Подключить',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServerDetails extends StatelessWidget {
  const _ServerDetails({required this.server, required this.onDelete});

  final ServerProfile server;
  final VoidCallback onDelete;

  String _getFlag(String host) {
    final h = host.toLowerCase();
    if (h.contains('ru')) return '🇷🇺';
    if (h.contains('de')) return '🇩🇪';
    if (h.contains('us')) return '🇺🇸';
    if (h.contains('uk') || h.contains('gb')) return '🇬🇧';
    if (h.contains('fr')) return '🇫🇷';
    if (h.contains('nl')) return '🇳🇱';
    if (h.contains('jp')) return '🇯🇵';
    if (h.contains('sg')) return '🇸🇬';
    return '🌐';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Center(
                    child: Text(
                      _getFlag(server.host),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        '${server.host}:${server.port}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: AppColors.glassBorder),
            _buildInfoRow('UUID', server.uuid, isSensitive: true),
            _buildInfoRow('Reality SNI', server.reality.serverName),
            _buildInfoRow(
              'Public Key',
              server.reality.publicKey,
              isSensitive: true,
            ),
            if (server.latencyMs != null)
              _buildInfoRow('Пинг', '${server.latencyMs} ms'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить сервер'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSensitive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.textDim),
            ),
          ),
          Expanded(
            child: Text(
              isSensitive ? _maskValue(value) : value,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.text,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskValue(String value) {
    if (value.length <= 8) return '••••••••';
    return '${value.substring(0, 4)}••••${value.substring(value.length - 4)}';
  }
}

// lib/ui/screens/connect_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../../vpn/vpn_status.dart';
import '../app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _updateTimer();
  }

  @override
  void didUpdateWidget(covariant ConnectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    _updateTimer();
  }

  void _updateTimer() {
    final isConnected = widget.controller.vpnStatus.state == VpnState.connected;
    if (isConnected && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } else if (!isConnected) {
      _timer?.cancel();
      _timer = null;
      if (mounted) setState(() => _seconds = 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  String get _timerText {
    final h = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _statusLabel {
    switch (widget.controller.vpnStatus.state) {
      case VpnState.disconnected:
        return 'Отключен';
      case VpnState.connecting:
        return 'Подключение...';
      case VpnState.connected:
        return 'Подключено';
      case VpnState.disconnecting:
        return 'Отключение...';
      case VpnState.error:
        return 'Ошибка';
    }
  }

  Color _getStatusColor(VpnState state) {
    switch (state) {
      case VpnState.disconnected:
        return AppColors.error;
      case VpnState.connecting:
      case VpnState.disconnecting:
        return AppColors.warning;
      case VpnState.connected:
        return AppColors.emerald;
      case VpnState.error:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.vpnStatus;
    final isBusy =
        status.state == VpnState.connecting ||
        status.state == VpnState.disconnecting;
    final isConnected = status.state == VpnState.connected;
    final statusColor = _getStatusColor(status.state);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('Панель управления'),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 12,
                        child: GlassCard(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatus(isConnected, statusColor),
                              const SizedBox(height: 32),
                              _buildPlayButton(isConnected, isBusy),
                              const SizedBox(height: 32),
                              _buildTimer(),
                              const SizedBox(height: 32),
                              _buildServerSelect(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 8,
                        child: Column(
                          children: [
                            _buildQuickConnect(isConnected, isBusy),
                            const SizedBox(height: 20),
                            _buildPlanCard(),
                            const SizedBox(height: 20),
                            _buildStatsCard(status),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatus(isConnected, statusColor),
                          const SizedBox(height: 24),
                          _buildPlayButton(isConnected, isBusy),
                          const SizedBox(height: 24),
                          _buildTimer(),
                          const SizedBox(height: 24),
                          _buildServerSelect(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildQuickConnect(isConnected, isBusy),
                    const SizedBox(height: 20),
                    _buildPlanCard(),
                    const SizedBox(height: 20),
                    _buildStatsCard(status),
                  ],
                );
              },
            ),
          ],
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

  Widget _buildStatus(bool isConnected, Color statusColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [
              BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _statusLabel,
          style: TextStyle(fontSize: 16, color: AppColors.textDim),
        ),
      ],
    );
  }

  Widget _buildPlayButton(bool isConnected, bool isBusy) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isBusy
          ? () {}
          : () {
              if (isConnected) {
                widget.controller.disconnect();
              } else {
                widget.controller.connect();
              }
            },
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.emerald, AppColors.emeraldDim],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.1),
              blurRadius: 80,
              spreadRadius: 20,
            ),
          ],
        ),
        child: Center(
          child: isConnected
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                )
              : CustomPaint(
                  size: const Size(40, 48),
                  painter: _PlayIconPainter(),
                ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return Text(
      _timerText,
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 42,
        fontWeight: FontWeight.w300,
        color: AppColors.text,
        letterSpacing: 4,
        shadows: [
          Shadow(
            color: AppColors.emerald.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildServerSelect() {
    final server = widget.controller.selectedServer;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.language,
                size: 18,
                color: AppColors.textDim.withOpacity(0.6),
              ),
              const SizedBox(width: 10),
              Text(
                server?.name ?? 'Не выбран',
                style: TextStyle(fontSize: 14, color: AppColors.textDim),
              ),
            ],
          ),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.textDim.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickConnect(bool isConnected, bool isBusy) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Быстрое подключение',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy || isConnected
                  ? null
                  : () => widget.controller.connect(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Подключиться',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    final info = widget.controller.subscriptionInfo;
    final hasPlan = info.isActive;
    final days = info.daysRemaining;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Текущий план',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.15),
                  border: Border.all(
                    color: AppColors.emerald.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasPlan ? info.plan.toUpperCase() : 'FREE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasPlan ? '$days дней осталось' : 'Без подписки',
                style: TextStyle(fontSize: 13, color: AppColors.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(VpnStatus status) {
    final traffic = status.state == VpnState.connected ? '2.5 GB' : '-';
    final uptime = status.state == VpnState.connected ? '99.9%' : '-';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStat(traffic, 'Трафик'),
              const SizedBox(width: 32),
              _buildStat(uptime, 'Аптайм'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 24,
            color: AppColors.emerald,
            shadows: [
              Shadow(
                color: AppColors.emerald.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _PlayIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.bg
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

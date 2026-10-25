// lib/ui/screens/subscription_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../models/subscription_models.dart';
import '../app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  final TextEditingController _promoController = TextEditingController();
  String? _promoMessage;
  bool _promoSuccess = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _checkPending();
  }

  @override
  void didUpdateWidget(covariant SubscriptionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _checkPending() async {
    if (widget.controller.pendingPayment != null) {
      setState(() => _isLoading = true);
      await widget.controller.checkPendingPayment();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pay(SubscriptionPlan plan) async {
    setState(() => _isLoading = true);

    if (widget.controller.pendingPayment == null) {
      widget.controller.initYooKassa(
        AppConfig.yookassaShopId,
        AppConfig.yookassaSecretKey,
      );
    }

    final result = await widget.controller.createSubscriptionPayment(
      plan,
      returnUrl: AppConfig.yookassaReturnUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result != null && result.confirmationUrl.isNotEmpty) {
        final uri = Uri.parse(result.confirmationUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (widget.controller.pendingPayment != null) {
        final uri = Uri.parse(
          widget.controller.pendingPayment!.confirmationUrl,
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  void _activatePromo() {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    if (code.toUpperCase() == 'EMERALD') {
      setState(() {
        _promoSuccess = true;
        _promoMessage = 'Промокод активирован! +7 дней добавлено.';
      });
    } else {
      setState(() {
        _promoSuccess = false;
        _promoMessage = 'Неверный промокод';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.controller.subscriptionInfo;
    final pending = widget.controller.pendingPayment;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('Подписка'),
            const SizedBox(height: 32),
            _buildCurrentPlan(info, pending),
            const SizedBox(height: 32),
            _buildPlans(pending),
            const SizedBox(height: 32),
            _buildPromocode(),
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

  Widget _buildCurrentPlan(SubscriptionInfo info, PendingPayment? pending) {
    final hasPlan = info.isActive;
    final days = info.daysRemaining;

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Текущий план',
                  style: TextStyle(fontSize: 14, color: AppColors.textDim),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (hasPlan) ...[
                  Text(
                    'Действителен до ${_formatDate(info.expireDate!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Осталось $days дней',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildClearButton(),
                  if (info.vpnLink != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.emerald.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VPN ключ:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            info.vpnLink!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    'Нет активной подписки',
                    style: TextStyle(fontSize: 14, color: AppColors.textDim),
                  ),
                ],
                if (pending != null) ...[
                  const SizedBox(height: 16),
                  Divider(color: AppColors.glassBorder),
                  Row(
                    children: [
                      Icon(
                        Icons.hourglass_top,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ожидается оплата: ${pending.amount.toStringAsFixed(0)} ₽',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkPending,
                        child: Text(
                          'Проверить',
                          style: TextStyle(color: AppColors.emerald),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Text('💎', style: TextStyle(fontSize: 48)),
        ],
      ),
    );
  }

  Widget _buildPlans(PendingPayment? pending) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final children = AppController.plans.map((plan) {
          return Expanded(
            child: GlassCard(
              child: Column(
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₽',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                        ),
                      ),
                      Text(
                        plan.priceRub.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${plan.days} дней',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || pending != null
                          ? null
                          : () => _pay(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: AppColors.bg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.bg,
                              ),
                            )
                          : Text(
                              pending != null ? 'Ожидание оплаты' : 'Оплатить',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                children[i],
              ],
            ],
          );
        }
        return Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        );
      },
    );
  }

  Widget _buildPromocode() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Промокод',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGlassInput(
                  controller: _promoController,
                  hint: 'Введите промокод',
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _activatePromo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Активировать'),
              ),
            ],
          ),
          if (_promoMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _promoMessage!,
              style: TextStyle(
                fontSize: 12,
                color: _promoSuccess ? AppColors.emerald : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String hint,
  }) {
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
                AppColors.glassFillAccent,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.glassBorder,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: controller,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
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

  Widget _buildClearButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.bgPanel,
              title: Text(
                'Сбросить подписку?',
                style: TextStyle(color: AppColors.text),
              ),
              content: Text(
                'Все данные подписки и VPN-ключи будут удалены. Продолжить?',
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'Сбросить',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            setState(() => _isLoading = true);
            await widget.controller.clearSubscription();
            if (mounted) setState(() => _isLoading = false);
          }
        },
        icon: Icon(
          Icons.delete_forever,
          color: AppColors.error,
          size: 18,
        ),
        label: Text(
          'Сбросить подписку',
          style: TextStyle(color: AppColors.error),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppColors.error, width: 0.5),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

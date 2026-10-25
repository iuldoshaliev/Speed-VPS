import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/session_logger.dart';
import '../models/server_config.dart';
import '../models/subscription_models.dart';
import '../config/app_config.dart';
import '../services/app_list_service.dart';
import '../services/config_storage.dart';
import '../services/server_repository.dart';
import '../services/subscription_service.dart';
import '../services/yookassa_service.dart';
import '../services/x3_ui_api.dart';
import '../vpn/models/server_models.dart';
import '../vpn/vpn_status.dart';
import '../core/state/vpn_state.dart';
import '../core/state/vpn_cubit.dart';
import '../core/state/server_state.dart';
import '../core/state/split_tunnel_state.dart';
export '../core/state/vpn_state.dart';
export '../core/state/server_state.dart';
export '../core/state/split_tunnel_state.dart';

/// AppController serves as the coordinator between UI and cubit classes.
class AppController extends ChangeNotifier {
  AppController({
    required ServerRepository serverRepository,
    required AppListService appListService,
    required SessionLogger logger,
  }) : _serverRepository = serverRepository,
       _appListService = appListService,
       _logger = logger,
       _vpnCubit = VpnCubit(logger: logger),
       _splitTunnelingSupported = Platform.isWindows {
    _vpnCubit.initialize();
    _vpnCubit.addListener(_onVpnCubitChanged);
  }

  final ServerRepository _serverRepository;
  final AppListService _appListService;
  final SessionLogger _logger;
  final VpnCubit _vpnCubit;
  final ConfigStorage _storage = ConfigStorage();

  late final bool _splitTunnelingSupported;

  // ---------- YooKassa & Subscription ----------
  YooKassaService? _yookassaService;
  X3UIApi? _x3uiApi;
  SubscriptionInfo _subscriptionInfo = SubscriptionInfo();
  PendingPayment? _pendingPayment;
  StreamSubscription<PaymentStatus>? _paymentPollSubscription;

  static const String _subscriptionKey = 'subscription_info';
  static const String _pendingPaymentKey = 'pending_payment';

  /// Тарифные планы (соответствуют config.py из референсного проекта)
  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: 'day_trial',
      name: 'Пробный',
      days: 1,
      priceRub: 10.0,
      description: '1 день для теста',
    ),
    SubscriptionPlan(
      id: 'month',
      name: 'Premium',
      days: 30,
      priceRub: 200.0,
      description: '30 дней безлимитного доступа',
    ),
  ];

  SubscriptionInfo get subscriptionInfo => _subscriptionInfo;
  PendingPayment? get pendingPayment => _pendingPayment;

  void initYooKassa(String shopId, String secretKey) {
    _yookassaService = YooKassaService(shopId, secretKey);
  }

  void initX3UI(String baseUrl, String apiToken) {
    _x3uiApi = X3UIApi(baseUrl, apiToken);
  }

  /// Создаёт платёж через YooKassa и возвращает URL для оплаты
  Future<YooKassaPaymentResult?> createSubscriptionPayment(
    SubscriptionPlan plan, {
    String returnUrl = 'https://t.me/',
    String? userId,
  }) async {
    final service = _yookassaService;
    if (service == null) {
      _logger.error('YooKassa not initialized');
      return null;
    }

    // Не даём создать новый платёж, пока есть pending
    if (_pendingPayment != null) {
      _logger.warning(
        'Pending payment already exists: ${_pendingPayment!.paymentId}',
      );
      return null;
    }

    final result = await service.createPayment(
      plan.priceRub,
      'Подписка ${plan.name} — ${plan.days} дней',
      returnUrl,
      metadata: {
        'user_id': userId ?? 'unknown',
        'plan_id': plan.id,
        'duration_days': plan.days.toString(),
      },
    );

    if (result != null) {
      _pendingPayment = PendingPayment(
        paymentId: result.paymentId,
        amount: result.amount,
        days: plan.days,
        confirmationUrl: result.confirmationUrl,
      );
      await _savePendingPayment();
      _startPaymentPolling(result.paymentId, plan.days);
      notifyListeners();
    }

    return result;
  }

  /// Загружает серверы из URL подписки и обновляет репозиторий
  Future<void> loadServersFromSubscription() async {
    final url = _subscriptionInfo.vpnLink;
    if (url == null || url.isEmpty) {
      _logger.info('No subscription URL to load servers from');
      return;
    }

    try {
      final service = SubscriptionService();
      final configs = await service.fetchSubscription(url);
      _logger.info('Loaded ${configs.length} servers from subscription');

      for (final config in configs) {
        final profile = config.toProfile();
        _serverRepository.upsert(profile);
      }

      // Выбираем первый сервер если ничего не выбрано
      if (_serverRepository.selectedServerId == null &&
          _serverRepository.servers.isNotEmpty) {
        _serverRepository.select(_serverRepository.servers.first.id);
      }

      await saveServersToStorage();
      _serverState = ServerLoaded(
        servers: _serverRepository.servers,
        selectedServer: _serverRepository.selectedServer,
      );
      notifyListeners();
    } catch (e, st) {
      _logger.error('Failed to load servers from subscription: $e\n$st');
    }
  }

  /// Полный сброс подписки — удаляет данные из хранилища, останавливает VPN
  Future<void> clearSubscription() async {
    // Отменяем polling если есть
    _paymentPollSubscription?.cancel();
    _paymentPollSubscription = null;

    // Останавливаем VPN если подключён
    final state = vpnState;
    if (state is VpnConnectedState || state is VpnConnecting) {
      await disconnect();
    }

    // Очищаем подписку
    _subscriptionInfo = SubscriptionInfo();
    await _saveSubscription();

    // Очищаем pending платёж
    _pendingPayment = null;
    await _savePendingPayment();

    _logger.info('Subscription cleared by user');
    notifyListeners();
  }

  /// Запускает polling статуса платежа
  void _startPaymentPolling(String paymentId, int days) {
    _paymentPollSubscription?.cancel();
    final service = _yookassaService;
    if (service == null) return;

    _paymentPollSubscription = service.pollPaymentStatus(paymentId).listen((
      status,
    ) async {
      _pendingPayment?.status = status.name;
      notifyListeners();

      if (status == PaymentStatus.succeeded) {
        _handlePaymentSucceeded(days);
        _pendingPayment = null;
        await _savePendingPayment();
        notifyListeners();
      } else if (status == PaymentStatus.canceled ||
          status == PaymentStatus.failed) {
        _pendingPayment = null;
        await _savePendingPayment();
        notifyListeners();
      }
    });
  }

  void _handlePaymentSucceeded(int days) async {
    final now = DateTime.now();
    final currentExpire = _subscriptionInfo.expireDate;
    final baseDate = (currentExpire != null && currentExpire.isAfter(now))
        ? currentExpire
        : now;
    final newExpire = baseDate.add(Duration(days: days));
    _subscriptionInfo.expireDate = newExpire;
    _subscriptionInfo.plan = 'premium';
    _subscriptionInfo.updatedAt = now;

    // ── Create or extend client in 3X-UI ─────────────────────
    final api = _x3uiApi;
    if (api != null) {
      try {
        final expireMs = newExpire.millisecondsSinceEpoch;
        final existingEmail = _subscriptionInfo.marzbanUsername;
        var clientExists = false;

        // Проверяем, существует ли клиент
        if (existingEmail != null && existingEmail.isNotEmpty) {
          final client = await api.getClient(existingEmail);
          clientExists = client != null;
        }

        if (clientExists) {
          // Client exists — extend expiry
          final updated = await api.updateClient(
            email: existingEmail!,
            expiryTimeMs: expireMs,
            enable: true,
          );
          if (updated) {
            _logger.info('3X-UI client $existingEmail extended to $newExpire');
          } else {
            _logger.warning('Failed to extend 3X-UI client $existingEmail');
          }
        } else {
          // New client — create in 3X-UI
          final email = 'emerald_${_randomId(8)}@client.local';
          final subId = _randomId(16);
          final created = await api.addClient(
            email: email,
            inboundIds: AppConfig.defaultInboundIds,
            totalGB: 0, // unlimited
            expiryTimeMs: expireMs,
            subId: subId,
            enable: true,
            comment: 'SpeedVPS auto-created',
          );

          if (created) {
            // Получаем реальный subId с сервера
            final newClient = await api.getClient(email);
            final realSubId = newClient?.subId ?? subId;

            _subscriptionInfo.marzbanUsername = email;
            _subscriptionInfo.vpnLink = _x3uiApi!.getSubscriptionUrl(realSubId);
            _logger.info('3X-UI client created: $email (subId: $realSubId)');
          } else {
            _logger.error('Failed to create 3X-UI client');
          }
        }

        // Загружаем серверы из подписки
        await loadServersFromSubscription();
      } catch (e) {
        _logger.error('3X-UI error during payment handling: $e');
      }
    } else {
      _logger.warning('X3UIApi not initialized — client NOT created on server');
    }

    await _saveSubscription();
    _logger.info('Subscription extended by $days days');
  }

  String _randomId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(chars[(DateTime.now().microsecond + i) % chars.length]);
    }
    return sb.toString();
  }

  /// Проверить статус платежа вручную
  Future<PaymentStatus?> checkPendingPayment() async {
    final pending = _pendingPayment;
    final service = _yookassaService;
    if (pending == null || service == null) return null;

    final status = await service.getPaymentStatus(pending.paymentId);
    pending.status = status.name;

    if (status == PaymentStatus.succeeded) {
      _handlePaymentSucceeded(pending.days);
      _pendingPayment = null;
      await _savePendingPayment();
    } else if (status == PaymentStatus.canceled ||
        status == PaymentStatus.failed) {
      _pendingPayment = null;
      await _savePendingPayment();
    }

    notifyListeners();
    return status;
  }

  Future<void> _loadSubscriptionState() async {
    final prefs = await SharedPreferences.getInstance();
    final subJson = prefs.getString(_subscriptionKey);
    if (subJson != null) {
      try {
        _subscriptionInfo = SubscriptionInfo.fromJson(
          jsonDecode(subJson) as Map<String, dynamic>,
        );
      } catch (e) {
        _logger.error('Failed to load subscription: $e');
      }
    }

    final pendingJson = prefs.getString(_pendingPaymentKey);
    if (pendingJson != null) {
      try {
        _pendingPayment = PendingPayment.fromJson(
          jsonDecode(pendingJson) as Map<String, dynamic>,
        );
        // Если есть pending платёж, возобновляем polling
        if (_pendingPayment != null && _yookassaService != null) {
          _startPaymentPolling(
            _pendingPayment!.paymentId,
            _pendingPayment!.days,
          );
        }

        // Если есть активная подписка — загружаем серверы
        if (_subscriptionInfo.isActive && _subscriptionInfo.vpnLink != null) {
          await loadServersFromSubscription();
        }
      } catch (e) {
        _logger.error('Failed to load pending payment: $e');
      }
    }
  }

  Future<void> _saveSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _subscriptionKey,
      jsonEncode(_subscriptionInfo.toJson()),
    );
  }

  Future<void> _savePendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _pendingPayment;
    if (pending != null) {
      await prefs.setString(_pendingPaymentKey, jsonEncode(pending.toJson()));
    } else {
      await prefs.remove(_pendingPaymentKey);
    }
  }

  // ---------- Public accessors ----------
  ServerRepository get serverRepository => _serverRepository;
  SessionLogger get logger => _logger;
  AppListService get appListService => _appListService;

  // ---------- VPN State delegation ----------
  VpnCubitState get vpnState => _vpnCubit.state;
  VpnStatus get vpnStatus => _vpnCubit.currentStatus;
  String? get lastErrorMessage => _vpnCubit.lastErrorMessage;

  // ---------- Server State ----------
  ServerState _serverState = const ServerInitial();
  ServerState get serverState => _serverState;

  List<ServerProfile> get servers => _serverRepository.servers;
  ServerProfile? get selectedServer => _serverRepository.selectedServer;

  ServerProfile? get albaniaProxy {
    final allServers = servers;
    if (allServers.length > 1) {
      return allServers[1];
    }
    return null;
  }

  static const List<String> geminiDomains = [
    'aistudio.google.com',
    'makersuite.google.com',
    'generativelanguage.googleapis.com',
    'api.googleusercontent.com',
    'chat.google.com',
    'bard.google.com',
    'gemini.google.com',
  ];

  // ---------- Split Tunneling State ----------
  SplitTunnelState _splitTunnelState = const SplitTunnelLoaded(
    mode: SplitTunnelMode.disabled,
    selectedApps: {},
    excludedDomains: [],
    domainOverrides: [],
  );
  SplitTunnelState get splitTunnelState => _splitTunnelState;

  SplitTunnelMode get splitMode {
    final state = _splitTunnelState;
    if (state is SplitTunnelLoaded) return state.mode;
    return SplitTunnelMode.disabled;
  }

  Set<String> get selectedApps {
    final state = _splitTunnelState;
    if (state is SplitTunnelLoaded) return state.selectedApps;
    return {};
  }

  List<String> get excludedDomains {
    final state = _splitTunnelState;
    if (state is SplitTunnelLoaded) return state.excludedDomains;
    return [];
  }

  List<DomainOverride> get domainOverrides {
    final state = _splitTunnelState;
    if (state is SplitTunnelLoaded) return state.domainOverrides;
    return [];
  }

  int get domainOverrideCount {
    final state = _splitTunnelState;
    if (state is SplitTunnelLoaded) return state.domainOverrideCount;
    return 0;
  }

  bool get canAddDomainOverride => domainOverrideCount < 50;

  List<ServerProfile> get availableServers => servers;

  bool get splitTunnelingSupported => _splitTunnelingSupported;

  // ---------- App List State ----------
  List<InstalledApp> _installedApps = [];
  List<InstalledApp> get installedApps => _installedApps;

  // ---------- Storage Keys ----------
  static const String _excludedDomainsKey = 'excluded_domains';
  static const String _domainOverridesKey = 'domain_overrides';
  static const int _domainOverrideDebounceMs = 500;
  Timer? _domainOverrideDebounceTimer;

  // ---------- Initialization ----------
  Future<void> initialize() async {
    // Инициализируем YooKassa и 3X-UI API
    initYooKassa(AppConfig.yookassaShopId, AppConfig.yookassaSecretKey);
    initX3UI(AppConfig.serverBaseUrl, AppConfig.serverApiToken);

    await _loadServerState();
    await _loadSplitTunnelState();
    await _loadInstalledApps();
    await _loadSubscriptionState();
  }

  Future<void> _loadServerState() async {
    _serverState = ServerLoaded(
      servers: _serverRepository.servers,
      selectedServer: _serverRepository.selectedServer,
    );
    notifyListeners();
  }

  Future<void> _loadSplitTunnelState() async {
    final prefs = await SharedPreferences.getInstance();
    final excludedList = prefs.getStringList(_excludedDomainsKey) ?? [];

    final jsonList = prefs.getStringList(_domainOverridesKey) ?? [];
    final domainOverrideList = <DomainOverride>[];
    for (final jsonStr in jsonList) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        domainOverrideList.add(DomainOverride.fromJson(json));
      } catch (e) {
        logger.error('Failed to parse domain override: $e');
      }
    }

    final selectedApps = await appListService.loadSelectedApps();

    final hasAlbaniaProxy = servers.length > 1;
    if (hasAlbaniaProxy && domainOverrideList.isEmpty) {
      final albaniaServerId = servers[1].id;
      for (final domain in geminiDomains) {
        if (!domainOverrideList.any((d) => d.domain == domain)) {
          domainOverrideList.add(
            DomainOverride(
              domain: domain,
              outboundServerId: albaniaServerId,
              enabled: true,
            ),
          );
        }
      }
    }

    _splitTunnelState = SplitTunnelLoaded(
      mode: _splitTunnelState is SplitTunnelLoaded
          ? (_splitTunnelState as SplitTunnelLoaded).mode
          : SplitTunnelMode.disabled,
      selectedApps: selectedApps,
      excludedDomains: excludedList,
      domainOverrides: domainOverrideList,
    );
    notifyListeners();
  }

  Future<void> _loadInstalledApps() async {
    if (!_splitTunnelingSupported) return;
    _updateSplitTunnelState(isLoadingApps: true);
    _installedApps = await appListService.getInstalledApps(forceRefresh: true);
    _updateSplitTunnelState(isLoadingApps: false);
    notifyListeners();
  }

  Future<void> refreshInstalledApps() async {
    _installedApps = await appListService.getInstalledApps(forceRefresh: true);
    notifyListeners();
  }

  void _onVpnCubitChanged() {
    notifyListeners();
  }

  // ---------- VPN Actions ----------
  Future<void> connect() async {
    final server = selectedServer;
    if (server == null) {
      logger.error('No server selected');
      notifyListeners();
      return;
    }

    final mode = splitMode;
    print('[DEBUG] Connecting with excludedDomains: $excludedDomains');
    print('[DEBUG] excludedDomains count: ${excludedDomains.length}');
    if (mode != SplitTunnelMode.disabled && selectedApps.isEmpty) {
      logger.error('Split tunneling enabled but no apps selected');
      notifyListeners();
      return;
    }

    final processNames = _installedApps
        .where(
          (app) => selectedApps.contains(app.id) && app.processName.isNotEmpty,
        )
        .map((app) => app.processName)
        .toList();

    await _vpnCubit.connect(
      server: server,
      splitTunnel: SplitTunnelSettings(
        mode: mode,
        appIdentifiers: processNames,
        excludedDomains: excludedDomains,
        domainOverrides: domainOverrides,
      ),
      albaniaProxy: albaniaProxy,
    );
  }

  Future<void> disconnect() async {
    await _vpnCubit.disconnect();
  }

  void selectServer(String id) {
    _serverRepository.select(id);
    _serverState = ServerLoaded(
      servers: _serverRepository.servers,
      selectedServer: _serverRepository.selectedServer,
    );
    notifyListeners();
  }

  Future<void> probeLatencies() async {
    await _serverRepository.refreshAllLatencies();
    _serverState = ServerLoaded(
      servers: _serverRepository.servers,
      selectedServer: _serverRepository.selectedServer,
      isRefreshing: true,
    );
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    _serverState = ServerLoaded(
      servers: _serverRepository.servers,
      selectedServer: _serverRepository.selectedServer,
    );
    notifyListeners();
  }

  // ---------- Split Tunneling Actions ----------
  void setSplitMode(SplitTunnelMode mode) {
    if (!_splitTunnelingSupported && mode != SplitTunnelMode.disabled) return;
    _updateSplitTunnelState(mode: mode);
  }

  void toggleAppSelection(String appId, bool selected) {
    final currentApps = Set<String>.from(selectedApps);
    if (selected) {
      currentApps.add(appId);
    } else {
      currentApps.remove(appId);
    }
    appListService.saveSelectedApps(currentApps);
    _updateSplitTunnelState(selectedApps: currentApps);
  }

  Future<void> addCustomApp(String exePath) async {
    final file = File(exePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $exePath');
    }
    final processName = exePath.split(Platform.pathSeparator).last;
    final newApp = InstalledApp(
      id: exePath,
      displayName: processName.replaceAll('.exe', ''),
      processName: processName,
    );
    await appListService.addCustomApp(newApp);
    await refreshInstalledApps();
    toggleAppSelection(newApp.id, true);
  }

  Future<void> removeCustomApp(String appId) async {
    await appListService.removeCustomApp(appId);
    if (selectedApps.contains(appId)) {
      toggleAppSelection(appId, false);
    }
    await refreshInstalledApps();
  }

  // ---------- Excluded Domains ----------
  void addExcludedDomain(String domain) {
    if (domain.isEmpty || excludedDomains.contains(domain)) return;
    final newList = List<String>.from(excludedDomains)..add(domain);
    _updateSplitTunnelState(excludedDomains: newList);
    _saveExcludedDomains(newList);
  }

  void removeExcludedDomain(String domain) {
    final newList = List<String>.from(excludedDomains)..remove(domain);
    _updateSplitTunnelState(excludedDomains: newList);
    _saveExcludedDomains(newList);
  }

  Future<void> _saveExcludedDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_excludedDomainsKey, domains);
  }

  // ---------- Domain Overrides ----------
  String? addDomainOverride(String domain, String outboundServerId) {
    if (!canAddDomainOverride) {
      return 'Maximum limit of 50 rules reached';
    }
    if (!isValidDomain(domain)) {
      return 'Invalid domain format';
    }
    if (domainOverrides.any((d) => d.domain == domain)) {
      return 'Domain "$domain" already exists';
    }

    final newList = List<DomainOverride>.from(domainOverrides)
      ..add(DomainOverride(domain: domain, outboundServerId: outboundServerId));
    _updateSplitTunnelState(domainOverrides: newList);
    _saveDomainOverridesDebounced(newList);
    return null;
  }

  void removeDomainOverride(String domain) {
    final newList = List<DomainOverride>.from(domainOverrides)
      ..removeWhere((d) => d.domain == domain);
    _updateSplitTunnelState(domainOverrides: newList);
    _saveDomainOverridesDebounced(newList);
  }

  void updateDomainOverride(
    String domain, {
    String? outboundServerId,
    bool? enabled,
  }) {
    final index = domainOverrides.indexWhere((d) => d.domain == domain);
    if (index == -1) return;

    final newList = List<DomainOverride>.from(domainOverrides);
    newList[index] = newList[index].copyWith(
      outboundServerId: outboundServerId,
      enabled: enabled,
    );
    _updateSplitTunnelState(domainOverrides: newList);
    _saveDomainOverridesDebounced(newList);
  }

  void clearAllDomainOverrides() {
    _updateSplitTunnelState(domainOverrides: []);
    _saveDomainOverridesDebounced([]);
  }

  String? checkDomainConflict(String domain) {
    if (excludedDomains.contains(domain)) {
      return 'Domain "$domain" is already in excluded domains list';
    }
    for (final excluded in excludedDomains) {
      if (excluded.startsWith('*.') && domain.endsWith(excluded.substring(1))) {
        return 'Domain "$domain" conflicts with wildcard rule "$excluded"';
      }
    }
    return null;
  }

  void _saveDomainOverridesDebounced(List<DomainOverride> overrides) {
    _domainOverrideDebounceTimer?.cancel();
    _domainOverrideDebounceTimer = Timer(
      const Duration(milliseconds: _domainOverrideDebounceMs),
      () async {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = overrides.map((d) => jsonEncode(d.toJson())).toList();
        await prefs.setStringList(_domainOverridesKey, jsonList);
      },
    );
  }

  // ---------- Storage ----------
  Future<void> saveServersToStorage() async {
    final configs = _serverRepository.servers
        .map(
          (p) => ServerConfig(
            name: p.name,
            address: p.host,
            port: p.port,
            uuid: p.uuid,
            serverName: p.reality.serverName,
            publicKey: p.reality.publicKey,
            shortId: p.reality.shortId,
            fingerprint: p.reality.fingerprint,
            flow: p.flow,
          ),
        )
        .toList();
    await _storage.saveServers(configs);
  }

  // ---------- Helper methods ----------
  void _updateSplitTunnelState({
    SplitTunnelMode? mode,
    Set<String>? selectedApps,
    List<String>? excludedDomains,
    List<DomainOverride>? domainOverrides,
    bool? isLoadingApps,
  }) {
    if (_splitTunnelState is SplitTunnelLoaded) {
      final current = _splitTunnelState as SplitTunnelLoaded;
      _splitTunnelState = current.copyWith(
        mode: mode,
        selectedApps: selectedApps,
        excludedDomains: excludedDomains,
        domainOverrides: domainOverrides,
        isLoadingApps: isLoadingApps,
      );
      notifyListeners();
    } else {
      _splitTunnelState = SplitTunnelLoaded(
        mode: mode ?? SplitTunnelMode.disabled,
        selectedApps: selectedApps ?? {},
        excludedDomains: excludedDomains ?? [],
        domainOverrides: domainOverrides ?? [],
        isLoadingApps: isLoadingApps ?? false,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _domainOverrideDebounceTimer?.cancel();
    _paymentPollSubscription?.cancel();
    _vpnCubit.removeListener(_onVpnCubitChanged);
    _vpnCubit.dispose();
    _yookassaService?.dispose();
    super.dispose();
  }
}

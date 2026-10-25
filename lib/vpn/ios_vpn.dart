import 'dart:async';
import 'package:flutter/services.dart';
import '../core/errors/vpn_error.dart';
import '../core/logging/session_logger.dart';
import 'models/server_models.dart';
import 'vpn_interface.dart';
import 'vpn_status.dart';

/// iOS VPN implementation using NetworkExtension via MethodChannel
/// Note: iOS has limited split tunneling support
/// - App-based filtering is NOT available via public APIs (requires MDM)
/// - Domain-based bypass (excludedRoutes) is supported
/// - On-Demand rules can filter by domain
class IosVpn implements VpnInterface {
  IosVpn({SessionLogger? logger}) : _logger = logger;

  final SessionLogger? _logger;
  static const _channel = MethodChannel('vps_emerald/vpn/ios');
  static const _eventChannel = EventChannel('vps_emerald/vpn/ios_events');

  VpnStatus _status = const VpnStatus(state: VpnState.disconnected);
  final _statusController = StreamController<VpnStatus>.broadcast();
  StreamSubscription? _eventSubscription;

  @override
  void initialize() {
    // iOS VPN doesn't require explicit initialization
    _logger?.info('iOS VPN initialized');
  }

  @override
  Future<void> connect({
    required ServerProfile server,
    required SplitTunnelSettings splitTunnel,
    ServerProfile? albaniaProxy,
  }) async {
    try {
      _status = const VpnStatus(state: VpnState.connecting);
      _statusController.add(_status);

      // iOS supports domain-based bypass via excludedRoutes
      // App-based split tunneling is NOT available on iOS (no public API without MDM)
      final hasAppFiltering =
          splitTunnel.mode != SplitTunnelMode.disabled &&
          splitTunnel.appIdentifiers.isNotEmpty;

      if (hasAppFiltering) {
        _logger?.warning(
          'App filtering not available on iOS, using domain bypass only',
        );
        _status = const VpnStatus(
          state: VpnState.connecting,
          message:
              'Note: App filtering not available on iOS, using domain bypass only',
        );
        _statusController.add(_status);
      }

      // Subscribe to VPN status events
      _eventSubscription ??= _eventChannel.receiveBroadcastStream().listen(
        _handleStatusEvent,
        onError: _handleStatusError,
      );

      // Generate config using SingBoxConfigGenerator would go here
      // For now, we use the MethodChannel to communicate with native VPNManager
      // The actual config generation should happen in Dart and be passed to native

      // TODO: Generate sing-box config and pass to native
      // For integration test, we'll just configure the tunnel
      throw VpnError(
        VpnErrorKind.platformUnsupported,
        'iOS VPN requires config generation before connecting. '
        'Use SingBoxConfigGenerator and pass config to configureTunnel.',
      );
    } catch (e) {
      if (e is VpnError) rethrow;
      _status = VpnStatus(state: VpnState.error, message: e.toString());
      _statusController.add(_status);
      throw VpnError(VpnErrorKind.processStart, e.toString());
    }
  }

  /// Connect with pre-generated config JSON
  Future<void> connectWithConfig({
    required String configJson,
    required SplitTunnelSettings splitTunnel,
  }) async {
    try {
      _status = const VpnStatus(state: VpnState.connecting);
      _statusController.add(_status);

      // Subscribe to VPN status events
      _eventSubscription ??= _eventChannel.receiveBroadcastStream().listen(
        _handleStatusEvent,
        onError: _handleStatusError,
      );

      // Configure tunnel with native VPNManager
      final configureResult = await _channel.invokeMethod('configureTunnel', {
        'config': configJson,
        'excludedDomains': splitTunnel.excludedDomains,
      });

      if (configureResult != true) {
        throw VpnError(VpnErrorKind.config, 'Failed to configure tunnel');
      }

      // Start the VPN connection
      final connectResult = await _channel.invokeMethod('connect');
      if (connectResult != true) {
        throw VpnError(VpnErrorKind.processStart, 'Failed to start VPN');
      }

      _logger?.info('iOS VPN connection started');
    } on PlatformException catch (e) {
      _status = VpnStatus(
        state: VpnState.error,
        message: e.message ?? 'Unknown error',
      );
      _statusController.add(_status);
      throw VpnError(
        VpnErrorKind.processStart,
        e.message ?? 'Connection failed',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      _status = const VpnStatus(state: VpnState.disconnected);
      _statusController.add(_status);
    } on PlatformException catch (e) {
      throw VpnError(
        VpnErrorKind.processStart,
        e.message ?? 'Disconnect failed',
      );
    }
  }

  @override
  Future<void> forceDisconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      _status = const VpnStatus(state: VpnState.disconnected);
      _statusController.add(_status);
    } on PlatformException {
      // Ignore errors
    }
  }

  @override
  Future<void> pauseConnection() async {
    // iOS doesn't support true pause - disconnect instead
    await disconnect();
  }

  @override
  Future<void> reconnect() async {
    // iOS reconnect via NEVPNManager - not implemented in stub
  }

  @override
  VpnStatus getStatus() => _status;

  @override
  Stream<VpnStatus> statusStream() {
    return _statusController.stream;
  }

  void _handleStatusEvent(dynamic event) {
    if (event is Map) {
      final statusStr = event['status'] as String? ?? 'disconnected';
      final message = event['message'] as String? ?? '';

      final state = _parseVpnState(statusStr);
      _status = VpnStatus(state: state, message: message);
      _statusController.add(_status);

      _logger?.debug('iOS VPN status: $statusStr - $message');
    }
  }

  void _handleStatusError(dynamic error) {
    _logger?.error('iOS VPN status error: $error');
    _status = VpnStatus(state: VpnState.error, message: error.toString());
    _statusController.add(_status);
  }

  VpnState _parseVpnState(String status) {
    switch (status) {
      case 'connected':
        return VpnState.connected;
      case 'connecting':
        return VpnState.connecting;
      case 'disconnecting':
        return VpnState.disconnecting;
      case 'disconnected':
        return VpnState.disconnected;
      default:
        return VpnState.error;
    }
  }

  /// Returns the excluded domains that will be used for bypass
  /// iOS supports this via NEVPNConnection.excludedRoutes
  static List<String> getSupportedExcludedDomains(
    SplitTunnelSettings splitTunnel,
  ) {
    return splitTunnel.excludedDomains;
  }

  Future<bool> isConfigured() async {
    try {
      final result = await _channel.invokeMethod<bool>('isConfigured');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeConfiguration() async {
    try {
      await _channel.invokeMethod('removeConfiguration');
    } catch (_) {
      // Ignore errors during removal
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _statusController.close();
  }
}

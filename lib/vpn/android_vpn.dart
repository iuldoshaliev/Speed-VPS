import 'dart:async';
import 'package:flutter/services.dart';
import '../core/errors/vpn_error.dart';
import 'models/server_models.dart';
import 'vpn_interface.dart';
import 'vpn_status.dart';

/// Android VPN implementation using VpnService
/// Requires native implementation via MethodChannel
class AndroidVpn implements VpnInterface {
  static const _channel = MethodChannel('vps_emerald/vpn/android');

  VpnStatus _status = const VpnStatus(state: VpnState.disconnected);
  final _statusController = StreamController<VpnStatus>.broadcast();

  @override
  void initialize() {
    // Android VPN doesn't require explicit initialization
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

      // Determine VPN mode based on split tunnel settings
      final vpnMode = _getVpnMode(splitTunnel);

      // Prepare app package list for split tunneling
      // On Android, we pass package names (app identifiers)
      final result = await _channel.invokeMethod('connect', {
        'host': server.host,
        'port': server.port,
        'uuid': server.uuid,
        'serverName': server.reality.serverName,
        'publicKey': server.reality.publicKey,
        'shortId': server.reality.shortId,
        'fingerprint': server.reality.fingerprint,
        'flow': server.flow,
        'mode': vpnMode,
        'excludedApps': splitTunnel.mode == SplitTunnelMode.excludeSelectedApps
            ? splitTunnel.appIdentifiers
            : <String>[],
        'includedApps':
            splitTunnel.mode == SplitTunnelMode.includeOnlySelectedApps
            ? splitTunnel.appIdentifiers
            : <String>[],
        'excludedDomains': splitTunnel.excludedDomains,
      });

      if (result == true) {
        _status = const VpnStatus(state: VpnState.connected);
      } else {
        _status = const VpnStatus(
          state: VpnState.error,
          message: 'Failed to start VPN',
        );
      }
      _statusController.add(_status);
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

  String _getVpnMode(SplitTunnelSettings splitTunnel) {
    if (splitTunnel.mode == SplitTunnelMode.disabled) {
      return 'all';
    }
    if (splitTunnel.mode == SplitTunnelMode.excludeSelectedApps) {
      return 'exclude';
    }
    return 'include';
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
      await _channel.invokeMethod('forceDisconnect');
      _status = const VpnStatus(state: VpnState.disconnected);
      _statusController.add(_status);
    } on PlatformException {
      // Ignore errors
    }
  }

  @override
  Future<void> pauseConnection() async {
    // Android doesn't support true pause, just disconnect
    await disconnect();
  }

  @override
  Future<void> reconnect() async {
    // Android reconnect via MethodChannel - need to store last config
    // For now, just trigger disconnect which signals need for reconnect
  }

  @override
  VpnStatus getStatus() => _status;

  @override
  Stream<VpnStatus> statusStream() {
    return _statusController.stream;
  }

  /// Request VPN permission - call this before connecting
  /// Returns true if permission granted
  static Future<bool> requestVpnPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if VPN permission is already granted
  static Future<bool> isPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPermissionGranted');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}

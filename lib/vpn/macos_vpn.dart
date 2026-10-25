import '../core/errors/vpn_error.dart';
import 'models/server_models.dart';
import 'vpn_interface.dart';
import 'vpn_status.dart';

class MacOsVpn implements VpnInterface {
  VpnStatus _status = const VpnStatus(state: VpnState.disconnected);

  @override
  void initialize() {
    // macOS VPN doesn't require explicit initialization
  }

  @override
  Future<void> connect({
    required ServerProfile server,
    required SplitTunnelSettings splitTunnel,
    ServerProfile? albaniaProxy,
  }) async {
    _status = const VpnStatus(
      state: VpnState.error,
      message: 'macOS implementation requires native entitlement setup',
    );
    throw VpnError(
      VpnErrorKind.platformUnsupported,
      'macOS VPN runtime is not yet wired in this bootstrap project',
    );
  }

  @override
  Future<void> disconnect() async {
    _status = const VpnStatus(state: VpnState.disconnected);
  }

  @override
  Future<void> forceDisconnect() async {
    _status = const VpnStatus(state: VpnState.disconnected);
  }

  @override
  Future<void> pauseConnection() async {
    // Not supported on macOS
  }

  @override
  Future<void> reconnect() async {
    // Not supported on macOS
  }

  @override
  VpnStatus getStatus() => _status;

  @override
  Stream<VpnStatus> statusStream() async* {
    yield _status;
  }
}

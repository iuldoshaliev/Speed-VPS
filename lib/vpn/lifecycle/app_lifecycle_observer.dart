// lib/vpn/lifecycle/app_lifecycle_observer.dart

import 'package:flutter/widgets.dart';

/// Strategy for VPN shutdown when app lifecycle changes
enum VpnShutdownStrategy {
  /// Disconnect immediately when app backgrounds
  immediate,

  /// Attempt graceful disconnect with timeout, force if needed
  gracefulWithTimeout,

  /// Preserve session state for reconnection when app resumes
  preserveSession,
}

/// Event args for kill switch status changes
class KillSwitchStatusChangedEventArgs {
  KillSwitchStatusChangedEventArgs({
    required this.isActive,
    required this.rules,
    this.error,
  });

  final bool isActive;
  final List<String> rules;
  final String? error;
}

/// Result of a kill switch operation
class KillSwitchResult {
  KillSwitchResult({
    required this.success,
    required this.enabledRules,
    this.errors,
  });

  final bool success;
  final List<String> enabledRules;
  final List<String>? errors;

  bool get hasErrors => errors != null && errors!.isNotEmpty;
}

/// Observer for app lifecycle changes to manage VPN connection lifecycle
class AppLifecycleObserver extends WidgetsBindingObserver {
  AppLifecycleObserver({
    required this.vpn,
    this.strategy = VpnShutdownStrategy.gracefulWithTimeout,
    this.shutdownTimeout = const Duration(seconds: 5),
    this.onShutdownInitiated,
    this.onShutdownCompleted,
    this.logger,
  });

  final VpnInterface vpn;
  final VpnShutdownStrategy strategy;
  final Duration shutdownTimeout;
  final void Function(String)? onShutdownInitiated;
  final void Function(String)? onShutdownCompleted;
  final void Function(String, dynamic)? logger;

  bool _wasConnectionInterrupted = false;
  bool _isShuttingDown = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _handleAppBackgrounding(state);
        break;
      case AppLifecycleState.resumed:
        _handleAppResumption();
        break;
    }
  }

  void _handleAppBackgrounding(AppLifecycleState state) {
    if (_isShuttingDown) return;
    _isShuttingDown = true;

    _log('info', 'App entering ${state.name} state');
    onShutdownInitiated?.call('App entering ${state.name} state');

    switch (strategy) {
      case VpnShutdownStrategy.immediate:
        _immediateShutdown();
        break;
      case VpnShutdownStrategy.gracefulWithTimeout:
        _gracefulShutdownWithTimeout();
        break;
      case VpnShutdownStrategy.preserveSession:
        _preserveSessionShutdown();
        break;
    }
  }

  void _handleAppResumption() {
    _isShuttingDown = false;

    if (_wasConnectionInterrupted) {
      _log('info', 'App resumed, attempting reconnection');
      _wasConnectionInterrupted = false;
      vpn.reconnect();
    }
  }

  Future<void> _immediateShutdown() async {
    try {
      _log('info', 'Executing immediate shutdown');
      await vpn.disconnect();
      onShutdownCompleted?.call('Immediate shutdown completed');
    } catch (e) {
      _logError('Immediate shutdown failed', e);
    } finally {
      _isShuttingDown = false;
    }
  }

  Future<void> _gracefulShutdownWithTimeout() async {
    try {
      _log(
        'info',
        'Executing graceful shutdown with ${shutdownTimeout.inSeconds}s timeout',
      );

      final disconnectFuture = vpn.disconnect();
      await disconnectFuture.timeout(
        shutdownTimeout,
        onTimeout: () {
          _log('warning', 'Graceful shutdown timed out, forcing disconnect');
          vpn.forceDisconnect();
        },
      );

      onShutdownCompleted?.call('Graceful shutdown completed within timeout');
    } catch (e) {
      _logError('Graceful shutdown failed', e);
    } finally {
      _isShuttingDown = false;
    }
  }

  Future<void> _preserveSessionShutdown() async {
    try {
      _log('info', 'Preserving session for reconnection');
      await vpn.pauseConnection();
      _wasConnectionInterrupted = true;
      onShutdownCompleted?.call('Session preserved for reconnection');
    } catch (e) {
      _logError('Session preservation failed, falling back to graceful', e);
      _gracefulShutdownWithTimeout();
    } finally {
      _isShuttingDown = false;
    }
  }

  void _log(String level, String message) {
    logger?.call(level, message);
    print('[AppLifecycleObserver][$level] $message');
  }

  void _logError(String message, Object error) {
    _log('error', '$message: $error');
  }
}

/// Interface for VPN operations that lifecycle observer controls
abstract class VpnInterface {
  /// Disconnect gracefully, allowing cleanup
  Future<void> disconnect();

  /// Force immediate disconnect without cleanup
  Future<void> forceDisconnect();

  /// Pause connection while preserving session state
  Future<void> pauseConnection();

  /// Reconnect with previous session or fresh connection
  Future<void> reconnect();

  /// Initialize VPN subsystem
  void initialize();
}

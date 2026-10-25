// lib/vpn/config/config_generator.dart
import 'dart:convert';
import 'dart:math';

import '../../core/errors/vpn_error.dart';
import '../models/server_models.dart';

class SingBoxConfigGenerator {
  String generateVlessRealityConfig({
    required ServerProfile server,
    required SplitTunnelSettings splitTunnel,
    int localSocksPort = 2080,
    int localMixedPort = 2081,
    ServerProfile? albaniaProxy,
  }) {
    _validate(server, localSocksPort, localMixedPort);

    final _RouteParts routeParts = _buildRouteParts(splitTunnel, albaniaProxy);

    final random = Random();
    final uniqueId = random.nextInt(10000);
    final thirdOctet = random.nextInt(254) + 1;
    final tunInterfaceName = 'vps-${uniqueId}';
    final tunAddress = '10.255.$thirdOctet.1/30';

    final Map<String, dynamic> vlessOutbound = {
      'type': 'vless',
      'tag': 'proxy',
      'server': server.host,
      'server_port': server.port,
      'uuid': server.uuid,
      'packet_encoding': 'xudp',
      'domain_resolver': 'remote',
      'tls': {
        'enabled': true,
        'server_name': server.reality.serverName,
        'utls': {'enabled': true, 'fingerprint': server.reality.fingerprint},
        'reality': {
          'enabled': true,
          'public_key': server.reality.publicKey,
          if (server.reality.shortId.isNotEmpty)
            'short_id': server.reality.shortId,
        },
      },
    };
    if (server.flow.isNotEmpty) {
      vlessOutbound['flow'] = server.flow;
    }

    // Outbounds: без отдельного dns-direct, только proxy и direct
    final outbounds = <Map<String, dynamic>>[
      vlessOutbound,
      {'type': 'direct', 'tag': 'direct'},
      {'type': 'block', 'tag': 'block'},
    ];

    if (albaniaProxy != null) {
      final albaniaOutbound = {
        'type': 'vless',
        'tag': 'albania-proxy',
        'domain_resolver': 'remote',
        'server': albaniaProxy.host,
        'server_port': albaniaProxy.port,
        'uuid': albaniaProxy.uuid,
        'packet_encoding': 'xudp',
        'tls': {
          'enabled': true,
          'server_name': albaniaProxy.reality.serverName,
          'utls': {
            'enabled': true,
            'fingerprint': albaniaProxy.reality.fingerprint,
          },
          'reality': {
            'enabled': true,
            'public_key': albaniaProxy.reality.publicKey,
            if (albaniaProxy.reality.shortId.isNotEmpty)
              'short_id': albaniaProxy.reality.shortId,
          },
        },
      };
      if (albaniaProxy.flow.isNotEmpty) {
        albaniaOutbound['flow'] = albaniaProxy.flow;
      }
      outbounds.insert(1, albaniaOutbound);
    }

    // DNS-серверы: только remote (через прокси) – надёжнее и без блокировок
    final dnsServers = [
      {
        'tag': 'remote',
        'type': 'tcp',
        'server': '1.1.1.1',
        'server_port': 53,
        'detour': 'proxy',
      },
    ];

    final dnsRules = <Map<String, dynamic>>[];

    // Исключённые домены → удалённый DNS (через прокси) для резолвинга,
    // но маршрутизация всё равно пойдёт в direct (см. routeRules)
    if (splitTunnel.excludedDomains.isNotEmpty) {
      final exactDomains = <String>[];
      final suffixKeywords = <String>[];
      for (var entry in splitTunnel.excludedDomains) {
        entry = entry.trim().toLowerCase();
        if (entry.startsWith('http://') || entry.startsWith('https://')) {
          entry = entry.replaceFirst(RegExp(r'^https?://'), '');
        }
        entry = entry.split('/').first;
        if (entry.startsWith('.')) {
          suffixKeywords.add(entry.substring(1));
        } else {
          exactDomains.add(entry);
          if (!entry.startsWith('www.')) {
            exactDomains.add('www.$entry');
          }
        }
      }
      if (exactDomains.isNotEmpty) {
        dnsRules.add({'domain': exactDomains, 'server': 'remote'});
      }
      if (suffixKeywords.isNotEmpty) {
        dnsRules.add({'domain_suffix': suffixKeywords, 'server': 'remote'});
      }
    }
    // Всё остальное тоже через remote
    dnsRules.add({'server': 'remote'});

    final routeRules = <Map<String, dynamic>>[
      {'action': 'sniff'},
      {'protocol': 'dns', 'action': 'hijack-dns'},
      ...routeParts.domainRules,
      ...routeParts.overrideRules,
      {
        'inbound': ['tun-in'],
        'action': 'route',
        'outbound': routeParts.finalOutbound,
      },
      {'ip_is_private': true, 'outbound': 'direct'},
    ];

    final config = {
      'log': {'level': 'info', 'timestamp': true},
      'dns': {
        'servers': dnsServers,
        'rules': dnsRules,
        'strategy': 'prefer_ipv4',
      },
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': localMixedPort,
        },
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': tunInterfaceName,
          'address': [tunAddress],
          'mtu': 1300,
          'stack': 'system',
          'auto_route': true,
          'strict_route': true,
        },
      ],
      'outbounds': outbounds,
      'route': {
        'auto_detect_interface': true,
        'default_domain_resolver': 'remote',
        'rules': routeRules,
        'final': routeParts.finalOutbound,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(config);
  }

  void _validate(ServerProfile server, int localSocksPort, int localMixedPort) {
    if (server.host.trim().isEmpty)
      throw VpnError(VpnErrorKind.config, 'Server host is required');
    if (server.uuid.trim().isEmpty)
      throw VpnError(VpnErrorKind.config, 'UUID is required');
    if (server.reality.publicKey.trim().isEmpty)
      throw VpnError(VpnErrorKind.config, 'Reality public key is required');
    if (server.reality.serverName.trim().isEmpty)
      throw VpnError(VpnErrorKind.config, 'Reality SNI/serverName is required');
    if (server.port <= 0 || server.port > 65535)
      throw VpnError(VpnErrorKind.config, 'Server port must be in 1..65535');
    if (localSocksPort <= 0 || localSocksPort > 65535)
      throw VpnError(VpnErrorKind.config, 'SOCKS port must be in 1..65535');
    if (localMixedPort <= 0 || localMixedPort > 65535)
      throw VpnError(VpnErrorKind.config, 'Mixed port must be in 1..65535');
  }

  _RouteParts _buildRouteParts(
    SplitTunnelSettings splitTunnel,
    ServerProfile? albaniaProxy,
  ) {
    final domainRules = <Map<String, dynamic>>[];
    final overrideRules = <Map<String, dynamic>>[];

    if (splitTunnel.excludedDomains.isNotEmpty) {
      final exactDomains = <String>[];
      final suffixKeywords = <String>[];
      for (var entry in splitTunnel.excludedDomains) {
        entry = entry.trim().toLowerCase();
        if (entry.startsWith('http://') || entry.startsWith('https://')) {
          entry = entry.replaceFirst(RegExp(r'^https?://'), '');
        }
        entry = entry.split('/').first;
        if (entry.startsWith('.')) {
          suffixKeywords.add(entry.substring(1));
        } else {
          exactDomains.add(entry);
          if (!entry.startsWith('www.')) {
            exactDomains.add('www.$entry');
          }
        }
      }
      if (exactDomains.isNotEmpty) {
        domainRules.add({'domain': exactDomains, 'outbound': 'direct'});
      }
      if (suffixKeywords.isNotEmpty) {
        domainRules.add({
          'domain_suffix': suffixKeywords,
          'outbound': 'direct',
        });
      }
    }

    if (splitTunnel.domainOverrides.isNotEmpty && albaniaProxy != null) {
      for (final override in splitTunnel.domainOverrides) {
        if (!override.enabled) continue;
        final domain = override.domain.trim().toLowerCase();
        if (domain.isEmpty) continue;
        if (domain.startsWith('*.')) {
          overrideRules.add({
            'domain_suffix': [domain.substring(2)],
            'outbound': 'albania-proxy',
          });
        } else {
          overrideRules.add({
            'domain': [domain],
            'outbound': 'albania-proxy',
          });
          if (!domain.startsWith('www.')) {
            overrideRules.add({
              'domain': ['www.$domain'],
              'outbound': 'albania-proxy',
            });
          }
        }
      }
    }

    String finalOutbound = 'proxy';
    if (splitTunnel.mode != SplitTunnelMode.disabled) {
      if (splitTunnel.appIdentifiers.isEmpty) {
        throw VpnError(
          VpnErrorKind.splitTunneling,
          'Split tunneling is enabled, but app list is empty',
        );
      }
      final outboundForSelected =
          splitTunnel.mode == SplitTunnelMode.excludeSelectedApps
          ? 'direct'
          : 'proxy';
      finalOutbound = splitTunnel.mode == SplitTunnelMode.excludeSelectedApps
          ? 'proxy'
          : 'direct';
      domainRules.add({
        'process_name': splitTunnel.appIdentifiers,
        'outbound': outboundForSelected,
      });
    }

    return _RouteParts(
      domainRules: domainRules,
      overrideRules: overrideRules,
      finalOutbound: finalOutbound,
    );
  }
}

class _RouteParts {
  _RouteParts({
    required this.domainRules,
    required this.overrideRules,
    required this.finalOutbound,
  });
  final List<Map<String, dynamic>> domainRules;
  final List<Map<String, dynamic>> overrideRules;
  final String finalOutbound;
}

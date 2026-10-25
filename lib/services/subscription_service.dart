import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/server_config.dart';

class SubscriptionService {
  /// Fetches a subscription URL and parses VLESS links from the base64 response.
  Future<List<ServerConfig>> fetchSubscription(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'SpeedVPS/1.0 (sing-box)'},
    );

    if (response.statusCode != 200) {
      throw Exception('Subscription fetch failed: HTTP ${response.statusCode}');
    }

    final body = response.body.trim();
    String decoded;
    try {
      // Marzban returns base64-encoded list of URIs separated by newlines
      decoded = utf8.decode(base64Decode(_padBase64(body)));
    } catch (_) {
      // Maybe it's already plain text
      decoded = body;
    }

    final lines = decoded
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    final servers = <ServerConfig>[];

    for (final line in lines) {
      if (line.startsWith('vless://')) {
        try {
          servers.add(ServerConfig.fromVlessUri(line));
        } catch (e) {
          // Skip unparseable lines, but log
          print('Failed to parse VLESS URI: $line, error: $e');
        }
      }
    }

    return servers;
  }

  String _padBase64(String input) {
    final remainder = input.length % 4;
    if (remainder == 0) return input;
    return input + '=' * (4 - remainder);
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MarzbanApi {
  final String _baseUrl;
  final String _username;
  final String _password;
  String? _token;
  final http.Client _client = http.Client();

  MarzbanApi(this._baseUrl, this._username, this._password);

  Future<String> _getToken() async {
    if (_token != null) return _token!;

    final uri = Uri.parse('$_baseUrl/api/admin/token');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': _username, 'password': _password},
    );

    if (response.statusCode != 200) {
      throw Exception('Auth failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    _token = data['access_token'] as String?;
    if (_token == null) throw Exception('No token in response');
    return _token!;
  }

  Future<String?> getSubscriptionUrl(String username) async {
    final token = await _getToken();
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/user/$username/links'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    return data['vless']?.first ??
        data['vmess']?.first ??
        data['trojan']?.first;
  }

  Future<List<UserInfo>?> getUsers() async {
    final token = await _getToken();
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/users'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => UserInfo.fromJson(e)).toList();
  }

  Future<bool> createUser(
    String username, {
    int dataLimitGB = 100,
    int expireDays = 30,
  }) async {
    final token = await _getToken();
    final expireAt =
        DateTime.now()
            .toUtc()
            .add(Duration(days: expireDays))
            .millisecondsSinceEpoch ~/
        1000;

    final body = jsonEncode({
      'username': username,
      'status': 'active',
      'data_limit': dataLimitGB * 1024 * 1024 * 1024,
      'expire': expireAt,
    });

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<String?> createVpnKey({int durationDays = 30}) async {
    try {
      final token = await _getToken();
      final expireAt =
          DateTime.now()
              .toUtc()
              .add(Duration(days: durationDays))
              .millisecondsSinceEpoch ~/
          1000;
      final randomId = _randomId(12);
      final username = 'client_$randomId';

      final body = jsonEncode({
        'username': username,
        'proxies': {
          'vless': {'flow': 'xtls-rprx-vision'},
        },
        'inbounds': {
          'vless': ['VLESS Reality'],
        },
        'expire': expireAt,
        'data_limit': 0,
        'note': 'SpeedVPS:$randomId',
      });

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200 && response.statusCode != 201) return null;

      final userData = jsonDecode(response.body);
      String? subUrl = userData['subscription_url'];
      if (subUrl != null && !subUrl.startsWith('http')) {
        subUrl = '$_baseUrl$subUrl';
      }

      if (subUrl != null) {
        final subResponse = await _client.get(Uri.parse(subUrl));
        if (subResponse.statusCode == 200) {
          final lines = const LineSplitter().convert(subResponse.body);
          for (final line in lines) {
            if (line.trim().startsWith('vless://')) return line.trim();
          }
        }
      }

      final links = userData['links'] as List<dynamic>?;
      if (links != null && links.isNotEmpty) return links.first as String;

      return null;
    } catch (e) {
      return null;
    }
  }

  String _randomId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(chars[(DateTime.now().microsecond + i) % chars.length]);
    }
    return sb.toString();
  }

  void dispose() => _client.close();
}

class UserInfo {
  final String username;
  final String status;
  final int dataLimit;
  final int expire;

  UserInfo({
    required this.username,
    required this.status,
    required this.dataLimit,
    required this.expire,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    username: json['username'] ?? '',
    status: json['status'] ?? '',
    dataLimit: json['data_limit'] ?? 0,
    expire: json['expire'] ?? 0,
  );
}

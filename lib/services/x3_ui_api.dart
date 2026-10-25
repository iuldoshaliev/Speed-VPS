import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// API client for 3X-UI panel (v3.x)
/// Works with Bearer token authentication.
class X3UIApi {
  final String _baseUrl;
  final String _token;
  final http.Client _client = http.Client();

  X3UIApi(this._baseUrl, this._token);

  // ── helpers ─────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<T> _post<T>(String path, Object? body, T Function(Map<String, dynamic>) parser) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.post(
      uri,
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('POST $path failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception('API error: ${data['msg']}');
    }
    return parser(data);
  }

  Future<T> _get<T>(String path, T Function(Map<String, dynamic>) parser) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('GET $path failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception('API error: ${data['msg']}');
    }
    return parser(data);
  }

  // ── inbounds ──────────────────────────────────────────────────

  /// List all inbounds with their client stats.
  Future<List<InboundInfo>> listInbounds() async {
    return _get('/panel/api/inbounds/list', (data) {
      final list = data['obj'] as List<dynamic>? ?? [];
      return list.map((e) => InboundInfo.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  /// Lightweight inbound list for pickers (id, remark, protocol, port).
  Future<List<InboundOption>> listInboundOptions() async {
    return _get('/panel/api/inbounds/options', (data) {
      final list = data['obj'] as List<dynamic>? ?? [];
      return list.map((e) => InboundOption.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  // ── clients ───────────────────────────────────────────────────

  /// List every client with attached inbound IDs and traffic record.
  Future<List<ClientInfo>> listClients() async {
    return _get('/panel/api/clients/list', (data) {
      final list = data['obj'] as List<dynamic>? ?? [];
      return list.map((e) => ClientInfo.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  /// Get one client by email.
  Future<ClientInfo?> getClient(String email) async {
    try {
      return _get('/panel/api/clients/get/${Uri.encodeComponent(email)}', (data) {
        final client = data['obj']?['client'] as Map<String, dynamic>?;
        if (client == null) throw Exception('No client data');
        return ClientInfo.fromJson(client);
      });
    } catch (_) {
      return null;
    }
  }

  /// Create a new client attached to given inbounds.
  /// [totalGB] — traffic limit in GB (0 = unlimited)
  /// [expiryTime] — Unix timestamp in milliseconds
  Future<bool> addClient({
    required String email,
    required List<int> inboundIds,
    int totalGB = 0,
    required int expiryTimeMs,
    String? subId,
    bool enable = true,
    String? comment,
  }) async {
    try {
      final body = {
        'client': {
          'email': email,
          if (subId != null) 'subId': subId,
          'totalGB': totalGB == 0 ? 0 : totalGB * 1024 * 1024 * 1024,
          'expiryTime': expiryTimeMs,
          'enable': enable,
          if (comment != null) 'comment': comment,
        },
        'inboundIds': inboundIds,
      };

      final result = await _post('/panel/api/clients/add', body, (data) => data);
      return result['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Update an existing client (full replace).
  Future<bool> updateClient({
    required String email,
    int? totalGB,
    int? expiryTimeMs,
    bool? enable,
  }) async {
    try {
      final body = <String, dynamic>{
        'email': email,
        if (totalGB != null) 'totalGB': totalGB == 0 ? 0 : totalGB * 1024 * 1024 * 1024,
        if (expiryTimeMs != null) 'expiryTime': expiryTimeMs,
        if (enable != null) 'enable': enable,
      };

      final result = await _post(
        '/panel/api/clients/update/${Uri.encodeComponent(email)}',
        body,
        (data) => data,
      );
      return result['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a client by email.
  Future<bool> deleteClient(String email) async {
    try {
      final uri = Uri.parse('$_baseUrl/panel/api/clients/del/${Uri.encodeComponent(email)}');
      final response = await _client.post(uri, headers: _headers);
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ── subscription link ────────────────────────────────────────────

  /// Build subscription URL for a client by subId.
  /// 3X-UI serves subscriptions at a separate port/path.
  String getSubscriptionUrl(String subId) {
    // Subscription server runs on port 2096 with path /aL9xK3mP/
    return 'https://109.120.176.131:2096/aL9xK3mP/${Uri.encodeComponent(subId)}';
  }

  /// Get raw subscription content (usually base64 or plain text with links).
  Future<String?> fetchSubscriptionContent(String subId) async {
    try {
      final url = getSubscriptionUrl(subId);
      final response = await _client.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return null;
      return response.body;
    } catch (e) {
      return null;
    }
  }

  // ── utility ───────────────────────────────────────────────────

  /// Generate a fresh UUID v4 from the server.
  Future<String?> getNewUuid() async {
    try {
      return _get('/panel/api/server/getNewUUID', (data) => data['obj'] as String?);
    } catch (e) {
      return null;
    }
  }

  void dispose() => _client.close();
}

// ── models ───────────────────────────────────────────────────────

class InboundInfo {
  final int id;
  final String remark;
  final String protocol;
  final int port;
  final bool enable;

  InboundInfo({
    required this.id,
    required this.remark,
    required this.protocol,
    required this.port,
    required this.enable,
  });

  factory InboundInfo.fromJson(Map<String, dynamic> json) => InboundInfo(
        id: json['id'] ?? 0,
        remark: json['remark'] ?? '',
        protocol: json['protocol'] ?? '',
        port: json['port'] ?? 0,
        enable: json['enable'] ?? false,
      );
}

class InboundOption {
  final int id;
  final String remark;
  final String protocol;
  final int port;
  final bool tlsFlowCapable;

  InboundOption({
    required this.id,
    required this.remark,
    required this.protocol,
    required this.port,
    required this.tlsFlowCapable,
  });

  factory InboundOption.fromJson(Map<String, dynamic> json) => InboundOption(
        id: json['id'] ?? 0,
        remark: json['remark'] ?? '',
        protocol: json['protocol'] ?? '',
        port: json['port'] ?? 0,
        tlsFlowCapable: json['tlsFlowCapable'] ?? false,
      );
}

class ClientInfo {
  final int id;
  final String email;
  final String? subId;
  final String? uuid;
  final int totalGB;
  final int expiryTime;
  final bool enable;
  final List<int> inboundIds;
  final ClientTraffic? traffic;

  ClientInfo({
    required this.id,
    required this.email,
    this.subId,
    this.uuid,
    required this.totalGB,
    required this.expiryTime,
    required this.enable,
    required this.inboundIds,
    this.traffic,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> json) => ClientInfo(
        id: json['id'] ?? 0,
        email: json['email'] ?? '',
        subId: json['subId'],
        uuid: json['uuid'],
        totalGB: json['totalGB'] ?? 0,
        expiryTime: json['expiryTime'] ?? 0,
        enable: json['enable'] ?? false,
        inboundIds: (json['inboundIds'] as List<dynamic>? ?? []).cast<int>(),
        traffic: json['traffic'] == null
            ? null
            : ClientTraffic.fromJson(json['traffic'] as Map<String, dynamic>),
      );

  /// Expiry as DateTime.
  DateTime? get expiryDate =>
      expiryTime > 0 ? DateTime.fromMillisecondsSinceEpoch(expiryTime) : null;

  /// True if expired.
  bool get isExpired =>
      expiryTime > 0 && DateTime.now().millisecondsSinceEpoch > expiryTime;
}

class ClientTraffic {
  final int up;
  final int down;
  final bool enable;

  ClientTraffic({required this.up, required this.down, required this.enable});

  factory ClientTraffic.fromJson(Map<String, dynamic> json) => ClientTraffic(
        up: json['up'] ?? 0,
        down: json['down'] ?? 0,
        enable: json['enable'] ?? false,
      );
}

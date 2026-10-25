import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/subscription_models.dart';

class YooKassaService {
  final String _shopId;
  final String _secretKey;
  static const String _apiBaseUrl = 'https://api.yookassa.ru/v3';
  final http.Client _client = http.Client();

  YooKassaService(this._shopId, this._secretKey);

  Future<YooKassaPaymentResult?> createPayment(
    double amountRub,
    String description,
    String returnUrl, {
    Map<String, String>? metadata,
  }) async {
    try {
      final body = jsonEncode({
        'amount': {'value': amountRub.toStringAsFixed(2), 'currency': 'RUB'},
        'capture': true,
        'confirmation': {'type': 'redirect', 'return_url': returnUrl},
        'description': description,
        'metadata': metadata ?? {},
      });

      final credentials = base64Encode(utf8.encode('$_shopId:$_secretKey'));
      final request = http.Request('POST', Uri.parse('$_apiBaseUrl/payments'))
        ..headers['Authorization'] = 'Basic $credentials'
        ..headers['Idempotence-Key'] = _generateIdempotenceKey()
        ..headers['Content-Type'] = 'application/json'
        ..body = body;

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _logError('CreatePayment', response.statusCode, response.body);
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return YooKassaPaymentResult(
        paymentId: data['id'] ?? '',
        confirmationUrl: data['confirmation']?['confirmation_url'] ?? '',
        status: _parseStatus(data['status']),
        amount: amountRub,
        description: description,
        metadata: metadata ?? {},
      );
    } catch (e, st) {
      await _logError('CreatePayment', 0, 'Exception: $e\n$st');
      return null;
    }
  }

  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    try {
      final credentials = base64Encode(utf8.encode('$_shopId:$_secretKey'));
      final response = await _client
          .get(
            Uri.parse('$_apiBaseUrl/payments/$paymentId'),
            headers: {'Authorization': 'Basic $credentials'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return PaymentStatus.failed;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseStatus(data['status']);
    } catch (e) {
      return PaymentStatus.failed;
    }
  }

  /// Автоматическое подтверждение платежа (capture) если он в статусе waiting_for_capture
  Future<PaymentStatus> capturePayment(String paymentId, double amountRub) async {
    try {
      final body = jsonEncode({
        'amount': {'value': amountRub.toStringAsFixed(2), 'currency': 'RUB'},
      });

      final credentials = base64Encode(utf8.encode('$_shopId:$_secretKey'));
      final response = await _client
          .post(
            Uri.parse('$_apiBaseUrl/payments/$paymentId/capture'),
            headers: {
              'Authorization': 'Basic $credentials',
              'Idempotence-Key': _generateIdempotenceKey(),
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return PaymentStatus.failed;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseStatus(data['status']);
    } catch (e) {
      return PaymentStatus.failed;
    }
  }

  /// Polling проверки статуса платежа с заданным интервалом
  Stream<PaymentStatus> pollPaymentStatus(
    String paymentId, {
    Duration interval = const Duration(seconds: 10),
    Duration timeout = const Duration(minutes: 10),
  }) async* {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      final status = await getPaymentStatus(paymentId);
      yield status;
      if (status == PaymentStatus.succeeded ||
          status == PaymentStatus.canceled ||
          status == PaymentStatus.failed) {
        break;
      }
      await Future.delayed(interval);
    }
    stopwatch.stop();
  }

  PaymentStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'waiting_for_capture':
        return PaymentStatus.pending;
      case 'succeeded':
        return PaymentStatus.succeeded;
      case 'canceled':
        return PaymentStatus.canceled;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.failed;
    }
  }

  String _generateIdempotenceKey() {
    final rnd = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}_${rnd.nextInt(999999)}';
  }

  Future<void> _logError(String method, int status, String response) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/SpeedVPS/subscription.log');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '[${DateTime.now()}] [YooKassa] $method failed: $status - $response\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  void dispose() => _client.close();
}

/// Конфигурация приложения
/// 
/// Замените значения на реальные перед сборкой релиза.
/// В продакшене рекомендуется получать ключи с сервера,
/// а не хранить их в коде приложения.
class AppConfig {
  // ── YooKassa ────────────────────────────────────────────────
  /// YooKassa Shop ID
  static const String yookassaShopId = 'секрет';

  /// YooKassa Secret Key
  static const String yookassaSecretKey = 'секрет';

  /// URL для возврата после оплаты
  static const String yookassaReturnUrl = 'https://t.me/';

  // ── Server 3X-UI (aeza.net, Frankfurt) ─────────────────────────
  /// Базовый URL панели 3X-UI (включая путь к панели)
  static const String serverBaseUrl = 'секрет';

  /// API Token из 3X-UI: Settings → Security → API Token
  static const String serverApiToken = 'секрет';

  /// ID inbound'ов, к которым прикреплять новых клиентов
  static const List<int> defaultInboundIds = [1];

  // ── Backend (опционально) ────────────────────────────────────
  /// Базовый URL backend API (если используется серверный вебхук)
  static const String? apiBaseUrl = null;
}

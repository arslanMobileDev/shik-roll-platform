import 'package:dio/dio.dart';

import '../../../core/auth/auth_token_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'loyalty_models.dart';

/// Failure surfaced by the loyalty data layer.
final class LoyaltyException implements Exception {
  const LoyaltyException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'LoyaltyException($statusCode): $message';
}

/// Loyalty & promotions access for the guest app (ADR-1614):
/// `GET /loyalty/balance` and `GET /promotions/feed`.
abstract interface class LoyaltyRepository {
  /// Balance, cashback rate and a page of the ledger (newest first).
  /// Requires an authenticated guest.
  Future<LoyaltyBalance> getBalance({int page = 1, int pageSize = 20});

  /// ACTIVE promotion campaigns of the current brand for the menu carousel.
  Future<List<PromotionCampaign>> getPromotionFeed();
}

/// Remote implementation over the Loyalty & Promotions API contract.
final class RemoteLoyaltyRepository implements LoyaltyRepository {
  RemoteLoyaltyRepository(this._client, [this._tokenProvider]);

  final ApiClient _client;

  /// Bearer token of the guest session; mandatory for `/loyalty/balance`,
  /// unused for the public promotions feed.
  final AuthTokenProvider? _tokenProvider;

  @override
  Future<LoyaltyBalance> getBalance({int page = 1, int pageSize = 20}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/loyalty/balance',
        queryParameters: {'page': page, 'page_size': pageSize},
        options: Options(
          headers: {
            if (_tokenProvider?.authorizationHeader != null)
              'Authorization': _tokenProvider!.authorizationHeader,
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        throw LoyaltyException(
          'Пустой ответ сервера при загрузке бонусов. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return LoyaltyBalance.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const LoyaltyException(
        'Некорректный ответ сервера. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Future<List<PromotionCampaign>> getPromotionFeed() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/promotions/feed',
        queryParameters: {'brandId': AppConfig.defaultBrandId},
      );
      final data = response.data;
      if (data == null) {
        throw LoyaltyException(
          'Пустой ответ сервера при загрузке акций. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return [
        for (final item in (data['items'] as List<dynamic>? ?? const []))
          PromotionCampaign.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const LoyaltyException(
        'Некорректный ответ сервера. Попробуйте ещё раз.',
      );
    }
  }

  /// Translates transport failures into a message the guest can act on.
  static LoyaltyException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => LoyaltyException(
        'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        statusCode: statusCode,
      ),
      DioExceptionType.connectionError => LoyaltyException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when (statusCode ?? 0) >= 500 =>
        LoyaltyException(
          'Сервер временно недоступен. Попробуйте позже.',
          statusCode: statusCode,
        ),
      DioExceptionType.badResponse => LoyaltyException(
        _backendMessage(error.response) ??
            'Не удалось загрузить данные лояльности. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.cancel => LoyaltyException(
        'Запрос отменён.',
        statusCode: statusCode,
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => LoyaltyException(
        'Ошибка сети. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
    };
  }

  /// NestJS error payloads: `{ message: '…' }` or `{ message: […] }`.
  static String? _backendMessage(Response<dynamic>? response) {
    final data = response?.data;
    if (data is! Map<String, dynamic>) return null;
    return switch (data['message']) {
      String message when message.isNotEmpty => message,
      List<dynamic> messages when messages.isNotEmpty =>
        messages.first.toString(),
      _ => null,
    };
  }
}

/// In-memory loyalty program for development and tests.
///
/// Used when `API_BASE_URL` is not configured: a fixed demo balance with
/// cashback and two promotion banners; records an `EARN` entry for
/// [earnOnOrderId] so the tracking screen demo can show accrued points.
final class FakeLoyaltyRepository implements LoyaltyRepository {
  FakeLoyaltyRepository({
    this.latency = const Duration(milliseconds: 300),
    this.balance = 250,
    this.cashbackRate = 5,
    List<BonusTransaction>? transactions,
    List<PromotionCampaign>? promotions,
  }) : transactions =
           transactions ??
           [
             BonusTransaction(
               id: 'tx-demo-earn',
               type: BonusTransactionType.earn,
               points: 48,
               balanceAfter: balance,
               orderId: 'demo-order-1042',
               createdAt: DateTime(2026, 9, 1, 12, 30),
             ),
             BonusTransaction(
               id: 'tx-demo-spend',
               type: BonusTransactionType.spend,
               points: -100,
               balanceAfter: balance - 48,
               orderId: 'demo-order-1041',
               createdAt: DateTime(2026, 8, 28, 19, 5),
             ),
           ],
       promotions =
           promotions ??
           [
             PromotionCampaign(
               id: 'promo-demo-1',
               title: 'Кешбэк 10% в сентябре',
               description: 'Повышенный кешбэк бонусами на все роллы.',
               bannerUrl: '',
               startsAt: DateTime(2026, 9, 1),
               endsAt: DateTime(2026, 9, 30),
             ),
             PromotionCampaign(
               id: 'promo-demo-2',
               title: 'Сет дня −20%',
               description: 'Филадельфия и Калифорния по специальной цене.',
               bannerUrl: '',
               startsAt: DateTime(2026, 9, 1),
               endsAt: DateTime(2026, 9, 15),
             ),
           ];

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  final int balance;
  final double cashbackRate;
  final List<BonusTransaction> transactions;
  final List<PromotionCampaign> promotions;

  Future<void> _simulateLatency() async {
    // A zero latency stays on the microtask queue (no timer), which keeps
    // tests deterministic.
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<LoyaltyBalance> getBalance({int page = 1, int pageSize = 20}) async {
    await _simulateLatency();
    final start = (page - 1) * pageSize;
    final slice = start >= transactions.length
        ? <BonusTransaction>[]
        : transactions.sublist(
            start,
            start + pageSize > transactions.length
                ? transactions.length
                : start + pageSize,
          );
    return LoyaltyBalance(
      balance: balance,
      cashbackRate: cashbackRate,
      transactions: slice,
      pagination: LoyaltyPagination(
        page: page,
        pageSize: pageSize,
        total: transactions.length,
        totalPages: transactions.isEmpty
            ? 0
            : (transactions.length + pageSize - 1) ~/ pageSize,
      ),
    );
  }

  @override
  Future<List<PromotionCampaign>> getPromotionFeed() async {
    await _simulateLatency();
    return promotions;
  }
}

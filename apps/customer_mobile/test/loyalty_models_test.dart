import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:customer_mobile/features/loyalty/domain/bonus_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoyaltyBalance.fromJson (ADR-1614)', () {
    test('парсит контракт GET /loyalty/balance со snake_case полями', () {
      final balance = LoyaltyBalance.fromJson(const {
        'balance': 250,
        'cashback_rate': 5.0,
        'transactions': [
          {
            'id': 'tx-1',
            'type': 'EARN',
            'points': 48,
            'balance_after': 250,
            'order_id': 'order-1',
            'created_at': '2026-09-05T12:30:00.000Z',
            'expires_at': null,
          },
          {
            'id': 'tx-2',
            'type': 'SPEND',
            'points': -100,
            'balance_after': 202,
            'order_id': null,
            'created_at': '2026-09-04T19:05:00.000Z',
            'expires_at': '2027-09-04T00:00:00.000Z',
          },
        ],
        'pagination': {
          'page': 1,
          'page_size': 20,
          'total': 2,
          'total_pages': 1,
        },
      });

      expect(balance.balance, 250);
      expect(balance.cashbackRate, 5.0);
      expect(balance.transactions, hasLength(2));

      final earn = balance.transactions[0];
      expect(earn.type, BonusTransactionType.earn);
      expect(earn.points, 48);
      expect(earn.balanceAfter, 250);
      expect(earn.orderId, 'order-1');
      expect(earn.expiresAt, isNull);

      final spend = balance.transactions[1];
      expect(spend.type, BonusTransactionType.spend);
      expect(spend.points, -100);
      expect(spend.orderId, isNull);
      expect(spend.expiresAt, DateTime.parse('2027-09-04T00:00:00.000Z'));

      expect(balance.pagination.page, 1);
      expect(balance.pagination.pageSize, 20);
      expect(balance.pagination.total, 2);
      expect(balance.pagination.totalPages, 1);
      expect(balance.pagination.hasNextPage, isFalse);
    });

    test('integer cashback_rate приводится к double', () {
      final balance = LoyaltyBalance.fromJson(const {
        'balance': 0,
        'cashback_rate': 7,
        'transactions': <dynamic>[],
        'pagination': {
          'page': 1,
          'page_size': 20,
          'total': 0,
          'total_pages': 0,
        },
      });

      expect(balance.cashbackRate, 7.0);
    });

    test('битый payload → FormatException', () {
      expect(
        () => LoyaltyBalance.fromJson(const {'cashback_rate': 5}),
        throwsA(isA<FormatException>()),
      );
    });

    test('неизвестный тип транзакции → FormatException', () {
      expect(
        () => BonusTransactionType.fromWire('ADJUSTMENT'),
        throwsA(isA<FormatException>()),
      );
    });

    test('earnedPointsFor суммирует EARN-записи заказа', () {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final balance = LoyaltyBalance(
        balance: 310,
        cashbackRate: 5,
        transactions: [
          BonusTransaction(
            id: 'tx-1',
            type: BonusTransactionType.earn,
            points: 48,
            balanceAfter: 250,
            orderId: 'order-1',
            createdAt: epoch,
          ),
          BonusTransaction(
            id: 'tx-2',
            type: BonusTransactionType.refund,
            points: 100,
            balanceAfter: 302,
            orderId: 'order-1',
            createdAt: epoch,
          ),
          BonusTransaction(
            id: 'tx-3',
            type: BonusTransactionType.earn,
            points: 8,
            balanceAfter: 310,
            orderId: 'order-2',
            createdAt: epoch,
          ),
        ],
        pagination: const LoyaltyPagination(
          page: 1,
          pageSize: 20,
          total: 3,
          totalPages: 1,
        ),
      );

      // REFUND не считается начислением кешбэка.
      expect(balance.earnedPointsFor('order-1'), 48);
      expect(balance.earnedPointsFor('order-2'), 8);
    });
  });

  group('PromotionCampaign.fromJson (ADR-1614)', () {
    test('парсит элемент ленты со snake_case полями и nullable-полями', () {
      final campaign = PromotionCampaign.fromJson(const {
        'id': 'promo-1',
        'title': 'Кешбэк 10% в сентябре',
        'description': null,
        'banner_url': 'https://cdn.example.com/banner.webp',
        'action_url': null,
        'starts_at': '2026-09-01T00:00:00.000Z',
        'ends_at': '2026-09-30T23:59:59.000Z',
      });

      expect(campaign.id, 'promo-1');
      expect(campaign.title, 'Кешбэк 10% в сентябре');
      expect(campaign.description, isNull);
      expect(campaign.bannerUrl, 'https://cdn.example.com/banner.webp');
      expect(campaign.actionUrl, isNull);
      expect(campaign.startsAt, DateTime.parse('2026-09-01T00:00:00.000Z'));
      expect(campaign.endsAt, DateTime.parse('2026-09-30T23:59:59.000Z'));
    });

    test('битый payload → FormatException', () {
      expect(
        () => PromotionCampaign.fromJson(const {'id': 'promo-1'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('bonus_math (зеркало backend bonus-rules, ADR-1614)', () {
    test('bonusLimitPoints: ровно 30% от базы, округление вниз', () {
      expect(bonusLimitPoints(const Money.kopecks(39000)), 117); // 390,00 ₽
      expect(bonusLimitPoints(const Money.kopecks(999)), 2); // 9,99 ₽ → 2,99…
      expect(bonusLimitPoints(const Money.kopecks(100)), 0); // 1,00 ₽ → 0,30
      expect(bonusLimitPoints(Money.zero), 0);
      expect(bonusLimitPoints(const Money.kopecks(-500)), 0);
    });

    test('maxBonusPoints: min(баланс, лимит 30%)', () {
      const base = Money.kopecks(39000); // лимит 117
      expect(maxBonusPoints(base, 500), 117);
      expect(maxBonusPoints(base, 117), 117);
      expect(maxBonusPoints(base, 100), 100);
      expect(maxBonusPoints(base, 0), 0);
      expect(maxBonusPoints(base, -10), 0);
    });

    test('cashbackPointsFor: floor(сумма * ставка / 100)', () {
      expect(cashbackPointsFor(const Money.kopecks(39000), 5), 19); // 19,5 → 19
      expect(cashbackPointsFor(const Money.kopecks(155000), 5), 77);
      expect(cashbackPointsFor(const Money.kopecks(39000), 0), 0);
      expect(cashbackPointsFor(Money.zero, 5), 0);
      expect(cashbackPointsFor(const Money.kopecks(-100), 5), 0);
    });
  });
}

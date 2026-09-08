import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/loyalty/bloc/loyalty_cubit.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoyaltyRepository extends Mock implements LoyaltyRepository {}

final _earnTx = BonusTransaction(
  id: 'tx-earn-1',
  type: BonusTransactionType.earn,
  points: 48,
  balanceAfter: 250,
  orderId: 'order-1',
  createdAt: DateTime(2026, 9, 5, 12, 30),
);

final _spendTx = BonusTransaction(
  id: 'tx-spend-1',
  type: BonusTransactionType.spend,
  points: -100,
  balanceAfter: 202,
  orderId: 'order-2',
  createdAt: DateTime(2026, 9, 4, 19, 5),
);

const _pagination = LoyaltyPagination(
  page: 1,
  pageSize: 20,
  total: 2,
  totalPages: 1,
);

final _balancePayload = LoyaltyBalance(
  balance: 250,
  cashbackRate: 5,
  transactions: [_earnTx, _spendTx],
  pagination: _pagination,
);

final _promotions = [
  PromotionCampaign(
    id: 'promo-1',
    title: 'Кешбэк 10%',
    description: 'На все роллы',
    bannerUrl: '',
    startsAt: DateTime(2026, 9, 1),
    endsAt: DateTime(2026, 9, 30),
  ),
];

void main() {
  late _MockLoyaltyRepository repository;

  setUp(() => repository = _MockLoyaltyRepository());

  LoyaltyCubit buildCubit() => LoyaltyCubit(repository: repository);

  void stubBalance(LoyaltyBalance payload) => when(
    () => repository.getBalance(
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((_) async => payload);

  group('LoyaltyCubit.loadBalance', () {
    blocTest<LoyaltyCubit, LoyaltyState>(
      'успех: loading → loaded с балансом, ставкой и леджером',
      setUp: () => stubBalance(_balancePayload),
      build: buildCubit,
      act: (cubit) => cubit.loadBalance(),
      expect: () => [
        const LoyaltyState(status: LoyaltyStatus.loading),
        LoyaltyState(
          status: LoyaltyStatus.loaded,
          balance: 250,
          cashbackRate: 5,
          transactions: [_earnTx, _spendTx],
          pagination: _pagination,
        ),
      ],
    );

    blocTest<LoyaltyCubit, LoyaltyState>(
      'параметры пагинации пробрасываются в репозиторий',
      setUp: () => stubBalance(_balancePayload),
      build: buildCubit,
      act: (cubit) => cubit.loadBalance(page: 3, pageSize: 50),
      verify: (_) =>
          verify(() => repository.getBalance(page: 3, pageSize: 50)).called(1),
    );

    blocTest<LoyaltyCubit, LoyaltyState>(
      'ошибка: loading → failure с сообщением',
      setUp: () =>
          when(
            () => repository.getBalance(
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
            ),
          ).thenThrow(
            const LoyaltyException('Сервер не отвечает.', statusCode: 503),
          ),
      build: buildCubit,
      act: (cubit) => cubit.loadBalance(),
      expect: () => [
        const LoyaltyState(status: LoyaltyStatus.loading),
        const LoyaltyState(
          status: LoyaltyStatus.failure,
          errorMessage: 'Сервер не отвечает.',
        ),
      ],
    );

    blocTest<LoyaltyCubit, LoyaltyState>(
      'повторная загрузка сбрасывает прежнюю ошибку',
      setUp: () {
        var call = 0;
        when(
          () => repository.getBalance(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async {
          call++;
          if (call == 1) {
            throw const LoyaltyException('Сервер не отвечает.');
          }
          return _balancePayload;
        });
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.loadBalance();
        await cubit.loadBalance();
      },
      expect: () => [
        const LoyaltyState(status: LoyaltyStatus.loading),
        const LoyaltyState(
          status: LoyaltyStatus.failure,
          errorMessage: 'Сервер не отвечает.',
        ),
        const LoyaltyState(status: LoyaltyStatus.loading),
        LoyaltyState(
          status: LoyaltyStatus.loaded,
          balance: 250,
          cashbackRate: 5,
          transactions: [_earnTx, _spendTx],
          pagination: _pagination,
        ),
      ],
    );
  });

  group('LoyaltyCubit.loadPromotions', () {
    blocTest<LoyaltyCubit, LoyaltyState>(
      'успех: лента акций загружена',
      setUp: () => when(
        () => repository.getPromotionFeed(),
      ).thenAnswer((_) async => _promotions),
      build: buildCubit,
      act: (cubit) => cubit.loadPromotions(),
      expect: () => [
        const LoyaltyState(promotionsStatus: LoyaltyStatus.loading),
        LoyaltyState(
          promotionsStatus: LoyaltyStatus.loaded,
          promotions: _promotions,
        ),
      ],
    );

    blocTest<LoyaltyCubit, LoyaltyState>(
      'ошибка ленты не трогает баланс и помечает только feed',
      setUp: () => when(
        () => repository.getPromotionFeed(),
      ).thenThrow(const LoyaltyException('Сервер не отвечает.')),
      build: buildCubit,
      act: (cubit) => cubit.loadPromotions(),
      expect: () => [
        const LoyaltyState(promotionsStatus: LoyaltyStatus.loading),
        const LoyaltyState(promotionsStatus: LoyaltyStatus.failure),
      ],
    );
  });

  group('LoyaltyCubit.refresh / clear', () {
    blocTest<LoyaltyCubit, LoyaltyState>(
      'refresh перезагружает и баланс, и ленту',
      setUp: () {
        stubBalance(_balancePayload);
        when(
          () => repository.getPromotionFeed(),
        ).thenAnswer((_) async => _promotions);
      },
      build: buildCubit,
      act: (cubit) => cubit.refresh(),
      verify: (_) {
        verify(
          () => repository.getBalance(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).called(1);
        verify(() => repository.getPromotionFeed()).called(1);
      },
    );

    blocTest<LoyaltyCubit, LoyaltyState>(
      'clear (выход из аккаунта) стирает баланс, но оставляет акции',
      setUp: () {
        stubBalance(_balancePayload);
        when(
          () => repository.getPromotionFeed(),
        ).thenAnswer((_) async => _promotions);
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.loadBalance();
        await cubit.loadPromotions();
        cubit.clear();
      },
      expect: () => [
        const LoyaltyState(status: LoyaltyStatus.loading),
        LoyaltyState(
          status: LoyaltyStatus.loaded,
          balance: 250,
          cashbackRate: 5,
          transactions: [_earnTx, _spendTx],
          pagination: _pagination,
        ),
        LoyaltyState(
          status: LoyaltyStatus.loaded,
          promotionsStatus: LoyaltyStatus.loading,
          balance: 250,
          cashbackRate: 5,
          transactions: [_earnTx, _spendTx],
          pagination: _pagination,
        ),
        LoyaltyState(
          status: LoyaltyStatus.loaded,
          promotionsStatus: LoyaltyStatus.loaded,
          balance: 250,
          cashbackRate: 5,
          transactions: [_earnTx, _spendTx],
          pagination: _pagination,
          promotions: _promotions,
        ),
        LoyaltyState(
          promotionsStatus: LoyaltyStatus.loaded,
          promotions: _promotions,
        ),
      ],
    );
  });

  group('LoyaltyState производные', () {
    test('earnedPointsFor суммирует только EARN-записи нужного заказа', () {
      final state = LoyaltyState(
        status: LoyaltyStatus.loaded,
        transactions: [
          _earnTx,
          _spendTx,
          BonusTransaction(
            id: 'tx-earn-2',
            type: BonusTransactionType.earn,
            points: 12,
            balanceAfter: 262,
            orderId: 'order-1',
            createdAt: DateTime(2026, 9, 6),
          ),
        ],
      );

      expect(state.earnedPointsFor('order-1'), 60);
      expect(state.earnedPointsFor('order-2'), 0);
      expect(state.earnedPointsFor('unknown'), 0);
    });

    test('maxSpendablePoints: лимит 30% от чека, усечённый балансом', () {
      const loaded = LoyaltyState(status: LoyaltyStatus.loaded, balance: 500);

      // 30% от 390,00 ₽ = 117 баллов; баланс больше — берём лимит.
      expect(loaded.maxSpendablePoints(const Money.kopecks(39000)), 117);
      // Баланс меньше лимита — берём баланс.
      const poor = LoyaltyState(status: LoyaltyStatus.loaded, balance: 100);
      expect(poor.maxSpendablePoints(const Money.kopecks(39000)), 100);
      // Пустой чек — ноль.
      expect(loaded.maxSpendablePoints(Money.zero), 0);
    });
  });
}

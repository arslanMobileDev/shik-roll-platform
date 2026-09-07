---
Document ID: ADR-1614

Document Name: ADR - LOYALTY SERVICE

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: September 2026
Last Updated: September 2026

Classification: Internal
---

# ADR - LOYALTY SERVICE

## Status

Accepted

## Context

Customer Mobile требует единого баланса бонусов, истории операций, применения бонусов при checkout и ленты активных акций. Контракты должны соответствовать API-First, NestJS, Prisma и PostgreSQL.

## Decision

Создать bounded context `loyalty` внутри текущего модульного монолита. `BonusTransaction` является неизменяемым ledger, а `BonusAccount.balance` - атомарно обновляемой проекцией баланса.

Бизнес-правила:

- 1 бонус = 1 RUB;
- бонусы целочисленные, дробные значения запрещены;
- списание не превышает 30% суммы товаров после промо-скидок, до бонусов;
- cashback начисляется на фактически оплаченную сумму товаров после всех скидок;
- начисление выполняется один раз после внутреннего перехода заказа в `OrderStatus.COMPLETED`, который проецируется клиенту как `DELIVERED`;
- отмена или возврат после списания создаёт `REFUND`; истечение срока создаёт `EXPIRE`; ledger-записи не изменяются и не удаляются.

## Data Contract

```prisma
enum BonusTransactionType {
  EARN
  SPEND
  EXPIRE
  REFUND
}

enum PromotionCampaignStatus {
  DRAFT
  ACTIVE
  PAUSED
  ENDED
}

model BonusAccount {
  id           String   @id @default(uuid()) @db.Uuid
  customerId   String   @unique @map("customer_id") @db.Uuid
  balance      Int      @default(0)
  cashbackRate Decimal  @default(0) @map("cashback_rate") @db.Decimal(5, 2)
  createdAt    DateTime @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt    DateTime @updatedAt @map("updated_at") @db.Timestamptz(6)

  customer     Customer           @relation(fields: [customerId], references: [id], onDelete: Restrict)
  transactions BonusTransaction[]

  @@map("bonus_accounts")
}

model BonusTransaction {
  id             String               @id @default(uuid()) @db.Uuid
  accountId      String               @map("account_id") @db.Uuid
  orderId        String?              @map("order_id") @db.Uuid
  type           BonusTransactionType
  points         Int                  // signed: EARN/REFUND > 0; SPEND/EXPIRE < 0
  balanceAfter   Int                  @map("balance_after")
  idempotencyKey String               @unique @map("idempotency_key")
  expiresAt      DateTime?            @map("expires_at") @db.Timestamptz(6)
  createdAt      DateTime             @default(now()) @map("created_at") @db.Timestamptz(6)

  account BonusAccount @relation(fields: [accountId], references: [id], onDelete: Restrict)
  order   Order?       @relation(fields: [orderId], references: [id], onDelete: Restrict)

  @@index([accountId, createdAt], map: "idx_bonus_transactions_account_id_created_at")
  @@index([orderId], map: "idx_bonus_transactions_order_id")
  @@map("bonus_transactions")
}

model PromotionCampaign {
  id          String                  @id @default(uuid()) @db.Uuid
  brandId     String                  @map("brand_id") @db.Uuid
  title       String
  description String?
  bannerUrl   String                  @map("banner_url")
  actionUrl   String?                 @map("action_url")
  status      PromotionCampaignStatus @default(DRAFT)
  priority    Int                     @default(0)
  startsAt    DateTime                @map("starts_at") @db.Timestamptz(6)
  endsAt      DateTime                @map("ends_at") @db.Timestamptz(6)
  createdAt   DateTime                @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt   DateTime                @updatedAt @map("updated_at") @db.Timestamptz(6)

  brand Brand @relation(fields: [brandId], references: [id], onDelete: Restrict)

  @@index([brandId, status, startsAt, endsAt], map: "idx_promotion_campaigns_feed")
  @@map("promotion_campaigns")
}
```

Обратные relation-поля добавляются в `Customer`, `Order` и `Brand`. CHECK constraints миграции: `balance >= 0`, `cashback_rate BETWEEN 0 AND 100`, `points <> 0`, `ends_at > starts_at`.

## API Contracts

```ts
type BonusTransactionDto = {
  id: string;
  type: 'EARN' | 'SPEND' | 'EXPIRE' | 'REFUND';
  points: number;
  balance_after: number;
  order_id: string | null;
  created_at: string;
  expires_at: string | null;
};

type LoyaltyBalanceResponseDto = {
  balance: number;
  cashback_rate: number;
  transactions: BonusTransactionDto[];
  pagination: { page: number; page_size: number; total: number; total_pages: number };
};
```

`GET /api/v1/loyalty/balance?page=1&page_size=20`

- требует customer access token;
- `page >= 1`, `page_size = 1..100`;
- история сортируется по `created_at DESC, id DESC`.

```ts
type CheckoutRequestDto = {
  // existing checkout fields remain backward compatible
  use_bonus_points?: number; // integer, default 0, minimum 0
};

type CheckoutTotalsDto = {
  subtotal_amount: string;
  promotion_discount_amount: string;
  bonus_discount_amount: string;
  applied_bonus_points: number;
  payable_amount: string;
  currency: 'RUB';
};
```

`POST /api/v1/orders/checkout` вычисляет:

```text
bonus_base = subtotal_amount - promotion_discount_amount
max_bonus_points = min(account.balance, floor(bonus_base * 0.30))
bonus_discount_amount = use_bonus_points * 1 RUB
payable_amount = bonus_base - bonus_discount_amount
```

Запрос отклоняется с `422 BONUS_LIMIT_EXCEEDED`, если число бонусов превышает 30%, и с `409 INSUFFICIENT_BONUS_BALANCE`, если баланс уже недостаточен. Создание заказа, условное уменьшение баланса и `SPEND` выполняются одной транзакцией. Повтор checkout защищается существующим `Idempotency-Key`; ключ ledger: `spend:{orderId}`.

Начисление cashback: `floor(payable_item_amount * cashback_rate / 100)`, ledger key `earn:{orderId}`. Worker обязан быть идемпотентным; повторный `COMPLETED` не меняет баланс.

```ts
type PromotionFeedItemDto = {
  id: string;
  title: string;
  description: string | null;
  banner_url: string;
  action_url: string | null;
  starts_at: string;
  ends_at: string;
};

type PromotionFeedResponseDto = { items: PromotionFeedItemDto[] };
```

`GET /api/v1/promotions/feed` возвращает только `ACTIVE` кампании текущего бренда, где `starts_at <= now < ends_at`, в порядке `priority DESC, starts_at DESC`.

## Consistency And Security

- Баланс никогда не принимается от клиента и не вычисляется в мобильном приложении.
- Все денежные значения API передаются decimal-строками; бонусы - JSON integer.
- Изменение баланса и ledger выполняются атомарно с защитой от отрицательного остатка.
- Транзакции доступны только владельцу аккаунта; административные операции требуют отдельного staff scope и audit trail.

## Consequences

Положительные: воспроизводимый баланс, идемпотентное начисление, единая серверная проверка 30%, совместимый feed для карусели.

Отрицательные: требуется транзакционная конкуренция вокруг аккаунта, scheduler для `EXPIRE` и компенсация `REFUND`.

## Alternatives Rejected

- Вычислять баланс суммой ledger при каждом запросе: слишком дорого для горячего endpoint.
- Хранить только изменяемый баланс: отсутствует аудит.
- Начислять cashback при оплате: заказ может быть отменён до доставки.

## Review Criteria

Пересмотреть при появлении дробных бонусов, мультивалютности, transferable points или выделении loyalty в отдельный сервис.

## Related Documents

ADR-1603 Event-Driven Architecture

ADR-1604 PostgreSQL as Primary Database

ADR-1607 Prisma ORM as Data Access Layer

ADR-1609 API-First and Contract-First Development

ADR-1615 Realtime Order Timeline

END OF DOCUMENT

import { BadGatewayException } from '@nestjs/common';
import { PaymentStatus, Prisma } from '@prisma/client';
import { YooKassaProvider } from './yookassa.provider';
import { CreatePaymentSessionInput } from '../payments.types';

const D = (value: string | number) => new Prisma.Decimal(value);

function makeInput(overrides: Partial<CreatePaymentSessionInput> = {}): CreatePaymentSessionInput {
  return {
    paymentId: '99999999-9999-9999-9999-999999999999',
    orderId: '55555555-5555-5555-5555-555555555555',
    orderNumber: 'AAAA-20260904-0001',
    idempotenceKey: 'pay_55555555-5555-5555-5555-555555555555_1',
    amount: D('500.00'),
    currency: 'RUB',
    description: 'Заказ AAAA-20260904-0001',
    customer: { email: null, phone: '+79000000000' },
    receiptLines: [
      { description: 'Филадельфия (+Икра тобико)', quantity: 1, unitPrice: D('500.00') },
    ],
    ...overrides,
  };
}

describe('YooKassaProvider', () => {
  const provider = new YooKassaProvider();
  const fetchMock = jest.fn();

  beforeEach(() => {
    fetchMock.mockReset();
    global.fetch = fetchMock as unknown as typeof fetch;
  });

  it('POSTs /payments with Basic auth, Idempotence-Key and a 54-ФЗ receipt', async () => {
    fetchMock.mockResolvedValue({
      ok: true,
      json: async () => ({
        id: '2c9f0000-000f-5000-9000-1aaaaaaaaaaa',
        status: 'pending',
        confirmation: {
          type: 'redirect',
          confirmation_url: 'https://yoomoney.ru/checkout/payments/v2/contract?orderId=x',
        },
      }),
    });

    const result = await provider.createPayment(makeInput());

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.yookassa.ru/v3/payments');
    expect(init.method).toBe('POST');
    const headers = init.headers as Record<string, string>;
    expect(headers['Idempotence-Key']).toBe(
      'pay_55555555-5555-5555-5555-555555555555_1',
    );
    expect(headers.Authorization).toMatch(/^Basic /);

    const body = JSON.parse(String(init.body));
    expect(body.amount).toEqual({ value: '500.00', currency: 'RUB' });
    expect(body.capture).toBe(true);
    expect(body.confirmation.type).toBe('redirect');
    expect(body.metadata).toEqual({
      orderId: '55555555-5555-5555-5555-555555555555',
      paymentId: '99999999-9999-9999-9999-999999999999',
    });
    // 54-ФЗ receipt forwarded to the Атол Сигма online cash register.
    expect(body.receipt.customer).toEqual({ phone: '+79000000000' });
    expect(body.receipt.items).toEqual([
      {
        description: 'Филадельфия (+Икра тобико)',
        quantity: 1,
        amount: { value: '500.00', currency: 'RUB' },
        vat_code: 1,
        payment_mode: 'full_payment',
        payment_subject: 'commodity',
      },
    ]);

    expect(result).toEqual({
      externalPaymentId: '2c9f0000-000f-5000-9000-1aaaaaaaaaaa',
      paymentUrl: 'https://yoomoney.ru/checkout/payments/v2/contract?orderId=x',
      status: PaymentStatus.PENDING,
    });
  });

  it('maps provider statuses onto our lifecycle', async () => {
    for (const [remote, local] of [
      ['pending', PaymentStatus.PENDING],
      ['waiting_for_capture', PaymentStatus.PENDING],
      ['succeeded', PaymentStatus.SUCCEEDED],
      ['canceled', PaymentStatus.CANCELED],
    ] as const) {
      fetchMock.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'ext', status: remote }),
      });
      const result = await provider.createPayment(makeInput());
      expect(result.status).toBe(local);
    }
  });

  it('omits the optional receipt without a customer contact', async () => {
    fetchMock.mockResolvedValue({
      ok: true,
      json: async () => ({ id: 'ext', status: 'pending' }),
    });
    await provider.createPayment(makeInput({ customer: undefined }));
    const body = JSON.parse(String(fetchMock.mock.calls[0][1].body));
    expect(body.receipt).toBeUndefined();
  });

  it('maps a provider rejection to PAYMENT_PROVIDER_ERROR', async () => {
    fetchMock.mockResolvedValue({
      ok: false,
      status: 400,
      text: async () => '{"code":"invalid_request"}',
    });

    await expect(provider.createPayment(makeInput())).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'PAYMENT_PROVIDER_ERROR' }),
    });
    await expect(provider.createPayment(makeInput())).rejects.toThrow(
      BadGatewayException,
    );
  });

  it('maps a network failure to PAYMENT_PROVIDER_UNAVAILABLE', async () => {
    fetchMock.mockRejectedValue(new Error('socket hang up'));

    await expect(provider.createPayment(makeInput())).rejects.toMatchObject({
      response: expect.objectContaining({
        code: 'PAYMENT_PROVIDER_UNAVAILABLE',
      }),
    });
  });

  const expected = makeInput();
  const notification = {
    type: 'notification', event: 'payment.succeeded',
    object: { id: 'ext-1', status: 'succeeded' },
  };
  const authoritative = {
    id: 'ext-1', status: 'succeeded', paid: true,
    amount: { value: '500.00', currency: 'RUB' },
    metadata: { orderId: expected.orderId, paymentId: expected.paymentId },
  };

  it('verifies GET data against the database even without notification metadata', async () => {
    fetchMock.mockResolvedValue({ ok: true, json: async () => authoritative });
    await expect(provider.verifyWebhook({}, notification, expected)).resolves.toBe(true);
    expect(fetchMock).toHaveBeenCalledWith('https://api.yookassa.ru/v3/payments/ext-1',
      expect.objectContaining({ method: 'GET', signal: expect.any(AbortSignal),
        headers: { Authorization: expect.stringMatching(/^Basic /) } }));
  });

  it.each([
    { id: 'other' }, { status: 'pending' }, { paid: false },
    { amount: { value: '1.00', currency: 'RUB' } },
    { amount: { value: '500.00', currency: 'USD' } },
    { metadata: { ...authoritative.metadata, orderId: 'another-order' } },
    { metadata: { ...authoritative.metadata, paymentId: 'another-attempt' } },
    { metadata: undefined },
  ])('rejects an authoritative mismatch: %j', async (override) => {
    fetchMock.mockResolvedValue({ ok: true, json: async () => ({ ...authoritative, ...override }) });
    await expect(provider.verifyWebhook({}, notification, expected)).resolves.toBe(false);
  });

  it('does not trust a forged amount or metadata from the notification', async () => {
    fetchMock.mockResolvedValue({ ok: true, json: async () => ({
      ...authoritative, amount: { value: '1.00', currency: 'RUB' },
    }) });
    await expect(provider.verifyWebhook({}, {
      ...notification, object: { ...notification.object,
        amount: authoritative.amount, metadata: authoritative.metadata },
    }, expected)).resolves.toBe(false);
  });

  it('verifies canceled payments without requiring paid=true', async () => {
    fetchMock.mockResolvedValue({ ok: true, json: async () => ({
      ...authoritative, status: 'canceled', paid: false,
    }) });
    await expect(provider.verifyWebhook({}, {
      ...notification, event: 'payment.canceled',
      object: { id: 'ext-1', status: 'canceled' },
    }, expected)).resolves.toBe(true);
  });

  it.each([401, 404, 429, 500])('propagates provider HTTP %s for retry', async (status) => {
    fetchMock.mockResolvedValue({ ok: false, status });
    await expect(provider.verifyWebhook({}, notification, expected)).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'PAYMENT_VERIFICATION_UNAVAILABLE' }),
    });
  });

  it.each(['network', 'timeout', 'invalid JSON', 'malformed object'])(
    'propagates %s verification failures for retry', async (failure) => {
      if (failure === 'network' || failure === 'timeout') {
        fetchMock.mockRejectedValue(new Error(failure));
      } else {
        fetchMock.mockResolvedValue({ ok: true, json: async () => {
          if (failure === 'invalid JSON') throw new SyntaxError('invalid JSON');
          return null;
        } });
      }
      await expect(provider.verifyWebhook({}, notification, expected)).rejects.toBeInstanceOf(BadGatewayException);
    },
  );
});

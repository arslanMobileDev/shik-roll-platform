import { BadGatewayException, BadRequestException } from '@nestjs/common';
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

    const result = await provider.createSession(makeInput());

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
      const result = await provider.createSession(makeInput());
      expect(result.status).toBe(local);
    }
  });

  it('fails fast without a customer contact for the receipt', async () => {
    await expect(
      provider.createSession(makeInput({ customer: { email: null, phone: null } })),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        code: 'PAYMENT_CUSTOMER_CONTACT_REQUIRED',
      }),
    });
    await expect(
      provider.createSession(makeInput({ customer: undefined })),
    ).rejects.toThrow(BadRequestException);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('maps a provider rejection to PAYMENT_PROVIDER_ERROR', async () => {
    fetchMock.mockResolvedValue({
      ok: false,
      status: 400,
      text: async () => '{"code":"invalid_request"}',
    });

    await expect(provider.createSession(makeInput())).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'PAYMENT_PROVIDER_ERROR' }),
    });
    await expect(provider.createSession(makeInput())).rejects.toThrow(
      BadGatewayException,
    );
  });

  it('maps a network failure to PAYMENT_PROVIDER_UNAVAILABLE', async () => {
    fetchMock.mockRejectedValue(new Error('socket hang up'));

    await expect(provider.createSession(makeInput())).rejects.toMatchObject({
      response: expect.objectContaining({
        code: 'PAYMENT_PROVIDER_UNAVAILABLE',
      }),
    });
  });
});

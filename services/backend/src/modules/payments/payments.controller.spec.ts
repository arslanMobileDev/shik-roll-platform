import { Test } from '@nestjs/testing';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

describe('PaymentsController', () => {
  let controller: PaymentsController;
  let service: { handleWebhook: jest.Mock };

  beforeEach(async () => {
    service = { handleWebhook: jest.fn() };
    const module = await Test.createTestingModule({
      controllers: [PaymentsController],
      providers: [{ provide: PaymentsService, useValue: service }],
    }).compile();
    controller = module.get(PaymentsController);
  });

  const payload = {
    type: 'notification',
    event: 'payment.succeeded',
    object: { id: 'ext-1', status: 'succeeded' },
  };

  it('handles the canonical webhook endpoint', async () => {
    service.handleWebhook.mockResolvedValue({ status: 'processed' });
    await expect(controller.webhook({}, payload)).resolves.toEqual({
      status: 'processed',
    });
  });

  it('keeps the legacy YooKassa endpoint compatible', async () => {
    service.handleWebhook.mockResolvedValue({ status: 'processed' });
    await expect(controller.yooKassaWebhook({}, payload)).resolves.toEqual({
      status: 'processed',
    });
  });

  it('acknowledges processing failures instead of returning a non-200 error', async () => {
    service.handleWebhook.mockRejectedValue(new Error('database unavailable'));
    await expect(controller.webhook({}, payload)).resolves.toEqual({
      status: 'ignored',
    });
  });
});

import { OrderStatus } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { OrderQueryDto } from './order-query.dto';

describe('OrderQueryDto', () => {
  it('parses a comma-separated status filter', async () => {
    const dto = plainToInstance(OrderQueryDto, { status: 'NEW,READY' });

    expect(dto.status).toEqual([OrderStatus.NEW, OrderStatus.READY]);
    expect(await validate(dto)).toHaveLength(0);
  });

  it('parses repeated status query parameters', async () => {
    const dto = plainToInstance(OrderQueryDto, {
      status: ['CONFIRMED', 'COOKING'],
    });

    expect(dto.status).toEqual([OrderStatus.CONFIRMED, OrderStatus.COOKING]);
    expect(await validate(dto)).toHaveLength(0);
  });

  it('rejects an unknown status', async () => {
    const dto = plainToInstance(OrderQueryDto, { status: 'UNKNOWN' });

    expect(await validate(dto)).not.toHaveLength(0);
  });
});

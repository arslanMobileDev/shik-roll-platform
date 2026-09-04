import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OrderStatus, Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderQueuesService } from '../queues/order-queues.service';
import { lineTotal, orderSubtotal, orderTotal } from './domain/order-pricing';
import {
  assertTransition,
  InvalidOrderStatusTransitionError,
} from './domain/order-status-machine';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderQueryDto } from './dto/order-query.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { OrderEntity, OrderPage } from './entities/order.entity';
import { toOrderEntity } from './mappers/order.mapper';
import { OrdersRepository } from './orders.repository';

@Injectable()
export class OrdersService {
  constructor(
    private readonly repository: OrdersRepository,
    private readonly queues: OrderQueuesService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * List orders. When the request carries a guest token (customerId), the
   * result is restricted to that customer's orders — guests never see
   * other customers' orders regardless of the query filters.
   */
  async list(query: OrderQueryDto, customerId?: string): Promise<OrderPage> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const { records, total } = await this.repository.list({
      brandId: query.brandId,
      branchId: query.branchId,
      status: query.status,
      customerId,
      page,
      limit,
    });
    return {
      data: records.map(toOrderEntity),
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getById(id: string): Promise<OrderEntity> {
    const record = await this.repository.findById(id);
    if (!record) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${id} not found`,
      });
    }
    return toOrderEntity(record);
  }

  /**
   * Create an order (BE-907 atomic operation). Prices, names and totals are
   * resolved on the server from the catalog — client-supplied prices are
   * never trusted. When the request is authenticated as a guest, the order
   * is bound to that customer. After the transaction commits, background
   * processing is scheduled on the 'order-processing' BullMQ queue.
   */
  async create(dto: CreateOrderDto, customerId?: string): Promise<OrderEntity> {
    const menuItemIds = dto.items.map((item) => item.menuItemId);
    const modifierIds = dto.items.flatMap(
      (item) => item.modifiers?.map((modifier) => modifier.modifierItemId) ?? [],
    );

    const menuItems = await this.prisma.menuItem.findMany({
      where: {
        id: { in: menuItemIds },
        brandId: dto.brandId,
        deletedAt: null,
        status: ProductStatus.PUBLISHED,
      },
      include: {
        prices: { where: { branchId: dto.branchId } },
      },
    });
    const menuItemById = new Map(menuItems.map((item) => [item.id, item]));

    const modifiers = modifierIds.length
      ? await this.prisma.modifierItem.findMany({
          where: { id: { in: modifierIds }, deletedAt: null, isActive: true },
        })
      : [];
    const modifierById = new Map(modifiers.map((item) => [item.id, item]));

    // Validate all lines before writing anything.
    for (const item of dto.items) {
      if (!menuItemById.has(item.menuItemId)) {
        throw new BadRequestException({
          statusCode: 400,
          code: 'PRODUCT_UNAVAILABLE',
          message: `Menu item ${item.menuItemId} is not available`,
        });
      }
      for (const modifier of item.modifiers ?? []) {
        if (!modifierById.has(modifier.modifierItemId)) {
          throw new BadRequestException({
            statusCode: 400,
            code: 'PRODUCT_UNAVAILABLE',
            message: `Modifier ${modifier.modifierItemId} is not available`,
          });
        }
      }
    }

    const sequence = await this.repository.nextOrderSequence(dto.branchId);
    const orderNumber = this.formatOrderNumber(dto.branchId, sequence);

    const itemInputs = dto.items.map((item) => {
      const menuItem = menuItemById.get(item.menuItemId)!;
      const unitPrice = menuItem.prices[0]?.price ?? menuItem.basePrice;
      const pricedModifiers = (item.modifiers ?? []).map((modifier) => {
        const record = modifierById.get(modifier.modifierItemId)!;
        return {
          modifierItemId: record.id,
          name: record.name,
          priceDelta: record.price,
          quantity: modifier.quantity ?? 1,
        };
      });
      const total = lineTotal({
        unitPrice,
        quantity: item.quantity,
        modifiers: pricedModifiers,
      });
      return {
        menuItem: { connect: { id: item.menuItemId } },
        name: menuItem.name,
        quantity: item.quantity,
        unitPrice,
        totalAmount: total,
        comment: item.comment ?? null,
        modifiers: { create: pricedModifiers },
      };
    });

    const subtotal = orderSubtotal(
      itemInputs.map((item) => ({
        unitPrice: item.unitPrice,
        quantity: item.quantity,
        modifiers: item.modifiers.create,
      })),
    );
    const total = orderTotal(subtotal);

    const record = await this.repository.create({
      orderNumber,
      type: dto.type,
      status: OrderStatus.NEW,
      brand: { connect: { id: dto.brandId } },
      branch: { connect: { id: dto.branchId } },
      ...(customerId ? { customer: { connect: { id: customerId } } } : {}),
      tableNumber: dto.tableNumber ?? null,
      deliveryAddress: dto.deliveryAddress ?? null,
      comment: dto.comment ?? null,
      subtotalAmount: subtotal,
      totalAmount: total,
      items: { create: itemInputs },
    });

    await this.queues.scheduleOrderProcessing(record.id);
    return toOrderEntity(record);
  }

  /**
   * Operator / POS / kitchen driven status change. Validates the state
   * machine (400 INVALID_ORDER_STATUS_TRANSITION on illegal moves) and
   * appends to order_status_history atomically (BE-907, DB-608).
   */
  async updateStatus(id: string, dto: UpdateOrderStatusDto): Promise<OrderEntity> {
    const record = await this.repository.findById(id);
    if (!record) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${id} not found`,
      });
    }

    try {
      assertTransition(record.status, dto.status);
    } catch (error) {
      if (error instanceof InvalidOrderStatusTransitionError) {
        throw new BadRequestException({
          statusCode: 400,
          code: 'INVALID_ORDER_STATUS_TRANSITION',
          message: error.message,
        });
      }
      throw error;
    }

    const updated = await this.repository.transitionStatus(
      id,
      record.status,
      dto.status,
      dto.changedBy,
      dto.reason,
    );
    return toOrderEntity(updated);
  }

  private formatOrderNumber(branchId: string, sequence: number): string {
    const now = new Date();
    const yyyymmdd = [
      now.getUTCFullYear(),
      String(now.getUTCMonth() + 1).padStart(2, '0'),
      String(now.getUTCDate()).padStart(2, '0'),
    ].join('');
    const branchPrefix = branchId.slice(0, 4).toUpperCase();
    return `${branchPrefix}-${yyyymmdd}-${String(sequence + 1).padStart(4, '0')}`;
  }
}

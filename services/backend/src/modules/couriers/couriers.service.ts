import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderStatus, OrderType } from '@prisma/client';
import { CourierPinAuthDto } from './dto/courier-auth.dto';

@Injectable()
export class CouriersService {
  constructor(private readonly prisma: PrismaService) {}

  async authenticateByPin(dto: CourierPinAuthDto) {
    let courier = await this.prisma.courier.findUnique({
      where: { phone: dto.phone },
    });

    if (!courier) {
      const defaultBranch = await this.prisma.branch.findFirst();
      const defaultBrand = await this.prisma.brand.findFirst();

      if (!defaultBranch || !defaultBrand) {
        throw new UnauthorizedException('Branch or Brand configuration is missing');
      }

      courier = await this.prisma.courier.create({
        data: {
          name: 'Курьер ' + dto.phone.slice(-4),
          phone: dto.phone,
          pinHash: dto.pin,
          brandId: defaultBrand.id,
          branchId: defaultBranch.id,
        },
      });
    } else if (courier.pinHash !== dto.pin) {
      throw new UnauthorizedException('Invalid PIN code');
    }

    return {
      token: `courier-session-${courier.id}`,
      courier: {
        id: courier.id,
        name: courier.name,
        phone: courier.phone,
      },
    };
  }

  async getActiveOrders(branchId?: string, courierId?: string) {
    const where: any = {
      type: OrderType.DELIVERY,
      status: {
        in: [OrderStatus.COOKING, OrderStatus.READY, OrderStatus.ON_WAY],
      },
    };

    if (branchId) {
      where.branchId = branchId;
    }

    if (courierId) {
      where.OR = [{ courierId: null }, { courierId }];
    }

    const orders = await this.prisma.order.findMany({
      where,
      include: {
        customer: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return orders.map((order) => ({
      id: order.id,
      number: order.orderNumber,
      status: order.status,
      type: order.type,
      totalRubles: Math.round(Number(order.totalAmount)),
      paymentMethod: 'onlinePaid',
      address: {
        street: order.deliveryAddress || 'Адрес не указан',
      },
      clientPhone: order.customer?.phone || '',
      clientComment: order.comment,
      branchId: order.branchId,
      courierId: order.courierId,
      createdAt: order.createdAt.toISOString(),
    }));
  }
}

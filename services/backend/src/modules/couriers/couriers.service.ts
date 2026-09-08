import { createHash, timingSafeEqual } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { Courier, OrderStatus, OrderType } from '@prisma/client';
import { CourierPinAuthDto } from './dto/courier-auth.dto';
import { COURIER_TOKEN_TTL_SECONDS, PIN_BCRYPT_ROUNDS } from './couriers.config';
import { CourierTokenPayload } from './couriers.types';

/** bcrypt hashes carry a version prefix ($2a$/$2b$/$2y$); anything else is a legacy plaintext row. */
function isBcryptHash(value: string): boolean {
  return /^\$2[aby]\$/.test(value);
}

@Injectable()
export class CouriersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

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
          pinHash: await bcrypt.hash(dto.pin, PIN_BCRYPT_ROUNDS),
          brandId: defaultBrand.id,
          branchId: defaultBranch.id,
        },
      });
    } else if (!(await this.verifyPin(courier, dto.pin))) {
      throw new UnauthorizedException('Invalid PIN code');
    }

    const payload: CourierTokenPayload = {
      sub: courier.id,
      phone: courier.phone,
      branchId: courier.branchId,
      role: 'COURIER',
      type: 'access',
    };
    const token = await this.jwt.signAsync(payload, {
      expiresIn: COURIER_TOKEN_TTL_SECONDS,
    });

    return {
      token,
      tokenType: 'Bearer',
      expiresInSeconds: COURIER_TOKEN_TTL_SECONDS,
      courier: {
        id: courier.id,
        name: courier.name,
        phone: courier.phone,
      },
    };
  }

  /**
   * bcrypt comparison for current hashes. Legacy plaintext rows (written before
   * hashing landed) are checked constant-time via SHA-256 digests and
   * transparently re-hashed to bcrypt on the first successful login.
   */
  private async verifyPin(courier: Courier, pin: string): Promise<boolean> {
    if (isBcryptHash(courier.pinHash)) {
      return bcrypt.compare(pin, courier.pinHash);
    }

    const digest = (value: string) => createHash('sha256').update(value).digest();
    if (!timingSafeEqual(digest(pin), digest(courier.pinHash))) {
      return false;
    }

    const pinHash = await bcrypt.hash(pin, PIN_BCRYPT_ROUNDS);
    await this.prisma.courier.update({
      where: { id: courier.id },
      data: { pinHash },
    });
    return true;
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

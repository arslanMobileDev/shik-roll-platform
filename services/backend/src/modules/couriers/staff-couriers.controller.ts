import {
  Body, Controller, Delete, ExecutionContext, ForbiddenException, Get,
  HttpCode, Injectable, NotFoundException, ConflictException, Param, ParseUUIDPipe,
  Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../prisma/prisma.service';
import { StaffJwtAuthGuard } from '../staff/guards/staff-jwt-auth.guard';
import { CurrentStaff } from '../staff/decorators/current-staff.decorator';
import { AuthenticatedStaff } from '../staff/staff.types';
import { CourierBranchQueryDto, CreateCourierDto, UpdateCourierDto } from './staff-couriers.dto';
import { restoreCutoff } from './couriers.service';

@Injectable()
export class CourierStaffAuthGuard extends StaffJwtAuthGuard {
  constructor(jwt: JwtService, prisma: PrismaService) { super(jwt, prisma); }
  override async canActivate(context: ExecutionContext): Promise<boolean> {
    await super.canActivate(context);
    const { staff } = context.switchToHttp().getRequest<{ staff: AuthenticatedStaff }>();
    if (staff.role !== 'OWNER' && staff.role !== 'DEVELOPER') {
      throw new ForbiddenException('Owner or developer access required');
    }
    return true;
  }
}

const courierSelect = {
  id: true, name: true, phone: true, branchId: true,
  isActive: true, isAvailable: true, createdAt: true,
  // The "Удалённые" tab sorts and dates the burn from this, and a live row
  // answers null for it — one select for both lists.
  deletedAt: true,
} satisfies Prisma.CourierSelect;

@ApiTags('staff-couriers')
@ApiBearerAuth()
@UseGuards(CourierStaffAuthGuard)
@Controller('staff/couriers')
export class StaffCouriersController {
  constructor(private readonly prisma: PrismaService) {}

  private async assertBranch(staff: AuthenticatedStaff, branchId: string) {
    const branch = await this.prisma.branch.findFirst({
      where: { id: branchId, deletedAt: null, brandBranches: { some: { brandId: staff.brandId } } },
      select: { id: true, tenantId: true },
    });
    if (!branch) throw new NotFoundException({ code: 'BRANCH_NOT_FOUND', message: 'Branch not found in staff brand' });
    return branch;
  }

  @Get()
  async list(@CurrentStaff() staff: AuthenticatedStaff, @Query() query: CourierBranchQueryDto) {
    await this.assertBranch(staff, query.branchId);
    return this.prisma.courier.findMany({
      // Self-deleted couriers keep their row (orders reference it), so they are
      // not gone — they are the other half of the list. Either-or on purpose:
      // mixing them in would put an account nobody can log into next to a
      // working one, with only deletedAt to tell them apart.
      where: {
        brandId: staff.brandId,
        branchId: query.branchId,
        ...(query.includeDeleted ? { deletedAt: { not: null } } : { deletedAt: null }),
      },
      select: courierSelect, orderBy: [{ name: 'asc' }, { id: 'asc' }],
    });
  }

  @Post()
  @HttpCode(200)
  async create(@CurrentStaff() staff: AuthenticatedStaff, @Body() dto: CreateCourierDto) {
    const branch = await this.assertBranch(staff, dto.branchId);
    try {
      return await this.prisma.courier.create({
        data: { name: dto.name, phone: dto.phone, pinHash: await bcrypt.hash(dto.pin, 12),
          brandId: staff.brandId, branchId: dto.branchId, tenantId: branch.tenantId },
        select: courierSelect,
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException({ code: 'COURIER_PHONE_EXISTS', message: 'Phone is already registered' });
      }
      throw error;
    }
  }

  @Patch(':id')
  async update(@CurrentStaff() staff: AuthenticatedStaff, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCourierDto) {
    const courier = await this.prisma.courier.findFirst({
      where: { id, brandId: staff.brandId }, select: { branchId: true },
    });
    if (!courier) throw new NotFoundException({ code: 'COURIER_NOT_FOUND', message: 'Courier not found' });
    await this.assertBranch(staff, courier.branchId);
    const data: Prisma.CourierUpdateManyMutationInput = {
      ...(dto.name !== undefined ? { name: dto.name } : {}),
      ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      ...(dto.pin !== undefined ? { pinHash: await bcrypt.hash(dto.pin, 12) } : {}),
    };
    // Preserve isAvailable and assignment state, including when blocking a busy courier.
    return this.prisma.$transaction(async tx => {
      const result = await tx.courier.updateMany({ where: { id, brandId: staff.brandId }, data });
      if (!result.count) throw new NotFoundException('Courier not found');
      return tx.courier.findFirstOrThrow({ where: { id, brandId: staff.brandId }, select: courierSelect });
    });
  }

  /**
   * Hands a self-deleted account back from the panel, for the courier who
   * cannot do it himself (lost the PIN, or asks the owner instead).
   *
   * Inverse of the courier-facing POST /couriers/auth/restore and deliberately
   * without its PIN check: the caller is an authenticated owner, not an
   * anonymous holder of a phone number, so there is no credential to prove and
   * no PIN oracle to throttle.
   */
  @Post(':id/restore')
  @HttpCode(200)
  async restore(@CurrentStaff() staff: AuthenticatedStaff, @Param('id', ParseUUIDPipe) id: string) {
    let count: number;
    try {
      ({ count } = await this.prisma.courier.updateMany({
        // The window predicate and the phone check ride on the write itself,
        // like the courier-facing restore: a row that raced the expiry sweep,
        // or a row the pre-window deletion left without a number and with a
        // randomized PIN, must not come back — reviving it would produce an
        // account nobody can log into, presented as a success.
        where: {
          id,
          brandId: staff.brandId,
          deletedAt: { gt: restoreCutoff() },
          phone: { not: null },
        },
        data: { deletedAt: null, isActive: true },
      }));
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        // Reachable: the partial unique index lets a live courier hold the
        // number this deleted row still has, so restoring it would leave two
        // live rows on one number — the state the login lookup cannot survive.
        // The database is the guard; the panel gets an answer, not a 500.
        throw new ConflictException({
          statusCode: 409,
          code: 'COURIER_PHONE_EXISTS',
          message: 'Phone is already registered',
        });
      }
      throw error;
    }
    // One answer for "no such courier", "already live", "outside the window"
    // and "no number to log in with": the panel does the same thing in all four
    // cases, and naming them apart would only report which ids exist.
    if (!count) {
      throw new NotFoundException({ code: 'COURIER_NOT_FOUND', message: 'Courier not found' });
    }
    return this.prisma.courier.findFirstOrThrow({
      where: { id, brandId: staff.brandId }, select: courierSelect,
    });
  }

  @Delete(':id')
  remove(@CurrentStaff() staff: AuthenticatedStaff, @Param('id', ParseUUIDPipe) id: string) {
    return this.update(staff, id, { isActive: false });
  }
}

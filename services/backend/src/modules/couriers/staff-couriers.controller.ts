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
      select: { id: true },
    });
    if (!branch) throw new NotFoundException({ code: 'BRANCH_NOT_FOUND', message: 'Branch not found in staff brand' });
  }

  @Get()
  async list(@CurrentStaff() staff: AuthenticatedStaff, @Query() query: CourierBranchQueryDto) {
    await this.assertBranch(staff, query.branchId);
    return this.prisma.courier.findMany({
      where: { brandId: staff.brandId, branchId: query.branchId },
      select: courierSelect, orderBy: [{ name: 'asc' }, { id: 'asc' }],
    });
  }

  @Post()
  @HttpCode(200)
  async create(@CurrentStaff() staff: AuthenticatedStaff, @Body() dto: CreateCourierDto) {
    await this.assertBranch(staff, dto.branchId);
    try {
      return await this.prisma.courier.create({
        data: { name: dto.name, phone: dto.phone, pinHash: await bcrypt.hash(dto.pin, 12),
          brandId: staff.brandId, branchId: dto.branchId },
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

  @Delete(':id')
  remove(@CurrentStaff() staff: AuthenticatedStaff, @Param('id', ParseUUIDPipe) id: string) {
    return this.update(staff, id, { isActive: false });
  }
}

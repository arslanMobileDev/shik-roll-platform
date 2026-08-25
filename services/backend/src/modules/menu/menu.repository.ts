import { Injectable } from '@nestjs/common';
import { MenuItemPrice, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CategoryQueryDto } from './dto/category-query.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { MenuItemQueryDto } from './dto/menu-item-query.dto';
import { MenuQueryDto } from './dto/menu-query.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import { CategoryRecord } from './mappers/category.mapper';
import { buildMenuItemInclude, HALAL_CODE, MenuItemRecord } from './mappers/menu-item.mapper';
import { MenuRecord } from './mappers/menu.mapper';

export interface Paginated<T> {
  rows: T[];
  total: number;
}

const ACTIVE_HALAL_FILTER: Prisma.MenuItemWhereInput = {
  certifications: {
    some: {
      tag: { code: HALAL_CODE, deletedAt: null },
      AND: [
        { OR: [{ validFrom: null }, { validFrom: { lte: new Date() } }] },
        { OR: [{ validUntil: null }, { validUntil: { gt: new Date() } }] },
      ],
    },
  },
};

/**
 * Repository pattern (ADR-1607): every catalog query goes through Prisma
 * here; the service layer contains no data-access code.
 */
@Injectable()
export class MenuRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findMenus(query: MenuQueryDto): Promise<Paginated<MenuRecord>> {
    const where: Prisma.MenuWhereInput = {
      deletedAt: null,
      ...(query.brandId ? { brandId: query.brandId } : {}),
      // Branch context also matches the brand-level default menu (branchId NULL).
      ...(query.branchId
        ? { OR: [{ branchId: query.branchId }, { branchId: null }] }
        : {}),
    };
    const include = { _count: { select: { categories: true } } };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.menu.findMany({
        where,
        include,
        orderBy: [{ createdAt: 'asc' }],
        skip: (query.page! - 1) * query.limit!,
        take: query.limit,
      }),
      this.prisma.menu.count({ where }),
    ]);
    return { rows: rows as MenuRecord[], total };
  }

  async findCategories(query: CategoryQueryDto): Promise<Paginated<CategoryRecord>> {
    const where: Prisma.CategoryWhereInput = {
      deletedAt: null,
      isActive: true,
      ...(query.menuId ? { menuId: query.menuId } : {}),
      ...(query.brandId ? { brandId: query.brandId } : {}),
    };
    const include = { _count: { select: { items: true } } };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.category.findMany({
        where,
        include,
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
        skip: (query.page! - 1) * query.limit!,
        take: query.limit,
      }),
      this.prisma.category.count({ where }),
    ]);
    return { rows: rows as CategoryRecord[], total };
  }

  async findItems(query: MenuItemQueryDto): Promise<Paginated<MenuItemRecord>> {
    const now = new Date();
    const where: Prisma.MenuItemWhereInput = {
      deletedAt: null,
      isActive: true,
      ...(query.brandId ? { brandId: query.brandId } : {}),
      ...(query.categoryId ? { categoryId: query.categoryId } : {}),
      ...(query.search
        ? {
            OR: ['name', 'sku', 'description'].map((field) => ({
              [field]: { contains: query.search, mode: 'insensitive' as const },
            })),
          }
        : {}),
      ...(query.isHalal ? ACTIVE_HALAL_FILTER : {}),
    };

    if (query.availableOnly && query.branchId) {
      const branchId = query.branchId;
      where.AND = [
        // No per-branch row means "available" (default); a false row excludes.
        {
          OR: [
            { availability: { none: { branchId } } },
            { availability: { some: { branchId, isAvailable: true } } },
          ],
        },
        {
          NOT: {
            stopList: {
              some: {
                branchId,
                isActive: true,
                startsAt: { lte: now },
                OR: [{ endsAt: null }, { endsAt: { gt: now } }],
              },
            },
          },
        },
      ];
    }

    const include = buildMenuItemInclude(query.branchId);
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.menuItem.findMany({
        where,
        include,
        orderBy: [{ name: 'asc' }],
        skip: (query.page! - 1) * query.limit!,
        take: query.limit,
      }),
      this.prisma.menuItem.count({ where }),
    ]);
    return { rows: rows as MenuItemRecord[], total };
  }

  async findItemById(id: string, branchId?: string): Promise<MenuItemRecord | null> {
    const row = await this.prisma.menuItem.findFirst({
      where: { id, deletedAt: null },
      include: buildMenuItemInclude(branchId),
    });
    return row as MenuItemRecord | null;
  }

  findMenuById(id: string) {
    return this.prisma.menu.findFirst({ where: { id, deletedAt: null } });
  }

  findCategoryById(id: string) {
    return this.prisma.category.findFirst({ where: { id, deletedAt: null } });
  }

  findBranchById(id: string) {
    return this.prisma.branch.findFirst({ where: { id, deletedAt: null } });
  }

  findMenuItemById(id: string) {
    return this.prisma.menuItem.findFirst({ where: { id, deletedAt: null } });
  }

  async createCategory(dto: CreateCategoryDto, brandId: string): Promise<CategoryRecord> {
    const row = await this.prisma.category.create({
      data: {
        brandId,
        menuId: dto.menuId,
        parentId: dto.parentId ?? null,
        name: dto.name,
        description: dto.description ?? null,
        imageUrl: dto.imageUrl ?? null,
        sortOrder: dto.sortOrder ?? 0,
        isActive: dto.isActive ?? false,
      },
      include: { _count: { select: { items: true } } },
    });
    return row as CategoryRecord;
  }

  async updateCategory(id: string, dto: UpdateCategoryDto): Promise<CategoryRecord> {
    const row = await this.prisma.category.update({
      where: { id },
      data: {
        ...(dto.parentId !== undefined ? { parentId: dto.parentId } : {}),
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.description !== undefined ? { description: dto.description } : {}),
        ...(dto.imageUrl !== undefined ? { imageUrl: dto.imageUrl } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        version: { increment: 1 },
      },
      include: { _count: { select: { items: true } } },
    });
    return row as CategoryRecord;
  }

  createMenuItem(dto: CreateMenuItemDto, brandId: string, slug: string) {
    return this.prisma.menuItem.create({
      data: {
        brandId,
        categoryId: dto.categoryId,
        sku: dto.sku,
        name: dto.name,
        slug,
        description: dto.description ?? null,
        basePrice: dto.basePrice,
        currency: dto.currency ?? 'RUB',
        weight: dto.weight ?? null,
        calories: dto.calories ?? null,
        preparationTime: dto.preparationTime ?? null,
        isFeatured: dto.isFeatured ?? false,
        isActive: dto.isActive ?? false,
        ...(dto.ingredients
          ? {
              ingredients: {
                create: dto.ingredients.map((ingredient, index) => ({
                  ingredientId: ingredient.ingredientId,
                  quantity: ingredient.quantity ?? null,
                  unit: ingredient.unit ?? null,
                  isOptional: ingredient.isOptional ?? false,
                  sortOrder: ingredient.sortOrder ?? index,
                })),
              },
            }
          : {}),
        ...(dto.modifierGroupIds
          ? {
              modifierGroups: {
                create: dto.modifierGroupIds.map((modifierGroupId, index) => ({
                  modifierGroupId,
                  sortOrder: index,
                })),
              },
            }
          : {}),
        ...(dto.certificationTagIds
          ? {
              certifications: {
                create: dto.certificationTagIds.map((tagId) => ({ tagId })),
              },
            }
          : {}),
      },
    });
  }

  updateMenuItem(id: string, dto: UpdateMenuItemDto, slug?: string) {
    return this.prisma.menuItem.update({
      where: { id },
      data: {
        ...(dto.categoryId !== undefined ? { categoryId: dto.categoryId } : {}),
        ...(dto.sku !== undefined ? { sku: dto.sku } : {}),
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(slug !== undefined ? { slug } : {}),
        ...(dto.description !== undefined ? { description: dto.description } : {}),
        ...(dto.basePrice !== undefined ? { basePrice: dto.basePrice } : {}),
        ...(dto.currency !== undefined ? { currency: dto.currency } : {}),
        ...(dto.weight !== undefined ? { weight: dto.weight } : {}),
        ...(dto.calories !== undefined ? { calories: dto.calories } : {}),
        ...(dto.preparationTime !== undefined
          ? { preparationTime: dto.preparationTime }
          : {}),
        ...(dto.isFeatured !== undefined ? { isFeatured: dto.isFeatured } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        version: { increment: 1 },
      },
    });
  }

  async upsertPrice(
    menuItemId: string,
    branchId: string,
    price: number,
    currency: string,
  ): Promise<MenuItemPrice> {
    const existing = await this.prisma.menuItemPrice.findUnique({
      where: { menuItemId_branchId: { menuItemId, branchId } },
    });
    return this.prisma.menuItemPrice.upsert({
      where: { menuItemId_branchId: { menuItemId, branchId } },
      create: { menuItemId, branchId, price, oldPrice: null, currency },
      update: {
        price,
        oldPrice: existing ? existing.price : null,
        currency,
        validFrom: new Date(),
        version: { increment: 1 },
      },
    });
  }

  upsertAvailability(menuItemId: string, branchId: string, isAvailable: boolean) {
    return this.prisma.branchMenuItemAvailability.upsert({
      where: { branchId_menuItemId: { branchId, menuItemId } },
      create: { branchId, menuItemId, isAvailable },
      update: { isAvailable },
    });
  }

  upsertStopList(menuItemId: string, branchId: string, isActive: boolean, reason?: string) {
    return this.prisma.stopListEntry.upsert({
      where: { menuItemId_branchId: { menuItemId, branchId } },
      create: {
        menuItemId,
        branchId,
        isActive,
        reason: reason ?? null,
        endsAt: isActive ? null : new Date(),
      },
      update: {
        isActive,
        ...(reason !== undefined ? { reason } : {}),
        ...(isActive ? { startsAt: new Date(), endsAt: null } : { endsAt: new Date() }),
        version: { increment: 1 },
      },
    });
  }

  /** Walks up the tree to prove that `parentId` is not `id` or its descendant. */
  async isCategoryCycle(id: string, parentId: string): Promise<boolean> {
    let current: string | null = parentId;
    for (let depth = 0; current !== null && depth < 32; depth += 1) {
      if (current === id) return true;
      const parent: { parentId: string | null } | null =
        await this.prisma.category.findUnique({
          where: { id: current },
          select: { parentId: true },
        });
      current = parent?.parentId ?? null;
    }
    return false;
  }
}

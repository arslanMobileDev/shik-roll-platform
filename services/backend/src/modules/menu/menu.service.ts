import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { MenuItemQueryDto } from './dto/menu-item-query.dto';
import { MenuQueryDto } from './dto/menu-query.dto';
import { CategoryQueryDto } from './dto/category-query.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import { UpdatePriceDto } from './dto/update-price.dto';
import { UpdateStopListDto } from './dto/update-stop-list.dto';
import { CategoryEntity, CategoryPage } from './entities/category.entity';
import { MenuEntity, MenuPage } from './entities/menu.entity';
import { MenuItemEntity, MenuItemPage } from './entities/menu-item.entity';
import { PageMeta } from './entities/pagination.entity';
import { MenuRepository } from './menu.repository';
import { toCategoryEntity } from './mappers/category.mapper';
import { toMenuEntity } from './mappers/menu.mapper';
import { slugify, toMenuItemEntity } from './mappers/menu-item.mapper';

/** API-706 error codes. */
function notFound(code: string, message: string): NotFoundException {
  return new NotFoundException({ statusCode: 404, code, message });
}

function badRequest(code: string, message: string): BadRequestException {
  return new BadRequestException({ statusCode: 400, code, message });
}

function pageMeta(page: number, limit: number, total: number): PageMeta {
  return { page, limit, total, totalPages: Math.max(1, Math.ceil(total / limit)) };
}

@Injectable()
export class MenuService {
  constructor(private readonly repository: MenuRepository) {}

  async getMenus(query: MenuQueryDto): Promise<MenuPage> {
    const { rows, total } = await this.repository.findMenus(query);
    return {
      data: rows.map(toMenuEntity),
      meta: pageMeta(query.page!, query.limit!, total),
    };
  }

  async getCategories(query: CategoryQueryDto): Promise<CategoryPage> {
    const { rows, total } = await this.repository.findCategories(query);
    return {
      data: rows.map(toCategoryEntity),
      meta: pageMeta(query.page!, query.limit!, total),
    };
  }

  async getItems(query: MenuItemQueryDto): Promise<MenuItemPage> {
    const { rows, total } = await this.repository.findItems(query);
    return {
      data: rows.map((row) => toMenuItemEntity(row, query.branchId)),
      meta: pageMeta(query.page!, query.limit!, total),
    };
  }

  async getItemById(id: string, branchId?: string): Promise<MenuItemEntity> {
    const record = await this.repository.findItemById(id, branchId);
    if (!record) {
      throw notFound('PRODUCT_NOT_FOUND', `Menu item ${id} not found`);
    }
    return toMenuItemEntity(record, branchId);
  }

  async createCategory(dto: CreateCategoryDto): Promise<CategoryEntity> {
    const menu = await this.repository.findMenuById(dto.menuId);
    if (!menu) {
      throw notFound('MENU_NOT_FOUND', `Menu ${dto.menuId} not found`);
    }
    if (dto.parentId) {
      await this.assertCategoryExists(dto.parentId);
    }
    const record = await this.repository.createCategory(dto, menu.brandId);
    return toCategoryEntity(record);
  }

  async updateCategory(id: string, dto: UpdateCategoryDto): Promise<CategoryEntity> {
    await this.assertCategoryExists(id);
    if (dto.parentId) {
      await this.assertCategoryExists(dto.parentId);
      if (await this.repository.isCategoryCycle(id, dto.parentId)) {
        throw badRequest(
          'VALIDATION_ERROR',
          'parentId must not be the category itself or its descendant',
        );
      }
    }
    const record = await this.repository.updateCategory(id, dto);
    return toCategoryEntity(record);
  }

  async createMenuItem(dto: CreateMenuItemDto): Promise<MenuItemEntity> {
    const category = await this.repository.findCategoryById(dto.categoryId);
    if (!category) {
      throw notFound('CATEGORY_NOT_FOUND', `Category ${dto.categoryId} not found`);
    }
    const slug = dto.slug ?? slugify(dto.name, dto.sku.toLowerCase());
    const created = await this.repository.createMenuItem(dto, category.brandId, slug);
    return this.getItemById(created.id);
  }

  async updateMenuItem(id: string, dto: UpdateMenuItemDto): Promise<MenuItemEntity> {
    const item = await this.repository.findMenuItemById(id);
    if (!item) {
      throw notFound('PRODUCT_NOT_FOUND', `Menu item ${id} not found`);
    }
    if (dto.categoryId) {
      await this.assertCategoryExists(dto.categoryId);
    }
    let slug = dto.slug;
    if (slug === undefined && dto.name !== undefined && dto.slug === undefined) {
      // Regenerate the slug only when the name changes and no slug was supplied.
      slug = slugify(dto.name, (dto.sku ?? item.sku).toLowerCase());
    }
    await this.repository.updateMenuItem(id, dto, slug);
    return this.getItemById(id);
  }

  async updatePrice(id: string, dto: UpdatePriceDto): Promise<MenuItemEntity> {
    const item = await this.repository.findMenuItemById(id);
    if (!item) {
      throw notFound('PRODUCT_NOT_FOUND', `Menu item ${id} not found`);
    }
    if (dto.price < 0) {
      throw badRequest('INVALID_PRICE', 'price must be zero or positive');
    }
    await this.assertBranchExists(dto.branchId);
    await this.repository.upsertPrice(
      id,
      dto.branchId,
      dto.price,
      dto.currency ?? 'RUB',
    );
    return this.getItemById(id, dto.branchId);
  }

  async updateAvailability(id: string, dto: UpdateAvailabilityDto): Promise<MenuItemEntity> {
    const item = await this.repository.findMenuItemById(id);
    if (!item) {
      throw notFound('PRODUCT_NOT_FOUND', `Menu item ${id} not found`);
    }
    await this.assertBranchExists(dto.branchId);
    await this.repository.upsertAvailability(id, dto.branchId, dto.isAvailable);
    return this.getItemById(id, dto.branchId);
  }

  async updateStopList(id: string, dto: UpdateStopListDto): Promise<MenuItemEntity> {
    const item = await this.repository.findMenuItemById(id);
    if (!item) {
      throw notFound('PRODUCT_NOT_FOUND', `Menu item ${id} not found`);
    }
    await this.assertBranchExists(dto.branchId);
    await this.repository.upsertStopList(id, dto.branchId, dto.isActive, dto.reason);
    return this.getItemById(id, dto.branchId);
  }

  private async assertCategoryExists(id: string): Promise<void> {
    if (!(await this.repository.findCategoryById(id))) {
      throw notFound('CATEGORY_NOT_FOUND', `Category ${id} not found`);
    }
  }

  private async assertBranchExists(id: string): Promise<void> {
    if (!(await this.repository.findBranchById(id))) {
      throw notFound('BRANCH_NOT_FOUND', `Branch ${id} not found`);
    }
  }
}

export type { MenuEntity, MenuItemEntity };

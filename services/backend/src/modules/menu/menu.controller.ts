import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CategoryQueryDto } from './dto/category-query.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { MenuItemQueryDto } from './dto/menu-item-query.dto';
import { MenuQueryDto } from './dto/menu-query.dto';
import { ReorderDto } from './dto/reorder.dto';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import { UpdateMerchandisingDto } from './dto/update-merchandising.dto';
import { UpdatePriceDto } from './dto/update-price.dto';
import { UpdateProductStatusDto } from './dto/update-product-status.dto';
import { UpdateStopListDto } from './dto/update-stop-list.dto';
import { CategoryEntity, CategoryPage } from './entities/category.entity';
import { MenuPage } from './entities/menu.entity';
import { MenuItemEntity, MenuItemPage } from './entities/menu-item.entity';
import { MenuService } from './menu.service';

@Controller()
export class MenuController {
  constructor(private readonly service: MenuService) {}

  @Get('menus')
  @ApiTags('menus')
  @ApiOperation({ summary: 'List menus (brand / branch filtered, paginated)' })
  @ApiOkResponse({ type: MenuPage })
  getMenus(@Query() query: MenuQueryDto): Promise<MenuPage> {
    return this.service.getMenus(query);
  }

  @Get('categories')
  @ApiTags('categories')
  @ApiOperation({ summary: 'List categories (menu / brand filtered, paginated)' })
  @ApiOkResponse({ type: CategoryPage })
  getCategories(@Query() query: CategoryQueryDto): Promise<CategoryPage> {
    return this.service.getCategories(query);
  }

  @Post('categories')
  @ApiTags('categories')
  @ApiOperation({ summary: 'Create a category' })
  @ApiOkResponse({ type: CategoryEntity })
  createCategory(@Body() dto: CreateCategoryDto): Promise<CategoryEntity> {
    return this.service.createCategory(dto);
  }

  @Patch('categories/order')
  @ApiTags('categories')
  @ApiOperation({ summary: 'Reorder categories inside a menu (index becomes sort_order)' })
  @ApiQuery({ name: 'menuId', required: true, type: String })
  @ApiOkResponse({ schema: { properties: { updated: { type: 'number' } } } })
  reorderCategories(
    @Query('menuId', ParseUUIDPipe) menuId: string,
    @Body() dto: ReorderDto,
  ): Promise<{ updated: number }> {
    return this.service.reorderCategories(menuId, dto);
  }

  @Patch('categories/:id')
  @ApiTags('categories')
  @ApiOperation({ summary: 'Update a category' })
  @ApiOkResponse({ type: CategoryEntity })
  updateCategory(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCategoryDto,
  ): Promise<CategoryEntity> {
    return this.service.updateCategory(id, dto);
  }

  @Patch('categories/:id/products/order')
  @ApiTags('categories')
  @ApiOperation({ summary: 'Reorder products inside a category (index becomes sort_order)' })
  @ApiOkResponse({ schema: { properties: { updated: { type: 'number' } } } })
  reorderCategoryProducts(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReorderDto,
  ): Promise<{ updated: number }> {
    return this.service.reorderCategoryProducts(id, dto);
  }

  @Get('menu-items')
  @ApiTags('menu-items')
  @ApiOperation({
    summary:
      'List menu items with brand/branch/category filters, Halal filter, ' +
      'availability filter, search and pagination',
  })
  @ApiOkResponse({ type: MenuItemPage })
  getItems(@Query() query: MenuItemQueryDto): Promise<MenuItemPage> {
    return this.service.getItems(query);
  }

  @Get('menu-items/:id')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Get a menu item; branchId resolves branch price, availability and stop list' })
  @ApiQuery({ name: 'branchId', required: false, type: String })
  @ApiOkResponse({ type: MenuItemEntity })
  getItemById(
    @Param('id', ParseUUIDPipe) id: string,
    @Query('branchId') branchId?: string,
  ): Promise<MenuItemEntity> {
    return this.service.getItemById(id, branchId);
  }

  @Post('menu-items')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Create a menu item (composition, modifier groups, certifications)' })
  @ApiOkResponse({ type: MenuItemEntity })
  createMenuItem(@Body() dto: CreateMenuItemDto): Promise<MenuItemEntity> {
    return this.service.createMenuItem(dto);
  }

  @Patch('menu-items/:id')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Update scalar fields of a menu item' })
  @ApiOkResponse({ type: MenuItemEntity })
  updateMenuItem(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMenuItemDto,
  ): Promise<MenuItemEntity> {
    return this.service.updateMenuItem(id, dto);
  }

  @Patch('menu-items/:id/status')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Change the product lifecycle status (DRAFT/PUBLISHED/HIDDEN)' })
  @ApiOkResponse({ type: MenuItemEntity })
  updateItemStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProductStatusDto,
  ): Promise<MenuItemEntity> {
    return this.service.updateItemStatus(id, dto);
  }

  @Patch('menu-items/:id/merchandising')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Update manual merchandising flags (popular / new / featured)' })
  @ApiOkResponse({ type: MenuItemEntity })
  updateMerchandising(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMerchandisingDto,
  ): Promise<MenuItemEntity> {
    return this.service.updateMerchandising(id, dto);
  }

  @Delete('menu-items/:id')
  @ApiTags('menu-items')
  @HttpCode(200)
  @ApiOperation({ summary: 'Archive a product (lifecycle → ARCHIVED)' })
  @ApiOkResponse({ type: MenuItemEntity })
  archiveMenuItem(@Param('id', ParseUUIDPipe) id: string): Promise<MenuItemEntity> {
    return this.service.archiveMenuItem(id);
  }

  @Patch('menu-items/:id/price')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Set or replace the branch price override' })
  @ApiOkResponse({ type: MenuItemEntity })
  updatePrice(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePriceDto,
  ): Promise<MenuItemEntity> {
    return this.service.updatePrice(id, dto);
  }

  @Patch('menu-items/:id/availability')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Enable or disable the item at a branch' })
  @ApiOkResponse({ type: MenuItemEntity })
  updateAvailability(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAvailabilityDto,
  ): Promise<MenuItemEntity> {
    return this.service.updateAvailability(id, dto);
  }

  @Patch('menu-items/:id/stop-list')
  @ApiTags('menu-items')
  @ApiOperation({ summary: 'Add the item to or remove it from the branch stop list' })
  @ApiOkResponse({ type: MenuItemEntity })
  updateStopList(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateStopListDto,
  ): Promise<MenuItemEntity> {
    return this.service.updateStopList(id, dto);
  }
}

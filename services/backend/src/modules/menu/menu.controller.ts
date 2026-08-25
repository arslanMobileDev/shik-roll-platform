import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CategoryQueryDto } from './dto/category-query.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { MenuItemQueryDto } from './dto/menu-item-query.dto';
import { MenuQueryDto } from './dto/menu-query.dto';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import { UpdatePriceDto } from './dto/update-price.dto';
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

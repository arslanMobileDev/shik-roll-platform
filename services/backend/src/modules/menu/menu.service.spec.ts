import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { MenuService } from './menu.service';
import { MenuRepository } from './menu.repository';
import { slugify, toMenuItemEntity, MenuItemRecord } from './mappers/menu-item.mapper';

const D = (value: number | string) => new Prisma.Decimal(value);

function makeRecord(overrides: Partial<MenuItemRecord> = {}): MenuItemRecord {
  const base = {
    id: '11111111-1111-1111-1111-111111111111',
    brandId: '22222222-2222-2222-2222-222222222222',
    categoryId: '33333333-3333-3333-3333-333333333333',
    sku: 'ROLL-001',
    name: 'Филадельфия',
    slug: 'filadelfija',
    description: null,
    weight: null,
    calories: null,
    preparationTime: null,
    isFeatured: false,
    isActive: true,
    basePrice: D('400.00'),
    currency: 'RUB',
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    deletedAt: null,
    createdBy: null,
    updatedBy: null,
    version: 1,
    category: { id: '33333333-3333-3333-3333-333333333333', name: 'Роллы', menuId: 'm1' },
    ingredients: [],
    certifications: [],
    prices: [],
    availability: [],
    stopList: [],
    modifierGroups: [],
  };
  return { ...base, ...overrides } as unknown as MenuItemRecord;
}

describe('toMenuItemEntity', () => {
  it('uses the base price when no branch override exists', () => {
    const entity = toMenuItemEntity(makeRecord());
    expect(entity.price).toEqual({ base: 400, branch: null, effective: 400, currency: 'RUB' });
    expect(entity.available).toBe(true);
    expect(entity.stopList.isActive).toBe(false);
  });

  it('resolves the branch price override (branch price override rule)', () => {
    const entity = toMenuItemEntity(
      makeRecord({
        prices: [
          {
            id: 'p1',
            menuItemId: '11111111-1111-1111-1111-111111111111',
            branchId: 'b1',
            price: D('450.50'),
            oldPrice: D('400.00'),
            currency: 'RUB',
            validFrom: new Date(),
            validTo: null,
            createdAt: new Date(),
            updatedAt: new Date(),
            version: 1,
          },
        ],
      } as Partial<MenuItemRecord>),
    );
    expect(entity.price.base).toBe(400);
    expect(entity.price.branch).toBe(450.5);
    expect(entity.price.effective).toBe(450.5);
  });

  it('marks valid HALAL certification as isHalal', () => {
    const halal = {
      id: 'c1',
      menuItemId: 'x',
      tagId: 't1',
      certificateNumber: null,
      issuedBy: null,
      validFrom: null,
      validUntil: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      tag: {
        id: 't1', code: 'HALAL', name: 'Halal', description: null, icon: null,
        createdAt: new Date(), updatedAt: new Date(), deletedAt: null,
        createdBy: null, updatedBy: null, version: 1,
      },
    };
    expect(toMenuItemEntity(makeRecord({ certifications: [halal] } as Partial<MenuItemRecord>)).isHalal).toBe(true);

    const expired = { ...halal, validUntil: new Date('2020-01-01T00:00:00Z') };
    expect(toMenuItemEntity(makeRecord({ certifications: [expired] } as Partial<MenuItemRecord>)).isHalal).toBe(false);
  });

  it('reports active stop list within the time window and blocks availability', () => {
    const entry = {
      id: 's1', menuItemId: 'x', branchId: 'b1', reason: 'Нет лосося',
      startsAt: new Date('2026-01-01T00:00:00Z'), endsAt: null, isActive: true,
      createdAt: new Date(), updatedAt: new Date(), version: 1,
    };
    const entity = toMenuItemEntity(makeRecord({ stopList: [entry] } as Partial<MenuItemRecord>));
    expect(entity.stopList.isActive).toBe(true);
    expect(entity.stopList.reason).toBe('Нет лосося');
    expect(entity.available).toBe(false);

    const future = { ...entry, startsAt: new Date(Date.now() + 3_600_000) };
    const futureEntity = toMenuItemEntity(makeRecord({ stopList: [future] } as Partial<MenuItemRecord>));
    expect(futureEntity.stopList.isActive).toBe(false);
    expect(futureEntity.available).toBe(true);
  });

  it('resolves per-branch availability: missing row means available, false row blocks', () => {
    const row = {
      id: 'a1', branchId: 'b1', menuItemId: 'x', isAvailable: false,
      createdAt: new Date(), updatedAt: new Date(),
    };
    const entity = toMenuItemEntity(makeRecord({ availability: [row] } as Partial<MenuItemRecord>));
    expect(entity.availability.isAvailable).toBe(false);
    expect(entity.available).toBe(false);
  });

  it('maps the modifier group tree with active items only', () => {
    const link = {
      id: 'l1', menuItemId: 'x', modifierGroupId: 'g1', sortOrder: 0,
      createdAt: new Date(), updatedAt: new Date(),
      modifierGroup: {
        id: 'g1', brandId: 'b', name: 'Размер', selectionType: 'SINGLE', minSelected: 1,
        maxSelected: 1, isRequired: true, sortOrder: 0,
        createdAt: new Date(), updatedAt: new Date(), deletedAt: null,
        createdBy: null, updatedBy: null, version: 1,
        items: [
          { id: 'm2', groupId: 'g1', name: 'L', price: D('80.00'), currency: 'RUB', calories: null, isActive: true, sortOrder: 1, createdAt: new Date(), updatedAt: new Date(), deletedAt: null, createdBy: null, updatedBy: null, version: 1 },
          { id: 'm1', groupId: 'g1', name: 'M', price: D('0.00'), currency: 'RUB', calories: null, isActive: true, sortOrder: 0, createdAt: new Date(), updatedAt: new Date(), deletedAt: null, createdBy: null, updatedBy: null, version: 1 },
        ],
      },
    };
    const entity = toMenuItemEntity(makeRecord({ modifierGroups: [link] } as Partial<MenuItemRecord>));
    expect(entity.modifierGroups).toHaveLength(1);
    expect(entity.modifierGroups[0].selectionType).toBe('SINGLE');
    expect(entity.modifierGroups[0].items.map((i) => i.name)).toEqual(['M', 'L']);
    expect(entity.modifierGroups[0].items[1].price).toBe(80);
  });

  it('maps composition ingredients with unit fallback to the ingredient default', () => {
    const row = {
      id: 'i1', menuItemId: 'x', ingredientId: 'ing1', quantity: D('50'), unit: null,
      isOptional: false, sortOrder: 0, createdAt: new Date(), updatedAt: new Date(),
      ingredient: {
        id: 'ing1', brandId: 'b', name: 'Рис', unit: 'g', isActive: true,
        createdAt: new Date(), updatedAt: new Date(), deletedAt: null,
        createdBy: null, updatedBy: null, version: 1,
      },
    };
    const entity = toMenuItemEntity(makeRecord({ ingredients: [row] } as Partial<MenuItemRecord>));
    expect(entity.ingredients[0]).toMatchObject({ name: 'Рис', quantity: 50, unit: 'g' });
  });
});

describe('slugify', () => {
  it('transliterates Cyrillic names to kebab-case', () => {
    expect(slugify('Филадельфия Делюкс', 'sku')).toBe('filadelfiya-deluks');
    expect(slugify('Ролл "Цезарь" 350 г', 'sku')).toBe('roll-cezar-350-g');
  });

  it('falls back to the SKU when the name has no latin content', () => {
    expect(slugify('お寿司', 'roll-001')).toBe('roll-001');
  });
});

describe('MenuService', () => {
  let service: MenuService;
  let repository: jest.Mocked<MenuRepository>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MenuService,
        {
          provide: MenuRepository,
          useValue: {
            findMenus: jest.fn(),
            findCategories: jest.fn(),
            findItems: jest.fn(),
            findItemById: jest.fn(),
            findMenuById: jest.fn(),
            findCategoryById: jest.fn(),
            findBranchById: jest.fn(),
            findMenuItemById: jest.fn(),
            createCategory: jest.fn(),
            updateCategory: jest.fn(),
            createMenuItem: jest.fn(),
            updateMenuItem: jest.fn(),
            upsertPrice: jest.fn(),
            upsertAvailability: jest.fn(),
            upsertStopList: jest.fn(),
            isCategoryCycle: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(MenuService);
    repository = module.get(MenuRepository);
  });

  it('paginates menu items and maps entities', async () => {
    repository.findItems.mockResolvedValue({ rows: [makeRecord()], total: 25 });
    const page = await service.getItems({ page: 2, limit: 10 });
    expect(page.meta).toEqual({ page: 2, limit: 10, total: 25, totalPages: 3 });
    expect(page.data[0].name).toBe('Филадельфия');
  });

  it('throws PRODUCT_NOT_FOUND for an unknown item', async () => {
    repository.findItemById.mockResolvedValue(null);
    await expect(service.getItemById('missing')).rejects.toMatchObject({
      response: { code: 'PRODUCT_NOT_FOUND' },
    });
  });

  it('throws MENU_NOT_FOUND when creating a category in a missing menu', async () => {
    repository.findMenuById.mockResolvedValue(null);
    await expect(
      service.createCategory({ menuId: 'no-menu', name: 'Роллы' }),
    ).rejects.toMatchObject({ response: { code: 'MENU_NOT_FOUND' } });
  });

  it('rejects a category parent cycle with VALIDATION_ERROR', async () => {
    repository.findCategoryById.mockResolvedValue({ id: 'c1' } as never);
    repository.isCategoryCycle.mockResolvedValue(true);
    await expect(
      service.updateCategory('c1', { parentId: 'c2' }),
    ).rejects.toMatchObject({ response: { code: 'VALIDATION_ERROR' } });
  });

  it('throws INVALID_PRICE for a negative branch price', async () => {
    repository.findMenuItemById.mockResolvedValue({ id: 'i1' } as never);
    await expect(
      service.updatePrice('i1', { branchId: 'b1', price: -5 }),
    ).rejects.toMatchObject({ response: { code: 'INVALID_PRICE' } });
    expect(repository.upsertPrice).not.toHaveBeenCalled();
  });

  it('throws BRANCH_NOT_FOUND when the branch does not exist', async () => {
    repository.findMenuItemById.mockResolvedValue({ id: 'i1' } as never);
    repository.findBranchById.mockResolvedValue(null);
    await expect(
      service.updateAvailability('i1', { branchId: 'bX', isAvailable: false }),
    ).rejects.toMatchObject({ response: { code: 'BRANCH_NOT_FOUND' } });
  });

  it('upserts the branch price and returns the branch-resolved entity', async () => {
    repository.findMenuItemById.mockResolvedValue({ id: 'i1' } as never);
    repository.findBranchById.mockResolvedValue({ id: 'b1' } as never);
    repository.upsertPrice.mockResolvedValue({} as never);
    repository.findItemById.mockResolvedValue(
      makeRecord({
        prices: [
          {
            id: 'p1', menuItemId: 'i1', branchId: 'b1', price: D('450.50'), oldPrice: D('400'),
            currency: 'RUB', validFrom: new Date(), validTo: null,
            createdAt: new Date(), updatedAt: new Date(), version: 1,
          },
        ],
      } as Partial<MenuItemRecord>),
    );

    const entity = await service.updatePrice('i1', { branchId: 'b1', price: 450.5 });
    expect(repository.upsertPrice).toHaveBeenCalledWith('i1', 'b1', 450.5, 'RUB');
    expect(repository.findItemById).toHaveBeenCalledWith('i1', 'b1');
    expect(entity.price.effective).toBe(450.5);
  });

  it('upserts stop list entries with a reason', async () => {
    repository.findMenuItemById.mockResolvedValue({ id: 'i1' } as never);
    repository.findBranchById.mockResolvedValue({ id: 'b1' } as never);
    repository.upsertStopList.mockResolvedValue({} as never);
    repository.findItemById.mockResolvedValue(makeRecord());

    await service.updateStopList('i1', { branchId: 'b1', isActive: true, reason: 'Нет лосося' });
    expect(repository.upsertStopList).toHaveBeenCalledWith('i1', 'b1', true, 'Нет лосося');
  });

  it('throws CATEGORY_NOT_FOUND when creating an item in a missing category', async () => {
    repository.findCategoryById.mockResolvedValue(null);
    await expect(
      service.createMenuItem({ categoryId: 'no', sku: 'S1', name: 'Ролл', basePrice: 100 }),
    ).rejects.toMatchObject({ response: { code: 'CATEGORY_NOT_FOUND' } });
  });

  it('derives brandId from the category when creating an item (tenant consistency)', async () => {
    repository.findCategoryById.mockResolvedValue({ id: 'c1', brandId: 'brand-A' } as never);
    repository.createMenuItem.mockResolvedValue({ id: 'i1' } as never);
    repository.findItemById.mockResolvedValue(makeRecord());

    await service.createMenuItem({ categoryId: 'c1', sku: 'S1', name: 'Ролл', basePrice: 100 });
    expect(repository.createMenuItem).toHaveBeenCalledWith(
      expect.objectContaining({ sku: 'S1' }),
      'brand-A',
      'roll',
    );
  });

  it('regenerates the slug from a new name on PATCH', async () => {
    repository.findMenuItemById.mockResolvedValue({ id: 'i1', sku: 'R-1' } as never);
    repository.updateMenuItem.mockResolvedValue({} as never);
    repository.findItemById.mockResolvedValue(makeRecord());

    await service.updateMenuItem('i1', { name: 'Калифорния' });
    expect(repository.updateMenuItem).toHaveBeenCalledWith(
      'i1',
      expect.objectContaining({ name: 'Калифорния' }),
      'kaliforniya',
    );
  });

  it('does not regenerate the slug when the name is unchanged', async () => {
    repository.findMenuItemById.mockResolvedValue({ id: 'i1', sku: 'R-1' } as never);
    repository.updateMenuItem.mockResolvedValue({} as never);
    repository.findItemById.mockResolvedValue(makeRecord());

    await service.updateMenuItem('i1', { description: 'новое описание' });
    expect(repository.updateMenuItem).toHaveBeenCalledWith(
      'i1',
      expect.objectContaining({ description: 'новое описание' }),
      undefined,
    );
  });
});

describe('error code helpers', () => {
  it('notFound errors carry API-706 codes', async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [MenuService, { provide: MenuRepository, useValue: { findItemById: jest.fn().mockResolvedValue(null) } }],
    }).compile();
    const svc = moduleRef.get(MenuService);
    try {
      await svc.getItemById('x');
      fail('should throw');
    } catch (error) {
      expect(error).toBeInstanceOf(NotFoundException);
    }
  });

  it('badRequest is a BadRequestException', () => {
    expect(new BadRequestException({ code: 'VALIDATION_ERROR' })).toBeInstanceOf(BadRequestException);
  });
});

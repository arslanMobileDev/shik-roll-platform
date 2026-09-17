import { ValidationPipe } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MenuRepository } from './menu.repository';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';

const input = { categoryId: '33333333-3333-4333-8333-333333333333', sku: 'TEST', name: 'Тест', basePrice: 100 };

describe('MenuRepository image and allergens', () => {
  const create = jest.fn().mockResolvedValue({});
  const update = jest.fn().mockResolvedValue({});
  const repository = new MenuRepository({ menuItem: { create, update } } as unknown as PrismaService);
  beforeEach(() => jest.clearAllMocks());

  it('passes both fields to Prisma create', async () => {
    await repository.createMenuItem({ ...input, imageUrl: '/uploads/menu/a.webp', allergens: 'Соя' }, { brandId: 'brand', menuId: 'menu' }, 'test');
    expect(create).toHaveBeenCalledWith({ data: expect.objectContaining({ imageUrl: '/uploads/menu/a.webp', allergens: 'Соя' }) });
  });

  it('creates nullable defaults when omitted', async () => {
    await repository.createMenuItem(input, { brandId: 'brand', menuId: 'menu' }, 'test');
    expect(create).toHaveBeenCalledWith({ data: expect.objectContaining({ imageUrl: null, allergens: null }) });
  });

  it.each(['imageUrl', 'allergens'] as const)('updates %s without changing the other field', async (field) => {
    await repository.updateMenuItem('item', { [field]: 'value' });
    expect(update).toHaveBeenCalledWith({ where: { id: 'item' }, data: { [field]: 'value', version: { increment: 1 } } });
  });

  it.each(['imageUrl', 'allergens'] as const)('allows clearing %s explicitly', async (field) => {
    await repository.updateMenuItem('item', { [field]: null });
    expect(update).toHaveBeenCalledWith({ where: { id: 'item' }, data: { [field]: null, version: { increment: 1 } } });
  });
});

describe('Menu image and allergen DTO validation', () => {
  const pipe = new ValidationPipe({ transform: true, whitelist: true });
  for (const metatype of [CreateMenuItemDto, UpdateMenuItemDto]) {
    for (const field of ['imageUrl', 'allergens']) {
      it(`${metatype.name}: ${field} accepts 500 and rejects 501 characters with HTTP 400`, async () => {
        await expect(pipe.transform({ ...input, [field]: 'a'.repeat(500) }, { type: 'body', metatype })).resolves.toHaveProperty(field);
        await expect(pipe.transform({ ...input, [field]: 'a'.repeat(501) }, { type: 'body', metatype })).rejects.toMatchObject({ status: 400 });
      });
      it(`${metatype.name}: ${field} rejects a non-string`, async () => {
        await expect(pipe.transform({ ...input, [field]: 123 }, { type: 'body', metatype })).rejects.toMatchObject({ status: 400 });
      });
    }
  }
});

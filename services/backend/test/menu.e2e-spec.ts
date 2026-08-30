import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { INestApplication, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/**
 * E2E coverage of the package acceptance criteria:
 *   - multi-brand isolation;
 *   - Halal filter;
 *   - branch price override;
 *   - stop lists;
 *   - modifier tree;
 *   - GET /menu-items?brandId&branchId response structure.
 *
 * Runs against a dedicated database (DATABASE_URL_TEST). The schema is applied
 * with `prisma migrate deploy` and all rows are deleted via the Prisma client
 * before the suite — a destructive `migrate reset` is intentionally avoided.
 */

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';

// The application's PrismaService picks up DATABASE_URL at instantiation.
process.env.DATABASE_URL = TEST_DATABASE_URL;

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

/** Clears every catalog table in FK-safe order using the Prisma client only. */
async function truncateAll(): Promise<void> {
  await prisma.menuItemModifierGroup.deleteMany();
  await prisma.modifierItem.deleteMany();
  await prisma.modifierGroup.deleteMany();
  await prisma.stopListEntry.deleteMany();
  await prisma.branchMenuItemAvailability.deleteMany();
  await prisma.menuItemPrice.deleteMany();
  await prisma.menuItemCertification.deleteMany();
  await prisma.certificationTag.deleteMany();
  await prisma.menuItemIngredient.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.menuItem.deleteMany();
  await prisma.category.deleteMany();
  await prisma.menu.deleteMany();
  await prisma.brandBranch.deleteMany();
  await prisma.branch.deleteMany();
  await prisma.brand.deleteMany();
}

interface Fixture {
  brandA: string;
  brandB: string;
  menuA: string;
  branchA1: string;
  branchA2: string;
  branchB1: string;
  categoryRolls: string;
  categorySets: string;
  categoryB: string;
  itemHalalPriced: string; // halal, base 400, override 450.50 @ branchA1, modifiers
  itemStopListed: string; // stop-listed @ branchA1
  itemUnavailable: string; // halal, availability=false @ branchA1
  itemDraft: string; // DRAFT — not in the public catalog
  itemBrandB: string;
}

async function seedFixtures(): Promise<Fixture> {
  const brandA = await prisma.brand.create({ data: { code: 'SHIK_ROLL', name: 'SHIK ROLL' } });
  const brandB = await prisma.brand.create({ data: { code: 'OTHER_BRAND', name: 'Other Brand' } });

  const branchA1 = await prisma.branch.create({ data: { code: 'A-01', name: 'Branch A1' } });
  const branchA2 = await prisma.branch.create({ data: { code: 'A-02', name: 'Branch A2' } });
  const branchB1 = await prisma.branch.create({ data: { code: 'B-01', name: 'Branch B1' } });

  await prisma.brandBranch.createMany({
    data: [
      { brandId: brandA.id, branchId: branchA1.id },
      { brandId: brandA.id, branchId: branchA2.id },
      { brandId: brandB.id, branchId: branchB1.id },
    ],
  });

  const halal = await prisma.certificationTag.create({
    data: { code: 'HALAL', name: 'Halal' },
  });

  const menuA = await prisma.menu.create({
    data: { brandId: brandA.id, name: 'Main Menu', status: 'PUBLISHED', publishedAt: new Date() },
  });
  const menuB = await prisma.menu.create({
    data: { brandId: brandB.id, name: 'Other Menu', status: 'PUBLISHED', publishedAt: new Date() },
  });

  const categoryRolls = await prisma.category.create({
    data: { brandId: brandA.id, menuId: menuA.id, name: 'Роллы', sortOrder: 0, isActive: true },
  });
  const categorySets = await prisma.category.create({
    data: { brandId: brandA.id, menuId: menuA.id, name: 'Сеты', sortOrder: 1, isActive: true },
  });
  const categoryB = await prisma.category.create({
    data: { brandId: brandB.id, menuId: menuB.id, name: 'Burgers', sortOrder: 0, isActive: true },
  });

  const rice = await prisma.ingredient.create({
    data: { brandId: brandA.id, name: 'Рис', unit: 'g', isActive: true },
  });
  const salmon = await prisma.ingredient.create({
    data: { brandId: brandA.id, name: 'Лосось', unit: 'g', isActive: true },
  });

  const sizeGroup = await prisma.modifierGroup.create({
    data: {
      brandId: brandA.id,
      name: 'Размер',
      selectionType: 'SINGLE',
      minSelected: 1,
      maxSelected: 1,
      isRequired: true,
      items: {
        create: [
          { name: 'L', price: 80, isActive: true, sortOrder: 1 },
          { name: 'M', price: 0, isActive: true, sortOrder: 0 },
        ],
      },
    },
  });

  const itemHalalPriced = await prisma.menuItem.create({
    data: {
      brandId: brandA.id,
      menuId: menuA.id,
      categoryId: categoryRolls.id,
      sku: 'ROLL-001',
      name: 'Филадельфия',
      slug: 'filadelfiya',
      basePrice: 400,
      status: 'PUBLISHED',
      sortOrder: 1,
      publishedAt: new Date(),
      ingredients: {
        create: [
          { ingredientId: rice.id, quantity: 50, sortOrder: 0 },
          { ingredientId: salmon.id, quantity: 30, sortOrder: 1 },
        ],
      },
      certifications: { create: [{ tagId: halal.id }] },
      modifierGroups: { create: [{ modifierGroupId: sizeGroup.id, sortOrder: 0 }] },
    },
  });

  const itemStopListed = await prisma.menuItem.create({
    data: {
      brandId: brandA.id,
      menuId: menuA.id,
      categoryId: categoryRolls.id,
      sku: 'ROLL-002',
      name: 'Калифорния',
      slug: 'kaliforniya',
      basePrice: 300,
      status: 'PUBLISHED',
      sortOrder: 0,
      publishedAt: new Date(),
    },
  });

  const itemUnavailable = await prisma.menuItem.create({
    data: {
      brandId: brandA.id,
      menuId: menuA.id,
      categoryId: categorySets.id,
      sku: 'SET-001',
      name: 'Сет Сяке',
      slug: 'set-syake',
      basePrice: 900,
      status: 'PUBLISHED',
      publishedAt: new Date(),
      certifications: { create: [{ tagId: halal.id }] },
    },
  });

  const itemDraft = await prisma.menuItem.create({
    data: {
      brandId: brandA.id,
      menuId: menuA.id,
      categoryId: categoryRolls.id,
      sku: 'ROLL-003',
      name: 'Черновик',
      slug: 'chernovik',
      basePrice: 100,
      status: 'DRAFT',
    },
  });

  const itemBrandB = await prisma.menuItem.create({
    data: {
      brandId: brandB.id,
      menuId: menuB.id,
      categoryId: categoryB.id,
      sku: 'BRG-001',
      name: 'Cheeseburger',
      slug: 'cheeseburger',
      basePrice: 250,
      status: 'PUBLISHED',
      publishedAt: new Date(),
    },
  });

  // Branch A1: price override on item 1, stop list on item 2, unavailable item 3.
  await prisma.menuItemPrice.create({
    data: { menuItemId: itemHalalPriced.id, branchId: branchA1.id, price: 450.5 },
  });
  await prisma.stopListEntry.create({
    data: {
      menuItemId: itemStopListed.id,
      branchId: branchA1.id,
      isActive: true,
      reason: 'Нет крабовых палочек',
    },
  });
  await prisma.branchMenuItemAvailability.create({
    data: { branchId: branchA1.id, menuItemId: itemUnavailable.id, isAvailable: false },
  });

  return {
    brandA: brandA.id,
    brandB: brandB.id,
    menuA: menuA.id,
    branchA1: branchA1.id,
    branchA2: branchA2.id,
    branchB1: branchB1.id,
    categoryRolls: categoryRolls.id,
    categorySets: categorySets.id,
    categoryB: categoryB.id,
    itemHalalPriced: itemHalalPriced.id,
    itemStopListed: itemStopListed.id,
    itemUnavailable: itemUnavailable.id,
    itemDraft: itemDraft.id,
    itemBrandB: itemBrandB.id,
  };
}

describe('Menu & Product API (e2e)', () => {
  let app: INestApplication;
  let fx: Fixture;

  beforeAll(async () => {
    execSync('pnpm prisma migrate deploy', {
      cwd: path.resolve(__dirname, '..'),
      env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
      stdio: 'inherit',
    });
    await truncateAll();

    fx = await seedFixtures();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        exceptionFactory: (errors) =>
          new BadRequestException({
            statusCode: 400,
            code: 'VALIDATION_ERROR',
            message: errors
              .map((error) => Object.values(error.constraints ?? {}).join(', '))
              .filter(Boolean)
              .join('; '),
          }),
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
    await prisma.$disconnect();
  });

  const get = (url: string) => request(app.getHttpServer()).get(url);

  it('GET /menus returns menus filtered by brand', async () => {
    const res = await get(`/menus?brandId=${fx.brandA}`).expect(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({ brandId: fx.brandA, name: 'Main Menu', status: 'PUBLISHED' });
    expect(res.body.meta).toMatchObject({ page: 1, limit: 20, total: 1 });
  });

  it('GET /categories returns categories of the brand menu with item counts', async () => {
    const res = await get(`/categories?brandId=${fx.brandA}`).expect(200);
    expect(res.body.data.map((c: { name: string }) => c.name)).toEqual(['Роллы', 'Сеты']);
    expect(res.body.data[0].itemCount).toBe(2);
  });

  it('multi-brand isolation: brand A never sees brand B items', async () => {
    const resA = await get(`/menu-items?brandId=${fx.brandA}`).expect(200);
    expect(resA.body.meta.total).toBe(3);
    expect(resA.body.data.every((i: { brandId: string }) => i.brandId === fx.brandA)).toBe(true);

    const resB = await get(`/menu-items?brandId=${fx.brandB}`).expect(200);
    expect(resB.body.meta.total).toBe(1);
    expect(resB.body.data[0].name).toBe('Cheeseburger');
  });

  it('Halal filter returns only items with a valid HALAL tag', async () => {
    const res = await get(`/menu-items?brandId=${fx.brandA}&isHalal=true`).expect(200);
    expect(res.body.meta.total).toBe(2);
    expect(res.body.data.every((i: { isHalal: boolean }) => i.isHalal)).toBe(true);
    expect(res.body.data.map((i: { name: string }) => i.name).sort()).toEqual(['Сет Сяке', 'Филадельфия']);
  });

  it('branch price override: effective price = override for branchA1, base for branchA2', async () => {
    const res1 = await get(`/menu-items?brandId=${fx.brandA}&branchId=${fx.branchA1}`).expect(200);
    const priced = res1.body.data.find((i: { id: string }) => i.id === fx.itemHalalPriced);
    expect(priced.price).toEqual({ base: 400, branch: 450.5, effective: 450.5, currency: 'RUB' });

    const res2 = await get(`/menu-items?brandId=${fx.brandA}&branchId=${fx.branchA2}`).expect(200);
    const plain = res2.body.data.find((i: { id: string }) => i.id === fx.itemHalalPriced);
    expect(plain.price).toEqual({ base: 400, branch: null, effective: 400, currency: 'RUB' });
  });

  it('stop list status is exposed per branch and respected by availableOnly', async () => {
    const res = await get(`/menu-items?brandId=${fx.brandA}&branchId=${fx.branchA1}`).expect(200);
    const stopped = res.body.data.find((i: { id: string }) => i.id === fx.itemStopListed);
    expect(stopped.stopList).toMatchObject({ isActive: true, reason: 'Нет крабовых палочек' });
    expect(stopped.available).toBe(false);

    const avail = await get(
      `/menu-items?brandId=${fx.brandA}&branchId=${fx.branchA1}&availableOnly=true`,
    ).expect(200);
    const ids = avail.body.data.map((i: { id: string }) => i.id);
    expect(ids).toContain(fx.itemHalalPriced);
    expect(ids).not.toContain(fx.itemStopListed); // stop-listed
    expect(ids).not.toContain(fx.itemUnavailable); // availability = false
  });

  it('response structure: halal flag, ingredients, modifier tree, branch price, stop list', async () => {
    const res = await get(`/menu-items/${fx.itemHalalPriced}?branchId=${fx.branchA1}`).expect(200);
    const item = res.body;

    expect(item).toMatchObject({
      id: fx.itemHalalPriced,
      brandId: fx.brandA,
      sku: 'ROLL-001',
      isHalal: true,
      available: true,
      price: { base: 400, branch: 450.5, effective: 450.5, currency: 'RUB' },
      availability: { branchId: fx.branchA1, isAvailable: true },
      stopList: { isActive: false, reason: null, since: null },
      category: { id: fx.categoryRolls, name: 'Роллы' },
    });

    expect(item.ingredients).toEqual([
      expect.objectContaining({ name: 'Рис', quantity: 50, unit: 'g', sortOrder: 0 }),
      expect.objectContaining({ name: 'Лосось', quantity: 30, unit: 'g', sortOrder: 1 }),
    ]);

    expect(item.modifierGroups).toHaveLength(1);
    expect(item.modifierGroups[0]).toMatchObject({
      name: 'Размер',
      selectionType: 'SINGLE',
      minSelected: 1,
      maxSelected: 1,
      isRequired: true,
    });
    expect(item.modifierGroups[0].items).toEqual([
      expect.objectContaining({ name: 'M', price: 0, sortOrder: 0 }),
      expect.objectContaining({ name: 'L', price: 80, sortOrder: 1 }),
    ]);

    expect(item.certifications).toEqual([
      expect.objectContaining({ code: 'HALAL', name: 'Halal' }),
    ]);
  });

  it('search matches name case-insensitively and respects pagination', async () => {
    const res = await get(`/menu-items?brandId=${fx.brandA}&search=филадел`).expect(200);
    expect(res.body.meta.total).toBe(1);
    expect(res.body.data[0].name).toBe('Филадельфия');

    const page = await get(`/menu-items?brandId=${fx.brandA}&page=2&limit=2`).expect(200);
    expect(page.body.data).toHaveLength(1);
    expect(page.body.meta).toMatchObject({ page: 2, limit: 2, total: 3, totalPages: 2 });
  });

  it('GET /menu-items/:id returns 404 PRODUCT_NOT_FOUND for unknown id', async () => {
    const res = await get('/menu-items/00000000-0000-4000-8000-000000000000').expect(404);
    expect(res.body.code).toBe('PRODUCT_NOT_FOUND');
  });

  it('admin: PATCH price creates and replaces the branch override', async () => {
    await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemStopListed}/price`)
      .send({ branchId: fx.branchA2, price: 320 })
      .expect(200);

    let res = await get(`/menu-items/${fx.itemStopListed}?branchId=${fx.branchA2}`).expect(200);
    expect(res.body.price).toMatchObject({ base: 300, branch: 320, effective: 320 });

    await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemStopListed}/price`)
      .send({ branchId: fx.branchA2, price: 310 })
      .expect(200);

    res = await get(`/menu-items/${fx.itemStopListed}?branchId=${fx.branchA2}`).expect(200);
    expect(res.body.price.effective).toBe(310);

    const row = await prisma.menuItemPrice.findUnique({
      where: { menuItemId_branchId: { menuItemId: fx.itemStopListed, branchId: fx.branchA2 } },
    });
    expect(row?.oldPrice?.toNumber()).toBe(320); // previous price kept as old_price
  });

  it('admin: PATCH availability toggles the per-branch flag', async () => {
    await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemHalalPriced}/availability`)
      .send({ branchId: fx.branchA2, isAvailable: false })
      .expect(200);

    const res = await get(`/menu-items/${fx.itemHalalPriced}?branchId=${fx.branchA2}`).expect(200);
    expect(res.body.availability).toMatchObject({ branchId: fx.branchA2, isAvailable: false });
    expect(res.body.available).toBe(false);

    // Restore shared fixture state for the following tests.
    await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemHalalPriced}/availability`)
      .send({ branchId: fx.branchA2, isAvailable: true })
      .expect(200);
  });

  it('admin: PATCH stop-list adds and removes the item with a reason', async () => {
    await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemHalalPriced}/stop-list`)
      .send({ branchId: fx.branchA2, isActive: true, reason: 'Нет риса' })
      .expect(200);

    let res = await get(`/menu-items/${fx.itemHalalPriced}?branchId=${fx.branchA2}`).expect(200);
    expect(res.body.stopList).toMatchObject({ isActive: true, reason: 'Нет риса' });
    expect(res.body.available).toBe(false);

    await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemHalalPriced}/stop-list`)
      .send({ branchId: fx.branchA2, isActive: false })
      .expect(200);

    res = await get(`/menu-items/${fx.itemHalalPriced}?branchId=${fx.branchA2}`).expect(200);
    expect(res.body.stopList.isActive).toBe(false);
    expect(res.body.available).toBe(true);
  });

  it('admin: POST /menu-items validates input and reports VALIDATION_ERROR', async () => {
    const res = await request(app.getHttpServer())
      .post('/menu-items')
      .send({ categoryId: fx.categoryRolls, sku: 'X', name: 'X', basePrice: -10 })
      .expect(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
  });

  it('admin: POST /menu-items reports CATEGORY_NOT_FOUND for a bogus category', async () => {
    const res = await request(app.getHttpServer())
      .post('/menu-items')
      .send({
        categoryId: '00000000-0000-4000-8000-000000000000',
        sku: 'X-1',
        name: 'X',
        basePrice: 100,
      })
      .expect(404);
    expect(res.body.code).toBe('CATEGORY_NOT_FOUND');
  });

  it('admin: POST then PATCH /menu-items creates and updates an item', async () => {
    const created = await request(app.getHttpServer())
      .post('/menu-items')
      .send({
        categoryId: fx.categorySets,
        sku: 'SET-002',
        name: 'Сет Филадельфия',
        basePrice: 1200,
        isActive: true,
      })
      .expect(201);
    expect(created.body.slug).toBe('set-filadelfiya');
    expect(created.body.brandId).toBe(fx.brandA);

    const updated = await request(app.getHttpServer())
      .patch(`/menu-items/${created.body.id}`)
      .send({ basePrice: 1150, isFeatured: true })
      .expect(200);
    expect(updated.body.price.base).toBe(1150);
    expect(updated.body.isFeatured).toBe(true);
  });

  it('admin: POST then PATCH /categories creates and updates a category', async () => {
    const menus = await get(`/menus?brandId=${fx.brandA}`).expect(200);
    const menuId = menus.body.data[0].id;

    const created = await request(app.getHttpServer())
      .post('/categories')
      .send({ menuId, name: 'Напитки', sortOrder: 2, isActive: true })
      .expect(201);
    expect(created.body).toMatchObject({ name: 'Напитки', brandId: fx.brandA, menuId });

    const updated = await request(app.getHttpServer())
      .patch(`/categories/${created.body.id}`)
      .send({ sortOrder: 5 })
      .expect(200);
    expect(updated.body.sortOrder).toBe(5);
  });

  it('admin: PATCH /categories rejects a parent cycle', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/categories/${fx.categoryRolls}`)
      .send({ parentId: fx.categoryRolls })
      .expect(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
  });

  it('public catalog shows only PUBLISHED items (lifecycle gate)', async () => {
    const pub = await get(`/menu-items?brandId=${fx.brandA}`).expect(200);
    expect(pub.body.data.every((i: { status: string }) => i.status === 'PUBLISHED')).toBe(true);
    expect(pub.body.data.map((i: { id: string }) => i.id)).not.toContain(fx.itemDraft);

    // Scoped by search so DRAFT items created by other tests do not leak in.
    const drafts = await get(
      `/menu-items?brandId=${fx.brandA}&status=DRAFT&search=${encodeURIComponent('Черновик')}`,
    ).expect(200);
    expect(drafts.body.meta.total).toBe(1);
    expect(drafts.body.data[0]).toMatchObject({ id: fx.itemDraft, status: 'DRAFT' });

    const allDrafts = await get(`/menu-items?brandId=${fx.brandA}&status=DRAFT`).expect(200);
    expect(
      allDrafts.body.data.every((i: { status: string }) => i.status === 'DRAFT'),
    ).toBe(true);
  });

  it('lifecycle: DRAFT→PUBLISHED→HIDDEN→PUBLISHED; rejects invalid transitions', async () => {
    const publish = await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemDraft}/status`)
      .send({ status: 'PUBLISHED' })
      .expect(200);
    expect(publish.body.status).toBe('PUBLISHED');
    expect(publish.body.lifecycle.publishedAt).not.toBeNull();

    const invalid = await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemDraft}/status`)
      .send({ status: 'DRAFT' })
      .expect(400);
    expect(invalid.body.code).toBe('INVALID_PRODUCT_STATUS_TRANSITION');

    const hidden = await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemDraft}/status`)
      .send({ status: 'HIDDEN' })
      .expect(200);
    expect(hidden.body.status).toBe('HIDDEN');
    expect(hidden.body.lifecycle.hiddenAt).not.toBeNull();
    expect(hidden.body.available).toBe(false);

    const republished = await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemDraft}/status`)
      .send({ status: 'PUBLISHED' })
      .expect(200);
    expect(republished.body.status).toBe('PUBLISHED');
  });

  it('merchandising flags are independent manual toggles', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/menu-items/${fx.itemHalalPriced}/merchandising`)
      .send({ isPopular: true, isNew: true })
      .expect(200);
    expect(res.body).toMatchObject({ isPopular: true, isNew: true, isFeatured: false });
  });

  it('DELETE /menu-items/:id archives the product and excludes it from the catalog', async () => {
    const created = await request(app.getHttpServer())
      .post('/menu-items')
      .send({ categoryId: fx.categorySets, sku: 'SET-009', name: 'Архивный сет', basePrice: 500 })
      .expect(201);
    expect(created.body.status).toBe('DRAFT');

    const archived = await request(app.getHttpServer())
      .delete(`/menu-items/${created.body.id}`)
      .expect(200);
    expect(archived.body.status).toBe('ARCHIVED');
    expect(archived.body.lifecycle.archivedAt).not.toBeNull();
  });

  it('ordering: categories and products reorder by ids', async () => {
    const reordered = await request(app.getHttpServer())
      .patch(`/categories/order?menuId=${fx.menuA}`)
      .send({ ids: [fx.categorySets, fx.categoryRolls] })
      .expect(200);
    expect(reordered.body.updated).toBe(2);

    const cats = await get(`/categories?brandId=${fx.brandA}`).expect(200);
    // Other tests create extra categories in the same menu — assert the fixture pair's relative order.
    const fixtureOrder = cats.body.data
      .filter((c: { id: string }) => [fx.categorySets, fx.categoryRolls].includes(c.id))
      .map((c: { name: string }) => c.name);
    expect(fixtureOrder).toEqual(['Сеты', 'Роллы']);

    const prodOrder = await request(app.getHttpServer())
      .patch(`/categories/${fx.categoryRolls}/products/order`)
      .send({ ids: [fx.itemHalalPriced, fx.itemStopListed] })
      .expect(200);
    expect(prodOrder.body.updated).toBe(2);

    const items = await get(`/menu-items?brandId=${fx.brandA}&categoryId=${fx.categoryRolls}`).expect(200);
    expect(items.body.data[0].id).toBe(fx.itemHalalPriced);
  });
});

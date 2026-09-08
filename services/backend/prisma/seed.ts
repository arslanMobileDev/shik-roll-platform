/**
 * SHIK Platform — catalog seed (DB-607 scope).
 *
 * IMPORTANT: the approved SHIK ROLL menu (ТЗ) is not present in the repository
 * (assets/menu is empty). Per the package rules, compositions are NOT invented:
 * MANU items and their compositions stay empty until the approved menu is
 * provided. Only structural seed data is created here:
 *   - SHIK ROLL brand
 *   - one development branch and the brand↔branch link
 *   - an empty draft menu
 *   - the HALAL certification tag
 *
 * The seed is idempotent (upsert by unique keys) so `prisma db seed` and
 * `prisma migrate reset` can re-run safely.
 */
import * as bcrypt from 'bcryptjs';
import { PrismaClient, MenuStatus } from '@prisma/client';

const prisma = new PrismaClient();

const BRAND = {
  code: 'SHIK_ROLL',
  name: 'SHIK ROLL',
};

const DEV_BRANCH = {
  code: 'DEV-01',
  name: 'SHIK ROLL Dev Branch',
};

// Kitchen POS dev terminal (ADR-1618). Dev-only PIN; production terminals are
// provisioned by ops with per-terminal PINs, never through this seed.
const DEV_KITCHEN_TERMINAL = {
  code: 'KDS-01',
  name: 'Kitchen Terminal 1',
  pin: '1234',
};

const CERTIFICATION_TAGS = [
  {
    code: 'HALAL',
    name: 'Halal',
    description: 'Сертификация халяль',
    icon: null,
  },
];

const MENU = {
  name: 'Main Menu',
};

interface SeedMenuItem {
  sku: string;
  name: string;
  description?: string;
  basePrice: number;
  /** Compositions strictly per the approved ТЗ — never invented. */
  ingredients: { name: string; quantity?: number; unit?: string; isOptional?: boolean }[];
  isHalal?: boolean;
}

interface SeedCategory {
  name: string;
  description?: string;
  sortOrder: number;
  items: SeedMenuItem[];
}

/**
 * Approved menu content. Empty by design: no approved menu document exists in
 * the repository yet, and inventing items or compositions is prohibited.
 * Fill from the approved ТЗ when it is provided.
 */
const CATEGORIES: SeedCategory[] = [];

async function main() {
  const halalTags = new Map<string, string>();
  for (const tag of CERTIFICATION_TAGS) {
    const upserted = await prisma.certificationTag.upsert({
      where: { code: tag.code },
      update: { name: tag.name, description: tag.description, icon: tag.icon },
      create: tag,
    });
    halalTags.set(tag.code, upserted.id);
  }

  const brand = await prisma.brand.upsert({
    where: { code: BRAND.code },
    update: { name: BRAND.name },
    create: { code: BRAND.code, name: BRAND.name },
  });

  const branch = await prisma.branch.upsert({
    where: { code: DEV_BRANCH.code },
    update: { name: DEV_BRANCH.name },
    create: { code: DEV_BRANCH.code, name: DEV_BRANCH.name },
  });

  await prisma.brandBranch.upsert({
    where: { brandId_branchId: { brandId: brand.id, branchId: branch.id } },
    update: {},
    create: { brandId: brand.id, branchId: branch.id },
  });

  // Kitchen POS terminal (ADR-1618): the KDS app signs in as this terminal.
  await prisma.kitchenTerminal.upsert({
    where: { code: DEV_KITCHEN_TERMINAL.code },
    update: { name: DEV_KITCHEN_TERMINAL.name, branchId: branch.id, isActive: true },
    create: {
      code: DEV_KITCHEN_TERMINAL.code,
      name: DEV_KITCHEN_TERMINAL.name,
      pinHash: await bcrypt.hash(DEV_KITCHEN_TERMINAL.pin, 10),
      branchId: branch.id,
    },
  });

  const existingMenu = await prisma.menu.findFirst({
    where: { brandId: brand.id, name: MENU.name, deletedAt: null },
  });
  let menu = existingMenu;
  if (!menu) {
    menu = await prisma.menu.create({
      data: {
        brandId: brand.id,
        name: MENU.name,
        status: MenuStatus.DRAFT, // stays DRAFT until approved content is seeded
      },
    });
  }

  for (const category of CATEGORIES) {
    // Category/item seeding is data-driven; CATEGORIES is intentionally empty
    // until the approved SHIK ROLL menu (ТЗ) is available.
    const createdCategory = await prisma.category.create({
      data: {
        brandId: brand.id,
        menuId: menu.id,
        name: category.name,
        description: category.description ?? null,
        sortOrder: category.sortOrder,
        isActive: true,
      },
    });
    for (const item of category.items) {
      const createdItem = await prisma.menuItem.create({
        data: {
          brandId: brand.id,
          menuId: menu.id,
          categoryId: createdCategory.id,
          sku: item.sku,
          name: item.name,
          slug: item.sku.toLowerCase(),
          description: item.description ?? null,
          basePrice: item.basePrice,
          status: 'PUBLISHED',
        },
      });
      for (const [index, ingredient] of item.ingredients.entries()) {
        const ingredientRow = await prisma.ingredient.upsert({
          where: { brandId_name: { brandId: brand.id, name: ingredient.name } },
          update: {},
          create: {
            brandId: brand.id,
            name: ingredient.name,
            unit: ingredient.unit ?? 'g',
            isActive: true,
          },
        });
        await prisma.menuItemIngredient.create({
          data: {
            menuItemId: createdItem.id,
            ingredientId: ingredientRow.id,
            quantity: ingredient.quantity ?? null,
            unit: ingredient.unit ?? null,
            isOptional: ingredient.isOptional ?? false,
            sortOrder: index,
          },
        });
      }
      if (item.isHalal) {
        const halalId = halalTags.get('HALAL');
        if (halalId) {
          await prisma.menuItemCertification.create({
            data: { menuItemId: createdItem.id, tagId: halalId },
          });
        }
      }
    }
  }

  const counts = {
    brands: await prisma.brand.count(),
    branches: await prisma.branch.count(),
    menus: await prisma.menu.count(),
    categories: await prisma.category.count(),
    menuItems: await prisma.menuItem.count(),
    certificationTags: await prisma.certificationTag.count(),
    kitchenTerminals: await prisma.kitchenTerminal.count(),
  };
  console.log('Seed finished:', counts);
}

main()
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

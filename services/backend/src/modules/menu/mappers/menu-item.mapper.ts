import { Prisma } from '@prisma/client';
import {
  CertificationEntity,
  MenuItemEntity,
  MenuItemIngredientEntity,
} from '../entities/menu-item.entity';
import { ModifierGroupEntity } from '../entities/modifier-group.entity';

/** HALAL is resolved through certification tags (generic replacement of halal_labels, DB-607). */
export const HALAL_CODE = 'HALAL';

/**
 * Branch context is resolved against a guaranteed-empty id when no branchId
 * is passed, keeping the include shape (and the generated type) stable.
 */
const NO_BRANCH = '00000000-0000-0000-0000-000000000000';

export function buildMenuItemInclude(branchId?: string) {
  const branchWhere = { branchId: branchId ?? NO_BRANCH };
  return {
    category: { select: { id: true, name: true, menuId: true } },
    ingredients: {
      orderBy: { sortOrder: 'asc' as const },
      include: { ingredient: true },
    },
    certifications: { include: { tag: true } },
    modifierGroups: {
      orderBy: { sortOrder: 'asc' as const },
      include: {
        modifierGroup: {
          include: {
            items: {
              where: { isActive: true, deletedAt: null },
              orderBy: { sortOrder: 'asc' as const },
            },
          },
        },
      },
    },
    prices: { where: branchWhere },
    availability: { where: branchWhere },
    stopList: { where: { ...branchWhere, isActive: true } },
  } satisfies Prisma.MenuItemInclude;
}

export type MenuItemRecord = Prisma.MenuItemGetPayload<{
  include: ReturnType<typeof buildMenuItemInclude>;
}>;

function dec(value: Prisma.Decimal | null | undefined): number | null {
  if (value === null || value === undefined) return null;
  return value.toNumber();
}

function iso(value: Date | null | undefined): string | null {
  return value ? value.toISOString() : null;
}

function isCertificationValid(
  certification: Pick<
    MenuItemRecord['certifications'][number],
    'validFrom' | 'validUntil'
  >,
  now: Date,
): boolean {
  if (certification.validFrom && certification.validFrom > now) return false;
  if (certification.validUntil && certification.validUntil <= now) return false;
  return true;
}

export function toModifierGroupEntity(
  link: MenuItemRecord['modifierGroups'][number],
): ModifierGroupEntity {
  const group = link.modifierGroup;
  return {
    id: group.id,
    name: group.name,
    selectionType: group.selectionType,
    minSelected: group.minSelected,
    maxSelected: group.maxSelected,
    isRequired: group.isRequired,
    sortOrder: link.sortOrder,
    items: [...group.items]
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((item) => ({
        id: item.id,
        name: item.name,
        price: item.price.toNumber(),
        currency: item.currency,
        calories: item.calories,
        sortOrder: item.sortOrder,
      })),
  };
}

export function toMenuItemEntity(record: MenuItemRecord, branchId?: string): MenuItemEntity {
  const now = new Date();

  const branchOverride = record.prices[0] ?? null;
  const availabilityRow = record.availability[0] ?? null;
  const stopEntry = record.stopList.find(
    (entry) =>
      entry.startsAt <= now && (entry.endsAt === null || entry.endsAt > now),
  );

  const certifications: CertificationEntity[] = record.certifications.map(
    (certification) => ({
      tagId: certification.tagId,
      code: certification.tag.code,
      name: certification.tag.name,
      certificateNumber: certification.certificateNumber,
      validUntil: iso(certification.validUntil),
    }),
  );

  const isHalal = record.certifications.some(
    (certification) =>
      certification.tag.code === HALAL_CODE &&
      certification.tag.deletedAt === null &&
      isCertificationValid(certification, now),
  );

  const ingredients: MenuItemIngredientEntity[] = record.ingredients.map(
    (row) => ({
      ingredientId: row.ingredientId,
      name: row.ingredient.name,
      quantity: dec(row.quantity),
      unit: row.unit ?? row.ingredient.unit,
      isOptional: row.isOptional,
      sortOrder: row.sortOrder,
    }),
  );

  const base = record.basePrice.toNumber();
  const branch = branchOverride ? branchOverride.price.toNumber() : null;
  const isAvailable = availabilityRow ? availabilityRow.isAvailable : true;
  const isStopListed = stopEntry !== undefined;

  return {
    id: record.id,
    brandId: record.brandId,
    menuId: record.menuId,
    sourceKey: record.sourceKey,
    sku: record.sku,
    name: record.name,
    slug: record.slug,
    description: record.description,
    category: {
      id: record.category.id,
      name: record.category.name,
      menuId: record.category.menuId,
    },
    weight: dec(record.weight),
    calories: record.calories,
    preparationTime: record.preparationTime,
    status: record.status,
    sortOrder: record.sortOrder,
    isPopular: record.isPopular,
    isNew: record.isNew,
    isFeatured: record.isFeatured,
    isHalal,
    available: record.status === 'PUBLISHED' && isAvailable && !isStopListed,
    price: {
      base,
      branch,
      effective: branch ?? base,
      currency: branchOverride?.currency ?? record.currency,
    },
    availability: {
      branchId: branchId ?? null,
      isAvailable,
    },
    stopList: {
      isActive: isStopListed,
      reason: stopEntry?.reason ?? null,
      since: iso(stopEntry?.startsAt),
    },
    certifications,
    ingredients,
    modifierGroups: [...record.modifierGroups]
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map(toModifierGroupEntity),
    lifecycle: {
      publishedAt: iso(record.publishedAt),
      hiddenAt: iso(record.hiddenAt),
      archivedAt: iso(record.archivedAt),
    },
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

const RU_TO_LATIN: Record<string, string> = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'e', ж: 'zh', з: 'z',
  и: 'i', й: 'j', к: 'k', л: 'l', м: 'm', н: 'n', о: 'o', п: 'p', р: 'r',
  с: 's', т: 't', у: 'u', ф: 'f', х: 'h', ц: 'c', ч: 'ch', ш: 'sh',
  щ: 'sch', ъ: '', ы: 'y', ь: '', э: 'e', ю: 'u', я: 'ya',
};

/** Kebab-case slug with basic Cyrillic transliteration; empty result falls back to the SKU. */
export function slugify(input: string, fallback: string): string {
  const transliterated = Array.from(input.toLowerCase())
    .map((char) => RU_TO_LATIN[char] ?? char)
    .join('');
  const slug = transliterated
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug || fallback;
}

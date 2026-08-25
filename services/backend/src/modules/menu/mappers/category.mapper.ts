import { Prisma } from '@prisma/client';
import { CategoryEntity } from '../entities/category.entity';

export type CategoryRecord = Prisma.CategoryGetPayload<{
  include: { _count: { select: { items: true } } };
}>;

export function toCategoryEntity(record: CategoryRecord): CategoryEntity {
  return {
    id: record.id,
    brandId: record.brandId,
    menuId: record.menuId,
    parentId: record.parentId,
    name: record.name,
    description: record.description,
    imageUrl: record.imageUrl,
    sortOrder: record.sortOrder,
    isActive: record.isActive,
    itemCount: record._count.items,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

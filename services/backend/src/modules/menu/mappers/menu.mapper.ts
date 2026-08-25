import { Prisma } from '@prisma/client';
import { MenuEntity } from '../entities/menu.entity';

export type MenuRecord = Prisma.MenuGetPayload<{
  include: { _count: { select: { categories: true } } };
}>;

export function toMenuEntity(record: MenuRecord): MenuEntity {
  return {
    id: record.id,
    brandId: record.brandId,
    branchId: record.branchId,
    name: record.name,
    status: record.status,
    publishedAt: record.publishedAt ? record.publishedAt.toISOString() : null,
    categoryCount: record._count.categories,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

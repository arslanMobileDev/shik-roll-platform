import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ModifierGroupEntity } from './modifier-group.entity';
import { PageMeta } from './pagination.entity';

export class MenuItemCategoryRef {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  menuId!: string;
}

export class LifecycleTimestamps {
  @ApiPropertyOptional({ nullable: true })
  publishedAt!: string | null;

  @ApiPropertyOptional({ nullable: true })
  hiddenAt!: string | null;

  @ApiPropertyOptional({ nullable: true })
  archivedAt!: string | null;
}

export class MenuItemIngredientEntity {
  @ApiProperty()
  ingredientId!: string;

  @ApiProperty()
  name!: string;

  @ApiPropertyOptional({ nullable: true })
  quantity!: number | null;

  @ApiProperty({ description: 'Effective unit: row override or ingredient default' })
  unit!: string;

  @ApiProperty()
  isOptional!: boolean;

  @ApiProperty()
  sortOrder!: number;
}

export class CertificationEntity {
  @ApiProperty()
  tagId!: string;

  @ApiProperty({ example: 'HALAL' })
  code!: string;

  @ApiProperty()
  name!: string;

  @ApiPropertyOptional({ nullable: true })
  certificateNumber!: string | null;

  @ApiPropertyOptional({ nullable: true })
  validUntil!: string | null;
}

export class MenuItemPriceEntity {
  @ApiProperty({ description: 'Base price from the product card' })
  base!: number;

  @ApiPropertyOptional({
    nullable: true,
    description: 'Branch override; null when the branch has no override or no branchId was passed',
  })
  branch!: number | null;

  @ApiProperty({ description: 'Selling price for the requested branch: branch ?? base' })
  effective!: number;

  @ApiProperty({ example: 'RUB' })
  currency!: string;
}

export class BranchAvailabilityEntity {
  @ApiPropertyOptional({
    nullable: true,
    description: 'Branch context the flag was resolved for; null when no branchId was passed',
  })
  branchId!: string | null;

  @ApiProperty({ description: 'true unless an explicit per-branch override disables the item' })
  isAvailable!: boolean;
}

export class StopListStatusEntity {
  @ApiProperty({ description: 'true when an active stop list entry exists for the branch' })
  isActive!: boolean;

  @ApiPropertyOptional({ nullable: true })
  reason!: string | null;

  @ApiPropertyOptional({ nullable: true, description: 'Entry start timestamp (ISO 8601)' })
  since!: string | null;
}

export class MenuItemEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  brandId!: string;

  @ApiProperty()
  menuId!: string;

  @ApiPropertyOptional({ nullable: true, description: 'Stable external import key within the menu' })
  sourceKey!: string | null;

  @ApiProperty()
  sku!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  slug!: string;

  @ApiPropertyOptional({ nullable: true })
  description!: string | null;

  @ApiProperty()
  category!: MenuItemCategoryRef;

  @ApiPropertyOptional({ nullable: true, description: 'Weight in grams' })
  weight!: number | null;

  @ApiPropertyOptional({ nullable: true })
  calories!: number | null;

  @ApiPropertyOptional({ nullable: true, description: 'Preparation time, minutes' })
  preparationTime!: number | null;

  @ApiProperty({ enum: ['DRAFT', 'PUBLISHED', 'HIDDEN', 'ARCHIVED'], description: 'Single lifecycle field (DB-607 v1.2.0)' })
  status!: string;

  @ApiProperty({ description: 'Position inside the category' })
  sortOrder!: number;

  @ApiProperty({ description: 'Manual merchandising flag' })
  isPopular!: boolean;

  @ApiProperty({ description: 'Manual merchandising flag' })
  isNew!: boolean;

  @ApiProperty({ description: 'Manual merchandising flag' })
  isFeatured!: boolean;

  @ApiProperty({ description: 'Holds a valid HALAL certification tag' })
  isHalal!: boolean;

  @ApiProperty({
    description:
      'Sellable in the requested branch context: PUBLISHED, available and not stop-listed',
  })
  available!: boolean;

  @ApiProperty()
  price!: MenuItemPriceEntity;

  @ApiProperty()
  availability!: BranchAvailabilityEntity;

  @ApiProperty()
  stopList!: StopListStatusEntity;

  @ApiProperty({ type: [CertificationEntity] })
  certifications!: CertificationEntity[];

  @ApiProperty({ type: [MenuItemIngredientEntity] })
  ingredients!: MenuItemIngredientEntity[];

  @ApiProperty({ type: [ModifierGroupEntity] })
  modifierGroups!: ModifierGroupEntity[];

  @ApiProperty()
  lifecycle!: LifecycleTimestamps;

  @ApiProperty()
  createdAt!: string;

  @ApiProperty()
  updatedAt!: string;
}

export class MenuItemPage {
  @ApiProperty({ type: [MenuItemEntity] })
  data!: MenuItemEntity[];

  @ApiProperty()
  meta!: PageMeta;
}

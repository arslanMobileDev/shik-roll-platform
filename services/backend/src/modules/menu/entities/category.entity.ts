import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PageMeta } from './pagination.entity';

export class CategoryEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  brandId!: string;

  @ApiProperty()
  menuId!: string;

  @ApiPropertyOptional({ nullable: true })
  parentId!: string | null;

  @ApiProperty()
  name!: string;

  @ApiPropertyOptional({ nullable: true })
  description!: string | null;

  @ApiPropertyOptional({ nullable: true })
  imageUrl!: string | null;

  @ApiProperty()
  sortOrder!: number;

  @ApiProperty()
  isActive!: boolean;

  @ApiProperty({ description: 'Number of active items in the category' })
  itemCount!: number;

  @ApiProperty()
  createdAt!: string;

  @ApiProperty()
  updatedAt!: string;
}

export class CategoryPage {
  @ApiProperty({ type: [CategoryEntity] })
  data!: CategoryEntity[];

  @ApiProperty()
  meta!: PageMeta;
}

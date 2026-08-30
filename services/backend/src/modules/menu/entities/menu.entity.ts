import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PageMeta } from './pagination.entity';

export class MenuEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  brandId!: string;

  @ApiPropertyOptional({ nullable: true, description: 'null — brand-level default menu' })
  branchId!: string | null;

  @ApiProperty()
  name!: string;

  @ApiProperty({ enum: ['DRAFT', 'PUBLISHED', 'UNPUBLISHED'] })
  status!: string;

  @ApiPropertyOptional({ nullable: true, description: 'Current published version number (menu_versions)' })
  currentVersion!: number | null;

  @ApiPropertyOptional({ nullable: true })
  publishedAt!: string | null;

  @ApiPropertyOptional({ nullable: true })
  unpublishedAt!: string | null;

  @ApiProperty()
  categoryCount!: number;

  @ApiProperty()
  createdAt!: string;

  @ApiProperty()
  updatedAt!: string;
}

export class MenuPage {
  @ApiProperty({ type: [MenuEntity] })
  data!: MenuEntity[];

  @ApiProperty()
  meta!: PageMeta;
}

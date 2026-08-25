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

  @ApiProperty({ enum: ['DRAFT', 'PUBLISHED', 'ARCHIVED'] })
  status!: string;

  @ApiPropertyOptional({ nullable: true })
  publishedAt!: string | null;

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

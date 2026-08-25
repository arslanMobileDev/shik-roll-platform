import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ModifierItemEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ description: 'Extra charge in the given currency' })
  price!: number;

  @ApiProperty()
  currency!: string;

  @ApiPropertyOptional({ nullable: true })
  calories!: number | null;

  @ApiProperty()
  sortOrder!: number;
}

export class ModifierGroupEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ enum: ['SINGLE', 'MULTIPLE'] })
  selectionType!: string;

  @ApiProperty()
  minSelected!: number;

  @ApiPropertyOptional({ nullable: true })
  maxSelected!: number | null;

  @ApiProperty()
  isRequired!: boolean;

  @ApiProperty()
  sortOrder!: number;

  @ApiProperty({ type: [ModifierItemEntity] })
  items!: ModifierItemEntity[];
}

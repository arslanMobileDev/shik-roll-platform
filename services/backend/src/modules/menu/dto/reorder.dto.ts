import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsUUID } from 'class-validator';

/** Ordered list of entity ids — position in the array becomes sort_order. */
export class ReorderDto {
  @ApiProperty({
    type: [String],
    description: 'UUIDs in the desired order; index becomes sortOrder',
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @IsUUID('4', { each: true })
  ids!: string[];
}

import { ApiProperty } from '@nestjs/swagger';
import { ProductStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

/** Product lifecycle transitions (API-706): DRAFT | PUBLISHED | HIDDEN. ARCHIVED via DELETE. */
export class UpdateProductStatusDto {
  @ApiProperty({
    enum: [ProductStatus.DRAFT, ProductStatus.PUBLISHED, ProductStatus.HIDDEN],
    description:
      'New lifecycle status. Allowed: DRAFT→PUBLISHED, PUBLISHED→HIDDEN, HIDDEN→PUBLISHED. ARCHIVED via DELETE.',
  })
  @IsEnum([ProductStatus.DRAFT, ProductStatus.PUBLISHED, ProductStatus.HIDDEN], {
    message: 'status must be one of DRAFT, PUBLISHED, HIDDEN (ARCHIVED via DELETE)',
  })
  status!: 'DRAFT' | 'PUBLISHED' | 'HIDDEN';
}

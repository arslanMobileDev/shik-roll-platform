import { OmitType, PartialType } from '@nestjs/swagger';
import { CreateCategoryDto } from './create-category.dto';

/** Menu reassignment is not supported by PATCH; all other fields are optional. */
export class UpdateCategoryDto extends PartialType(
  OmitType(CreateCategoryDto, ['menuId'] as const),
) {}

import { OmitType, PartialType } from '@nestjs/swagger';
import { CreateMenuItemDto } from './create-menu-item.dto';

/**
 * PATCH updates scalar fields and certifications; composition and modifier
 * groups are assigned at creation time within this package scope.
 */
export class UpdateMenuItemDto extends PartialType(
  OmitType(CreateMenuItemDto, ['ingredients', 'modifierGroupIds'] as const),
) {}

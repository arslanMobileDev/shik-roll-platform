import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { OrderStatus, OrderType } from '@prisma/client';
import { PageMeta } from '../../menu/entities/pagination.entity';

export class OrderItemModifierEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  modifierItemId!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ description: 'Price delta in RUB' })
  priceDelta!: number;

  @ApiProperty()
  quantity!: number;
}

export class OrderItemEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  menuItemId!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  quantity!: number;

  @ApiProperty({ description: 'Unit price in RUB' })
  unitPrice!: number;

  @ApiProperty({ description: 'Line total in RUB' })
  totalAmount!: number;

  @ApiPropertyOptional()
  comment!: string | null;

  @ApiProperty({ type: [OrderItemModifierEntity] })
  modifiers!: OrderItemModifierEntity[];
}

export class OrderEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  orderNumber!: string;

  @ApiProperty({ enum: OrderStatus })
  status!: OrderStatus;

  @ApiProperty({ enum: OrderType })
  type!: OrderType;

  @ApiProperty()
  brandId!: string;

  @ApiProperty()
  branchId!: string;

  @ApiPropertyOptional()
  tableNumber!: string | null;

  @ApiPropertyOptional()
  deliveryAddress!: string | null;

  @ApiPropertyOptional()
  comment!: string | null;

  @ApiProperty({ description: 'Subtotal in RUB' })
  subtotalAmount!: number;

  @ApiProperty({ description: 'Total in RUB' })
  totalAmount!: number;

  @ApiProperty()
  currency!: string;

  @ApiPropertyOptional()
  estimatedReadyAt!: string | null;

  @ApiPropertyOptional()
  completedAt!: string | null;

  @ApiPropertyOptional()
  cancelledAt!: string | null;

  @ApiProperty()
  createdAt!: string;

  @ApiProperty()
  updatedAt!: string;

  @ApiProperty({ type: [OrderItemEntity] })
  items!: OrderItemEntity[];
}

export class OrderPage {
  @ApiProperty({ type: [OrderEntity] })
  data!: OrderEntity[];

  @ApiProperty({ type: PageMeta })
  meta!: PageMeta;
}

import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class CreatePaymentDto {
  @ApiProperty({ description: 'Order to pay online' })
  @IsUUID()
  orderId!: string;
}

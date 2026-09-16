import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
export class RevenueRange {
  @ApiProperty({ format: 'date-time' }) from!: string;
  @ApiProperty({ format: 'date-time' }) to!: string;
  @ApiProperty() label!: string;
}
export class RevenueTotals {
  @ApiProperty() total!: number;
  @ApiProperty() ordersCount!: number;
  @ApiProperty() averageCheck!: number;
}
export class RevenueDay {
  @ApiProperty({ format: 'date' }) date!: string;
  @ApiProperty() total!: number;
  @ApiProperty() count!: number;
}
export class RevenueItem {
  @ApiProperty({ format: 'uuid' }) menuItemId!: string;
  @ApiProperty() name!: string;
  @ApiProperty() quantity!: number;
  @ApiProperty({ description: 'Sum of item snapshots before order-level bonus discounts, RUB' }) revenue!: number;
}
export class RevenueBranch {
  @ApiProperty({ format: 'uuid' }) branchId!: string;
  @ApiProperty() branchName!: string;
  @ApiProperty() total!: number;
  @ApiProperty() count!: number;
}
export class RevenueResponse {
  @ApiProperty({ type: RevenueRange }) period!: RevenueRange;
  @ApiProperty({ type: RevenueTotals }) summary!: RevenueTotals;
  @ApiProperty({ type: [RevenueDay] }) byDay!: RevenueDay[];
  @ApiProperty({ type: [RevenueItem] }) topItems!: RevenueItem[];
  @ApiPropertyOptional({ type: [RevenueBranch] }) byBranch?: RevenueBranch[];
}

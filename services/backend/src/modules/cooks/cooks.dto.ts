import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, ValidateIf, IsString, IsUUID, Matches, MaxLength, MinLength } from 'class-validator';
export const normalizeCookPhone = (value: unknown): unknown => {
    if (typeof value !== 'string')
        return value;
    const digits = value.replace(/[\s()+-]/g, '');
    return /^[78]\d{10}$/.test(digits) ? '+7' + digits.slice(1) : value;
};
export class CookLoginDto {
    @Transform(({ value }) => normalizeCookPhone(value))
    @Matches(/^\+7\d{10}$/)
    phone!: string;
    @Matches(/^\d{4,8}$/)
    pin!: string;
}
export class CreateCookDto extends CookLoginDto {
    @IsString()
    @MinLength(1)
    @MaxLength(100)
    @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
    name!: string;
    @IsUUID()
    branchId!: string;
}
export class UpdateCookDto {
    @ValidateIf((_, value) => value !== undefined)
    @IsString()
    @MinLength(1)
    @MaxLength(100)
    @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
    name?: string;
    @ValidateIf((_, value) => value !== undefined)
    @Matches(/^\d{4,8}$/)
    pin?: string;
    @ValidateIf((_, value) => value !== undefined)
    @IsBoolean()
    isActive?: boolean;
}
export class CookBranchDto {
    @IsUUID()
    branchId!: string;
}
export class CookStatsDto {
    @IsOptional()
    @IsIn(['today', 'week', 'month'])
    period?: 'today' | 'week' | 'month';
}
export interface CookActor {
    id: string;
    shiftId: string;
    branchId: string;
    terminalId: string;
}
export interface CookRequest {
    headers: {
        authorization?: string;
        'x-cook-authorization'?: string;
    };
    cook: CookActor;
    kitchenTerminal: import('../kitchen/kitchen.types').AuthenticatedKitchenTerminal;
}

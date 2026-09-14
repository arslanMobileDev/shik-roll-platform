import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentStaff } from './decorators/current-staff.decorator';
import { StaffPinAuthDto } from './dto/staff-auth.dto';
import { StaffJwtAuthGuard } from './guards/staff-jwt-auth.guard';
import { StaffAuthResponse, StaffService } from './staff.service';
import { AuthenticatedStaff } from './staff.types';

@ApiTags('staff')
@Controller('staff')
export class StaffController {
  constructor(private readonly service: StaffService) {}

  @Post('auth/pin')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Back-office login by phone + PIN (returns a scoped staff JWT)',
  })
  @ApiOkResponse({ description: 'STAFF token plus safe staff projection' })
  @ApiUnauthorizedResponse({ description: 'INVALID_CREDENTIALS' })
  authByPin(@Body() dto: StaffPinAuthDto): Promise<StaffAuthResponse> {
    return this.service.authenticateByPin(dto);
  }

  @Get('me')
  @UseGuards(StaffJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Profile of the authenticated staff member' })
  @ApiOkResponse({ description: 'Staff identity from the verified token' })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  me(@CurrentStaff() staff: AuthenticatedStaff): AuthenticatedStaff {
    return staff;
  }
}

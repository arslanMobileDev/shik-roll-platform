import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { AuthenticatedCustomer } from '../auth/auth.types';
import { CurrentCustomer } from '../auth/decorators/current-customer.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CustomersService } from './customers.service';
import { ConfirmDeletionDto } from './dto/confirm-deletion.dto';
import {
  ConfirmDeletionResponse,
  DeletionRequestResponse,
} from './entities/customer-deletion.entities';

/**
 * Self-service account deletion for the mobile app (Apple requirement).
 *
 * Two server-side steps rather than a preview plus a `confirm` flag, because
 * the second step has to be something the client cannot fabricate by flipping
 * a body field — and the same short-lived-token mechanism is needed for
 * restore anyway.
 */
@ApiTags('customers')
@Controller('customers/me')
export class CustomersController {
  constructor(private readonly service: CustomersService) {}

  @Post('deletion-request')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Step 1 of account deletion: what will be lost (bonus balance) and a one-shot confirmation token',
  })
  @ApiOkResponse({ type: DeletionRequestResponse })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  @ApiConflictResponse({ description: 'ACCOUNT_ALREADY_DELETED' })
  requestDeletion(
    @CurrentCustomer() customer: AuthenticatedCustomer,
  ): Promise<DeletionRequestResponse> {
    return this.service.requestDeletion(customer.id);
  }

  @Post('deletion-confirm')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Step 2 of account deletion: burns the bonus balance and anonymizes the account',
  })
  @ApiOkResponse({ type: ConfirmDeletionResponse })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / ACCOUNT_TOKEN_INVALID' })
  @ApiConflictResponse({
    description: 'ACTIVE_ORDERS_EXIST / ACCOUNT_ALREADY_DELETED',
  })
  confirmDeletion(
    @Body() dto: ConfirmDeletionDto,
    @CurrentCustomer() customer: AuthenticatedCustomer,
  ): Promise<ConfirmDeletionResponse> {
    return this.service.confirmDeletion(customer.id, dto);
  }
}

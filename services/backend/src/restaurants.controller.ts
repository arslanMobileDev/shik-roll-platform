import { Controller, Get, Query, NotFoundException } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

@Controller('restaurants')
export class RestaurantsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('contacts')
  async getContacts(@Query('branchId') branchId?: string) {
    if (!branchId) {
      throw new NotFoundException('branchId is required');
    }

    const branch = await this.prisma.branch.findUnique({
      where: { id: branchId },
    });

    if (!branch) {
      throw new NotFoundException('Branch not found');
    }

    // TODO(post-release): move hardcoded contacts into the Branch model so
    // the back office can edit them without a redeploy.
    return {
      branchId: branch.id,
      phone: '+79283002625',
      phoneDisplay: '+7 928 300-26-25',
      whatsapp: '+79283002625',
      telegram: 'SHIKROLLfoodZona',
      telegramUrl: 'https://t.me/SHIKROLLfoodZona',
      instagramUrl: 'https://www.instagram.com/shikroll.mv?stkn=aTF2ZXdmN3VtMndy',
      workingHours: '10:00 – 22:00',
      address: 'г. Минеральные Воды, ул. Бештаугорская, 7А',
    };
  }
}

import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { MenuModule } from './modules/menu/menu.module';

@Module({
  imports: [PrismaModule, MenuModule],
})
export class AppModule {}

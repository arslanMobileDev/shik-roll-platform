import { ApiProperty } from '@nestjs/swagger';

/** Result of a successful menu image upload (ADR-008). */
export class UploadResultDto {
  @ApiProperty({ example: '0f3d2c9a-7b1e-4f2a-9c8d-1e2f3a4b5c6d.webp' })
  filename: string;

  @ApiProperty({
    example: '/uploads/menu/0f3d2c9a-7b1e-4f2a-9c8d-1e2f3a4b5c6d.webp',
    description: 'Stable public path; independent of the client Host header',
  })
  url: string;

  @ApiProperty({ example: 'image/webp' })
  mimeType: string;

  @ApiProperty({ example: 183421, description: 'WebP payload size in bytes' })
  size: number;

  @ApiProperty({ example: 1000 })
  width: number;

  @ApiProperty({ example: 1000 })
  height: number;
}

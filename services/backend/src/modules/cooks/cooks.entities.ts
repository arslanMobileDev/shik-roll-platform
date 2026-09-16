import { CooksService } from './cooks.service';
import { CookStatisticsService } from './cook-statistics.service';
export type CookLoginResponse = Awaited<ReturnType<CooksService['login']>>;
export type CookProfileResponse = Awaited<ReturnType<CooksService['me']>>;
export type CookShiftsResponse = Awaited<ReturnType<CookStatisticsService['shifts']>>;
export type CookStatisticsResponse = Awaited<ReturnType<CookStatisticsService['personal']>>;

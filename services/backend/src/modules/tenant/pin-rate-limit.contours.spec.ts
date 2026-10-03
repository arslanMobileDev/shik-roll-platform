import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import * as rateLimit from './pin-rate-limit';
import { __pinRateLimitResetForTests } from './pin-rate-limit';
import { TenantContext } from './tenant.types';
import { StaffService } from '../staff/staff.service';
import { CouriersService } from '../couriers/couriers.service';
import { KitchenService } from '../kitchen/kitchen.service';
import { CooksService } from '../cooks/cooks.service';

/**
 * The contour split (ADR-1622 step 4, C4; review of c5f9c4d) proved where it
 * actually lives: at the four call sites, not in the limiter's own tests.
 *
 * `pin-rate-limit.spec.ts` drives the module directly, so on the pre-d5b4b7e
 * sources its contour assertions stay green — the spec's extra first argument
 * is silently dropped by the old two-argument signature (ts-jest runs with
 * isolatedModules and never type-checks), and the effective key just becomes
 * `contour:tenant`, which still happens to differ per contour. This file goes
 * through the services, which is where the old signature actually was.
 */

const SECRET = 'contour-test-secret';
const PHONE = '+79991234567';
const PIN = '1234';
const TENANT: TenantContext = { id: 'tenant-1', code: 'SHIK_ROLL' };
const TERMINAL = { id: 'terminal-1', tenantId: TENANT.id, branchId: 'branch-1' };

const staffPrisma = () => ({
  staff: { findMany: jest.fn(), findUnique: jest.fn() },
});

const courierPrisma = () => ({
  courier: { findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
});

describe('PIN rate limit is scoped per auth contour', () => {
  let jwt: JwtService;

  beforeEach(() => {
    __pinRateLimitResetForTests();
    jwt = new JwtService({ secret: SECRET });
  });

  describe('through the services', () => {
    it('a successful courier login does not hand back the staff budget', async () => {
      const staffDb = staffPrisma();
      const courierDb = courierPrisma();
      const staff = new StaffService(staffDb as never, jwt);
      const couriers = new CouriersService(
        courierDb as never,
        jwt,
        { emitCourierLocation: jest.fn() } as never,
        { earnCashback: jest.fn() } as never,
      );

      // Four failed staff attempts. Four, not five: on the old shared key the
      // courier login below is the fifth attempt and still fits the budget.
      staffDb.staff.findMany.mockResolvedValue([]);
      for (let i = 0; i < 4; i += 1) {
        await expect(
          staff.authenticateByPin({ phone: PHONE, pin: PIN }, TENANT),
        ).rejects.toMatchObject({ response: { code: 'INVALID_CREDENTIALS' } });
      }

      // The same phone is also a courier, and this login genuinely succeeds —
      // so it resets the courier bucket. On the old `tenant:key` bucket that
      // reset deleted the staff budget too, and an attacker could probe four
      // staff PINs, log in once as a courier, and repeat forever.
      courierDb.courier.findUnique.mockResolvedValue({
        id: 'courier-1',
        name: 'Курьер',
        phone: PHONE,
        pinHash: bcrypt.hashSync(PIN, 4),
        branchId: 'branch-1',
        isActive: true,
      });
      await couriers.authenticateByPin({ phone: PHONE, pin: PIN }, TENANT);

      // Fifth staff attempt: the budget still has one slot left...
      await expect(
        staff.authenticateByPin({ phone: PHONE, pin: PIN }, TENANT),
      ).rejects.toMatchObject({ response: { code: 'INVALID_CREDENTIALS' } });

      // ...and the sixth is the 429. On the old sources the courier reset had
      // zeroed the counter, so this attempt is a plain 401 — red before green.
      await expect(
        staff.authenticateByPin({ phone: PHONE, pin: PIN }, TENANT),
      ).rejects.toMatchObject({ response: { code: 'TOO_MANY_ATTEMPTS' } });
    });
  });

  describe('at the call site', () => {
    let consume: jest.SpyInstance;

    beforeEach(() => {
      consume = jest.spyOn(
        rateLimit as unknown as { pinRateLimitConsume: () => void },
        'pinRateLimitConsume',
      );
    });

    afterEach(() => {
      consume.mockRestore();
    });

    it('staff passes its own contour and tenant', async () => {
      const staffDb = staffPrisma();
      staffDb.staff.findMany.mockResolvedValue([]);
      const staff = new StaffService(staffDb as never, jwt);

      await expect(
        staff.authenticateByPin({ phone: PHONE, pin: PIN }, TENANT),
      ).rejects.toThrow();

      expect(consume).toHaveBeenCalledWith('staff', TENANT.code, PHONE);
    });

    it('courier passes its own contour and tenant', async () => {
      const courierDb = courierPrisma();
      courierDb.courier.findUnique.mockResolvedValue(null);
      const couriers = new CouriersService(
        courierDb as never,
        jwt,
        { emitCourierLocation: jest.fn() } as never,
        { earnCashback: jest.fn() } as never,
      );

      await expect(
        couriers.authenticateByPin({ phone: PHONE, pin: PIN }, TENANT),
      ).rejects.toThrow();

      expect(consume).toHaveBeenCalledWith('courier', TENANT.code, PHONE);
    });

    it('kitchen passes its own contour and keys on the terminal code', async () => {
      const kitchenDb = { kitchenTerminal: { findUnique: jest.fn() } };
      kitchenDb.kitchenTerminal.findUnique.mockResolvedValue(null);
      const kitchen = new KitchenService(
        kitchenDb as never,
        jwt,
        {} as never,
        {} as never,
      );

      await expect(
        kitchen.authenticateByPin({ terminalCode: 'KDS-01', pin: PIN }, TENANT),
      ).rejects.toThrow();

      expect(consume).toHaveBeenCalledWith('kitchen', TENANT.code, 'KDS-01');
    });

    it('cook passes its own contour and the terminal as its tenant proxy', async () => {
      const cookDb = { cook: { findUnique: jest.fn() } };
      cookDb.cook.findUnique.mockResolvedValue(null);
      const cooks = new CooksService(cookDb as never, jwt);

      await expect(
        cooks.login(TERMINAL as never, { phone: PHONE, pin: PIN }),
      ).rejects.toThrow();

      // The cook route carries no X-Tenant, so the authenticated terminal's id
      // stands in for the tenant code (documented in cooks.service.ts).
      expect(consume).toHaveBeenCalledWith('cook', TERMINAL.id, PHONE);
    });
  });
});

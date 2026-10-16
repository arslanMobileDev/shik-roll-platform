import { maskPhone } from './mask-phone';

describe('maskPhone', () => {
  it('keeps the +7 prefix, the operator digits and the last four', () => {
    expect(maskPhone('+79822681958')).toBe('+7982***1958');
    expect(maskPhone('+79991234567')).toBe('+7999***4567');
  });

  it('masks a value in any other shape entirely', () => {
    expect(maskPhone('+7999')).toBe('***');
    expect(maskPhone('79822681958')).toBe('***');
    expect(maskPhone('+7 (982) 268-19-58')).toBe('***');
    expect(maskPhone('')).toBe('***');
  });

  it('never lets the middle digits through', () => {
    expect(maskPhone('+79822681958')).not.toContain('2681');
  });
});

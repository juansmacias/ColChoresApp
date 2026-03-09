import { generateCode, normalizeCode } from '../src/invite/invite-utils';

describe('invite-utils', () => {
  it('generates a 6 character code', () => {
    expect(generateCode()).toHaveLength(6);
  });

  it('normalizes codes to uppercase', () => {
    expect(normalizeCode(' abc123 ')).toBe('ABC123');
  });
});

import { SmsRuProvider } from '../src/modules/auth/providers/sms/smsru.provider';

async function main(): Promise<void> {
  const phone = process.argv[2];
  const code = process.argv[3] ?? '5555';
  const ip = process.argv[4] ?? '127.0.0.1';
  const apiId = process.env.SMSRU_API_ID;

  if (!apiId) throw new Error('SMSRU_API_ID is unset (source .env first)');
  if (!phone) throw new Error('Usage: tsx send-test-sms.ts <phone> [code] [ip]');

  const provider = new SmsRuProvider(apiId);
  console.log(`Sending code "${code}" to ${phone} via SMS.ru (ip=${ip}) ...`);
  await provider.send(phone, code, ip);
  console.log('OK — check the phone in a few seconds.');
}

main().catch((error) => {
  console.error('FAILED:', error instanceof Error ? error.message : error);
  process.exit(1);
});

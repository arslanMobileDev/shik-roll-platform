export function allowedCorsOrigins(
  env: NodeJS.ProcessEnv = process.env,
): string[] | true {
  const configured = (env.CORS_ORIGIN ?? env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (env.NODE_ENV === 'production') {
    if (configured.length === 0 || configured.includes('*')) {
      throw new Error(
        'Production CORS_ORIGIN must contain explicit HTTPS origins; wildcard is forbidden',
      );
    }
    for (const origin of configured) {
      const uri = new URL(origin);
      if (uri.protocol !== 'https:' || uri.origin !== origin) {
        throw new Error(`Invalid production CORS origin: ${origin}`);
      }
    }
  }

  return configured.length > 0 ? configured : true;
}

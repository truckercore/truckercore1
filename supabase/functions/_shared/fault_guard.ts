export function assertChaosAllowed() {
  const env = Deno.env.get('ENV') ?? 'prod';
  if (env === 'prod') throw new Error('Chaos disabled in prod');
}

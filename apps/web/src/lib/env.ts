export type AppConfig = Readonly<{
  supabaseUrl: string
  supabaseAnonKey: string
  mapToken?: string
  featureDefaults: { [k: string]: boolean }
}>

function required(name: string, value: string | undefined): string {
  if (!value) {
    // During build or server-side prerendering, allow empty defaults to avoid hard failures.
    // At runtime, ensure your Vercel project has these env vars configured.
    if (typeof window === 'undefined') return '';
    // In the browser, fail softly to avoid crashing the whole app.
    console.warn(`[env] Missing env: ${name}`);
    return '';
  }
  return value;
}

export const config: AppConfig = Object.freeze({
  supabaseUrl: required('NEXT_PUBLIC_SUPABASE_URL', process.env.NEXT_PUBLIC_SUPABASE_URL),
  supabaseAnonKey: required('NEXT_PUBLIC_SUPABASE_ANON_KEY', process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY),
  mapToken: process.env.NEXT_PUBLIC_MAP_TOKEN,
  featureDefaults: {},
})

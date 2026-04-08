import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

type AppRole = 'driver' | 'owner_operator' | 'fleet_manager' | 'freight_broker' | 'admin';

const ROLE_ROUTES: Array<{ prefix: string; roles: AppRole[]; premium?: boolean }> = [
  { prefix: '/driver-dashboard', roles: ['driver', 'admin'] },
  { prefix: '/owner-operator-dashboard', roles: ['owner_operator', 'admin'] },
  { prefix: '/fleet-manager-dashboard', roles: ['fleet_manager', 'admin'] },
  { prefix: '/freight-broker-dashboard', roles: ['freight_broker', 'admin'] },
  { prefix: '/gps', roles: ['driver', 'owner_operator', 'fleet_manager', 'freight_broker', 'admin'] },
];

function getRouteRule(pathname: string) {
  return ROLE_ROUTES.find((r) => pathname.startsWith(r.prefix));
}

export async function middleware(request: NextRequest) {
  const { pathname, search } = request.nextUrl;

  let response = NextResponse.next({
    request: { headers: request.headers },
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  // Redirect logged-in users away from login page
  if (user && pathname === '/login') {
    return NextResponse.redirect(new URL('/', request.url));
  }

  const routeRule = getRouteRule(pathname);
  if (!routeRule) return response;

  // Require auth
  if (!user) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirectTo', pathname + search);
    return NextResponse.redirect(loginUrl);
  }

  // Fetch profile for role/premium check
  const { data: profile } = await supabase
    .from('profiles')
    .select('role, is_premium, app_is_premium')
    .eq('id', user.id)
    .maybeSingle();

  const role = profile?.role as AppRole | undefined;
  const premium = !!(profile?.app_is_premium || profile?.is_premium);
  const roleAllowed = !!role && (role === 'admin' || routeRule.roles.includes(role));

  if (!roleAllowed) {
    return NextResponse.redirect(new URL('/unauthorized', request.url));
  }

  if (routeRule.premium && !premium) {
    const upgradeUrl = new URL('/upgrade', request.url);
    upgradeUrl.searchParams.set('from', pathname + search);
    return NextResponse.redirect(upgradeUrl);
  }

  return response;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
};
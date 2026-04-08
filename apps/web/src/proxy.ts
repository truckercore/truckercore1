import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';
import type { AppRole } from '@/lib/auth/access';

type RouteRule = {
  prefix: string;
  roles: AppRole[];
  premium?: boolean;
};

const PUBLIC_PATHS = ['/', '/login', '/pricing', '/about', '/contact', '/unauthorized', '/upgrade'];

const ROUTE_RULES: RouteRule[] = [
  { prefix: '/gps', roles: ['driver', 'owner_operator', 'fleet_manager', 'freight_broker', 'admin'] },

  { prefix: '/driver-dashboard', roles: ['driver', 'admin'] },
  { prefix: '/owner-operator-dashboard', roles: ['owner_operator', 'admin'] },
  { prefix: '/fleet-manager-dashboard', roles: ['fleet_manager', 'admin'] },
  { prefix: '/freight-broker-dashboard', roles: ['freight_broker', 'admin'] },

  { prefix: '/premium/driver', roles: ['driver', 'admin'], premium: true },
  { prefix: '/premium/owner-operator', roles: ['owner_operator', 'admin'], premium: true },
  { prefix: '/premium/fleet', roles: ['fleet_manager', 'admin'], premium: true },
  { prefix: '/premium/broker', roles: ['freight_broker', 'admin'], premium: true },
];

function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

function getRouteRule(pathname: string): RouteRule | undefined {
  return ROUTE_RULES.find((rule) => pathname.startsWith(rule.prefix));
}

export async function proxy(request: NextRequest) {
  const { pathname, search } = request.nextUrl;

  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => {
            request.cookies.set(name, value);
          });

          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user && pathname === '/login') {
    return NextResponse.redirect(new URL('/', request.url));
  }

  if (isPublicPath(pathname)) {
    return response;
  }

  const routeRule = getRouteRule(pathname);

  if (!routeRule) {
    return response;
  }

  if (!user) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirectTo', pathname + search);
    return NextResponse.redirect(loginUrl);
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, is_premium, app_is_premium')
    .eq('id', user.id)
    .maybeSingle();

  const role = (profile?.role as AppRole | undefined) ?? undefined;
  const isPremium = !!(profile?.app_is_premium || profile?.is_premium);

  const roleAllowed =
    !!role && (role === 'admin' || routeRule.roles.includes(role));

  if (!roleAllowed) {
    return NextResponse.redirect(new URL('/unauthorized', request.url));
  }

  if (routeRule.premium && !isPremium) {
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
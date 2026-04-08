import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

const PROTECTED = [
  '/gps',
  '/driver-dashboard',
  '/owner-operator-dashboard',
  '/fleet-manager-dashboard',
  '/freight-broker-dashboard',
];

function isProtected(pathname: string) {
  return PROTECTED.some((p) => pathname.startsWith(p));
}

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({
    request: { headers: request.headers },
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
          // Fix: no response reassignment — stable under load
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

  // getUser() triggers token refresh + is safe for authorization
  const { data: { user } } = await supabase.auth.getUser();

  // Block unauthenticated access to protected routes
  if (!user && isProtected(request.nextUrl.pathname)) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set(
      'redirectTo',
      request.nextUrl.pathname + request.nextUrl.search
    );
    return NextResponse.redirect(loginUrl);
  }

  // Block logged-in users from seeing the login page
  if (user && request.nextUrl.pathname === '/login') {
    return NextResponse.redirect(new URL('/', request.url));
  }

  return response;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
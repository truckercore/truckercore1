import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

function isProtected(pathname: string) {
  return (
    pathname.startsWith('/gps') ||
    pathname.startsWith('/driver-dashboard') ||
    pathname.startsWith('/owner-operator-dashboard') ||
    pathname.startsWith('/fleet-manager-dashboard') ||
    pathname.startsWith('/freight-broker-dashboard')
  );
}

export async function middleware(req: NextRequest) {
  const res = NextResponse.next();

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) { return req.cookies.get(name)?.value; },
        set(name: string, value: string, options: Record<string, any>) {
          res.cookies.set({ name, value, ...options });
        },
        remove(name: string, options: Record<string, any>) {
          res.cookies.set({ name, value: '', ...options });
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  if (isProtected(req.nextUrl.pathname) && !user) {
    const loginUrl = new URL('/login', req.url);
    loginUrl.searchParams.set('redirectTo', req.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  return res;
}

export const config = {
  matcher: [
    '/gps/:path*',
    '/driver-dashboard/:path*',
    '/owner-operator-dashboard/:path*',
    '/fleet-manager-dashboard/:path*',
    '/freight-broker-dashboard/:path*',
  ],
};
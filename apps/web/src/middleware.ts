import { NextResponse, NextRequest } from 'next/server'

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl
  if (pathname.startsWith('/dashboard')) {
    // Placeholder gate: in real app, check Supabase session using middleware on edge
    const isAuthed = req.cookies.get('sb-access-token') || req.cookies.get('sb:token')
    if (!isAuthed) {
      const url = req.nextUrl.clone()
      url.pathname = '/login'
      return NextResponse.redirect(url)
    }
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*'],
}

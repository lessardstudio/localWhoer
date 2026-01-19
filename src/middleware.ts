import { NextRequest, NextResponse } from 'next/server';

export const config = {
  matcher: ['/', '/api/:path*'],
};

export function middleware(req: NextRequest) {
  const basicAuth = req.headers.get('authorization');

  if (basicAuth) {
    const authValue = basicAuth.split(' ')[1];
    const [user, pwd] = atob(authValue).split(':');

    // Default credentials: admin / whier123
    // In production, these should be env vars
    const validUser = process.env.BASIC_AUTH_USER || 'admin';
    const validPass = process.env.BASIC_AUTH_PASSWORD || 'whier123';

    if (user === validUser && pwd === validPass) {
      return NextResponse.next();
    }
  }

  return new NextResponse('Auth Required', {
    status: 401,
    headers: {
      'WWW-Authenticate': 'Basic realm="Secure Area"',
    },
  });
}

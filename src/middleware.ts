import { NextRequest, NextResponse } from 'next/server';

export const config = {
  matcher: ['/', '/api/:path*'],
};

export function middleware(req: NextRequest) {
  // Check for trusted IPs (VPN/Localhost)
  const forwardedFor = req.headers.get('x-forwarded-for');
  const realIp = req.headers.get('x-real-ip');
  let clientIp = forwardedFor?.split(',')[0].trim() || realIp || 'unknown';
  
  // Allow access without auth for internal IPs
  const trustedIps = ['127.0.0.1', '172.18.0.1', '::1', '8080'];
  if (trustedIps.includes(clientIp)) {
    return NextResponse.next();
  }

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

import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const forwardedFor = req.headers.get('x-forwarded-for');
  const realIp = req.headers.get('x-real-ip');
  
  let ip = forwardedFor ?? realIp ?? req.ip ?? 'unknown';
  
  // Handle multiple IPs in x-forwarded-for
  if (ip && ip.includes(',')) {
    ip = ip.split(',')[0].trim();
  }

  if (ip?.startsWith('::ffff:')) {
    ip = ip.slice('::ffff:'.length);
  }
  
  // Fallback if headers are empty (e.g. local dev)
  if (!ip || ip === 'unknown') {
    ip = '127.0.0.1'; 
  }

  // Trusted Networks / IPs
  // 172.18.0.1 - Docker Gateway (Internal Network Access)
  // 127.0.0.1 - Localhost (Masquerade Proxy)
  // 208.92.227.197 - Server Public IP (VPN Exit IP)
  const trustedIps = [
    '127.0.0.1', 
    '::1', 
    '172.21.0.1', 
    '208.92.227.197' 
  ];

  const isTrustedIp = trustedIps.includes(ip);
  const isDockerNetwork = ip.startsWith('172.21.') || ip.startsWith('10.');
  
  // Check if secure
  const isSecure = isTrustedIp || isDockerNetwork;

  return NextResponse.json({ 
    ip,
    isSecure, // <-- New flag
    debug: {
      'x-forwarded-for': forwardedFor,
      'x-real-ip': realIp,
      'headers': Object.fromEntries(req.headers),
      'isSecure': isSecure
    }
  });
}

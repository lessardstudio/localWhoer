import { NextRequest, NextResponse } from 'next/server';

export const config = {
  matcher: ['/', '/api/:path*'],
};

export function middleware(req: NextRequest) {
  // Check for trusted IPs (VPN/Localhost)
  const forwardedFor = req.headers.get('x-forwarded-for');
  const realIp = req.headers.get('x-real-ip');
  
  // Get the first IP from the list
  let clientIp = forwardedFor?.split(',')[0].trim() || realIp || 'unknown';
  
  // Debug: Log IP to console (visible in docker logs)
  // console.log(`Incoming Request from: ${clientIp}`);

  // List of allowed IPs (VPN Exit IPs, Localhost, Docker Gateway)
  // Add your Server Public IP here if Hysteria routes via public interface!
  const allowedIps = [
    '127.0.0.1', 
    '::1', 
    '172.18.0.1',    // Docker Gateway (check debug info if changed)
    '208.92.227.197' // Server Public IP (if accessing via loopback)
  ];

  // Check if client IP starts with allowed prefixes (for subnets)
  const isAllowed = allowedIps.includes(clientIp) || 
                    clientIp.startsWith('172.') || 
                    clientIp.startsWith('10.');

  if (isAllowed) {
    return NextResponse.next();
  }

  // Block everyone else
  return new NextResponse(
    `Access Denied. You must be connected to the Corporate VPN.\nYour IP: ${clientIp}`, 
    { status: 403 }
  );
}

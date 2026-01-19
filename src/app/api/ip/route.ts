import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const forwardedFor = req.headers.get('x-forwarded-for');
  const realIp = req.headers.get('x-real-ip');
  
  let ip = forwardedFor ?? realIp ?? 'unknown';
  
  // Handle multiple IPs in x-forwarded-for
  if (ip && ip.includes(',')) {
    ip = ip.split(',')[0].trim();
  }
  
  // Fallback if headers are empty (e.g. local dev)
  if (!ip || ip === 'unknown') {
    ip = '127.0.0.1'; 
  }

  return NextResponse.json({ 
    ip,
    debug: {
      'x-forwarded-for': forwardedFor,
      'x-real-ip': realIp,
      'next-ip': req.ip,
      'geo': req.geo
    }
  });
}

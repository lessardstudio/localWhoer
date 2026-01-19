import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  let ip = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? 'unknown';
  
  // Handle multiple IPs in x-forwarded-for
  if (ip && ip.includes(',')) {
    ip = ip.split(',')[0].trim();
  }
  
  // Fallback if headers are empty (e.g. local dev)
  if (!ip || ip === 'unknown') {
    // In Next.js App Router, req.ip is sometimes available depending on hosting
    // But locally it might be null.
    ip = '127.0.0.1'; 
  }

  return NextResponse.json({ ip });
}

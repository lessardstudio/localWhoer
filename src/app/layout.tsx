import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Whier - IP Verifier",
  description: "Check your public IP and Hysteria2 connection status",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ru" className="dark">
      <body className={inter.className}>
        <main className="min-h-screen flex flex-col items-center justify-center p-4 md:p-24 bg-background text-foreground">
          {children}
        </main>
      </body>
    </html>
  );
}

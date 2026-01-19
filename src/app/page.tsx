"use client";

import { useEffect, useState } from "react";
import { Loader2, Shield, ShieldAlert, RefreshCw, Save } from "lucide-react";
import { cn } from "@/lib/utils";

export default function Home() {
  const [ip, setIp] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [expectedIp, setExpectedIp] = useState("");
  const [isClient, setIsClient] = useState(false);
  const [proxyPort, setProxyPort] = useState("");

  useEffect(() => {
    setIsClient(true);
    const savedIp = localStorage.getItem("whier_expected_ip");
    if (savedIp) setExpectedIp(savedIp);
    
    const savedPort = localStorage.getItem("whier_proxy_port");
    if (savedPort) setProxyPort(savedPort);

    fetchIp();
  }, []);

  const fetchIp = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/ip");
      const data = await res.json();
      setIp(data.ip);
    } catch (error) {
      console.error("Failed to fetch IP", error);
      setIp("Ошибка");
    } finally {
      setLoading(false);
    }
  };

  const handleSaveConfig = () => {
    localStorage.setItem("whier_expected_ip", expectedIp);
    localStorage.setItem("whier_proxy_port", proxyPort);
    // Trigger re-check logic visually if needed
    fetchIp();
  };

  const isSecured = ip && expectedIp && ip === expectedIp;
  const isConfigured = !!expectedIp;

  if (!isClient) return null;

  return (
    <div className="w-full max-w-md space-y-8">
      <div className="text-center space-y-2">
        <h1 className="text-4xl font-bold tracking-tighter bg-gradient-to-r from-white to-gray-500 bg-clip-text text-transparent">
          Whier
        </h1>
        <p className="text-muted-foreground">Проверка анонимности Hysteria2</p>
      </div>

      <div className="relative group">
        <div className={cn(
          "absolute -inset-0.5 bg-gradient-to-r rounded-xl blur opacity-75 transition duration-1000 group-hover:duration-200",
          isSecured ? "from-green-600 to-emerald-600" : "from-red-600 to-orange-600",
          !isConfigured && "from-gray-600 to-gray-400"
        )}></div>
        <div className="relative bg-black rounded-xl p-6 border border-white/10 shadow-2xl">
          
          {/* Status Indicator */}
          <div className="flex justify-center mb-6">
            {loading ? (
              <Loader2 className="h-16 w-16 text-blue-500 animate-spin" />
            ) : isSecured ? (
              <div className="flex flex-col items-center text-green-500">
                <Shield className="h-16 w-16 mb-2" />
                <span className="text-xl font-medium">Защищено (Hysteria2)</span>
              </div>
            ) : (
              <div className="flex flex-col items-center text-red-500">
                <ShieldAlert className="h-16 w-16 mb-2" />
                <span className="text-xl font-medium">
                  {isConfigured ? "Не защищено" : "Требуется настройка"}
                </span>
              </div>
            )}
          </div>

          {/* IP Display */}
          <div className="text-center mb-8">
            <div className="text-sm text-muted-foreground mb-1">Ваш публичный IP</div>
            <div className="text-3xl font-mono font-bold tracking-wider text-white">
              {ip || "..."}
            </div>
            <button 
              onClick={fetchIp}
              className="mt-4 text-xs flex items-center justify-center gap-1 mx-auto text-muted-foreground hover:text-white transition-colors"
            >
              <RefreshCw className="h-3 w-3" /> Обновить
            </button>
          </div>

          {/* Configuration */}
          <div className="space-y-4 pt-4 border-t border-white/10">
            <div className="space-y-2">
              <label className="text-xs font-medium text-muted-foreground">Ожидаемый IP (Hysteria2 VPN)</label>
              <input
                type="text"
                value={expectedIp}
                onChange={(e) => setExpectedIp(e.target.value)}
                placeholder="0.0.0.0"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-primary/50 font-mono"
              />
            </div>

            <div className="space-y-2">
              <label className="text-xs font-medium text-muted-foreground">Порт подключения (Опционально)</label>
              <input
                type="text"
                value={proxyPort}
                onChange={(e) => setProxyPort(e.target.value)}
                placeholder="e.g. 443"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-primary/50 font-mono"
              />
            </div>

            <button
              onClick={handleSaveConfig}
              className="w-full flex items-center justify-center gap-2 bg-white/10 hover:bg-white/20 text-white py-2 rounded-lg text-sm font-medium transition-colors"
            >
              <Save className="h-4 w-4" /> Сохранить настройки
            </button>
          </div>
        </div>
      </div>

      <div className="text-center text-xs text-muted-foreground">
        <p>Если доступ есть, то значит ты имеешь доступ к корпоративной сети.</p>
      </div>
    </div>
  );
}

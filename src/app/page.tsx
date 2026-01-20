"use client";

import { useEffect, useState } from "react";
import { Loader2, Shield, ShieldAlert, RefreshCw } from "lucide-react";
import { cn } from "@/lib/utils";

export default function Home() {
  const [ip, setIp] = useState<string | null>(null);
  const [isSecure, setIsSecure] = useState(false);
  const [debugInfo, setDebugInfo] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [showDebug, setShowDebug] = useState(false);

  useEffect(() => {
    fetchIp();
  }, []);

  const fetchIp = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/ip");
      const data = await res.json();
      setIp(data.ip);
      setIsSecure(data.isSecure);
      setDebugInfo(data.debug);
    } catch (error) {
      console.error("Failed to fetch IP", error);
      setIp("Ошибка");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-md space-y-8">
      <div className="text-center space-y-2">
        <h1 className="text-4xl font-bold tracking-tighter bg-gradient-to-r from-white to-gray-500 bg-clip-text text-transparent">
          Whier
        </h1>
        <p className="text-muted-foreground">Проверка доступности к корпоративной сети.</p>
      </div>

      <div className="relative group">
        <div className={cn(
          "absolute -inset-0.5 bg-gradient-to-r rounded-xl blur opacity-75 transition duration-1000 group-hover:duration-200",
          isSecure ? "from-green-600 to-emerald-600" : "from-red-600 to-orange-600"
        )}></div>
        <div className="relative bg-black rounded-xl p-6 border border-white/10 shadow-2xl">
          
          {/* Status Indicator */}
          <div className="flex justify-center mb-6">
            {loading ? (
              <Loader2 className="h-16 w-16 text-blue-500 animate-spin" />
            ) : isSecure ? (
              <div className="flex flex-col items-center text-green-500">
                <Shield className="h-16 w-16 mb-2" />
                <span className="text-xl font-medium">Защищено (VPN)</span>
              </div>
            ) : (
              <div className="flex flex-col items-center text-red-500">
                <ShieldAlert className="h-16 w-16 mb-2" />
                <span className="text-xl font-medium">Нет доступа к корпоративной сети</span>
              </div>
            )}
          </div>

          {/* IP Display */}
          <div className="text-center mb-8">
            <div className="text-sm text-muted-foreground mb-1">Ваш текущий IP</div>
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

          {/* Info */}
          <div className="text-center text-xs text-muted-foreground pt-4 border-t border-white/10">
            {isSecure ? (
               <p className="text-green-400">Вы успешно подключены к корпоративной сети.</p>
            ) : (
               <p className="text-red-400">Подключитесь к Hysteria2 VPN для доступа.</p>
            )}
          </div>
        </div>
      </div>

      <div className="text-center text-xs text-muted-foreground">
        <button 
          onClick={() => setShowDebug(!showDebug)}
          className="mt-4 underline opacity-50 hover:opacity-100"
        >
          {showDebug ? "Скрыть детали" : "Показать детали подключения"}
        </button>
        
        {showDebug && debugInfo && (
          <div className="mt-4 text-left bg-black/50 p-4 rounded-lg border border-white/10 font-mono text-[10px] overflow-x-auto">
            <pre>{JSON.stringify(debugInfo, null, 2)}</pre>
          </div>
        )}
      </div>
    </div>
  );
}

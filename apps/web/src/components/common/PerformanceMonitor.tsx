import React, { useEffect, useState } from 'react';
import { Activity, Zap, Clock } from 'lucide-react';

interface PerformanceMetrics {
  fps: number;
  memoryUsage: number; // MB
  renderTime: number; // reserved for future measurements
}

export default function PerformanceMonitor() {
  const [metrics, setMetrics] = useState<PerformanceMetrics>({ fps: 0, memoryUsage: 0, renderTime: 0 });
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    let frameCount = 0;
    let lastTime = performance.now();
    let animationFrameId: number | null = null;

    const measure = () => {
      frameCount++;
      const now = performance.now();
      if (now >= lastTime + 1000) {
        const fps = Math.round((frameCount * 1000) / (now - lastTime));
        const mem = (performance as any).memory?.usedJSHeapSize
          ? Math.round(((performance as any).memory.usedJSHeapSize as number) / 1048576)
          : 0;
        setMetrics((prev) => ({ ...prev, fps, memoryUsage: mem }));
        frameCount = 0;
        lastTime = now;
      }
      animationFrameId = requestAnimationFrame(measure);
    };

    if (isVisible) {
      animationFrameId = requestAnimationFrame(measure);
    }

    return () => {
      if (animationFrameId) cancelAnimationFrame(animationFrameId);
    };
  }, [isVisible]);

  // Keyboard shortcut to toggle (Ctrl/Cmd + Shift + P)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && (e.key === 'P' || e.key === 'p')) {
        e.preventDefault();
        setIsVisible((v) => !v);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  if (!isVisible) return null;

  return (
    <div className="fixed bottom-20 right-4 bg-black/90 text-white rounded-lg shadow-xl p-4 z-50 font-mono text-xs min-w-[220px]">
      <div className="flex items-center gap-2 mb-3 pb-2 border-b border-gray-700">
        <Activity className="w-4 h-4" />
        <span className="font-semibold">Performance Monitor</span>
        <button onClick={() => setIsVisible(false)} className="ml-auto text-gray-400 hover:text-white">
          ×
        </button>
      </div>

      <div className="space-y-2">
        <MetricRow icon={<Zap className="w-3 h-3" />} label="FPS" value={metrics.fps} unit="" color={metrics.fps >= 55 ? 'text-green-400' : metrics.fps >= 30 ? 'text-yellow-400' : 'text-red-400'} />
        <MetricRow icon={<Activity className="w-3 h-3" />} label="Memory" value={metrics.memoryUsage} unit="MB" color="text-blue-400" />
        <MetricRow icon={<Clock className="w-3 h-3" />} label="Render" value={metrics.renderTime} unit="ms" color="text-purple-400" />
      </div>

      <div className="mt-3 pt-2 border-t border-gray-700 text-gray-400 text-[10px]">Press Ctrl+Shift+P to toggle</div>
    </div>
  );
}

function MetricRow({ icon, label, value, unit, color }: { icon: React.ReactNode; label: string; value: number; unit: string; color: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <div className="flex items-center gap-2">
        {icon}
        <span className="text-gray-400">{label}:</span>
      </div>
      <span className={`font-semibold ${color}`}>
        {value} {unit}
      </span>
    </div>
  );
}

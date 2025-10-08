"use client";

import React, { useEffect } from 'react';
import toast, { Toaster } from 'react-hot-toast';
import { AlertTriangle, Info, X, Bell, CheckCircle } from 'lucide-react';
import { useFleetStore } from '@/stores/fleetStore';
import type { Alert } from '@/types/fleet';

interface AlertNotificationsProps {
  enableSound?: boolean;
  position?: 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left';
}

export default function AlertNotifications({ enableSound = true, position = 'top-right' }: AlertNotificationsProps) {
  const alerts = useFleetStore((s) => s.alerts);
  const acknowledgeAlert = useFleetStore((s) => s.acknowledgeAlert);
  const removeAlert = useFleetStore((s) => s.removeAlert);

  useEffect(() => {
    const unacked = alerts.filter((a) => !a.acknowledged);
    for (const alert of unacked) {
      const toastId = `alert-${alert.id}`;
      // Deduplicate by checking active toasts via an attribute we add on root
      // react-hot-toast doesn't expose a registry, so rely on id uniqueness
      toast.custom(
        (t) => (
          <AlertToast
            alert={alert}
            visible={t.visible}
            onDismiss={() => {
              toast.dismiss(t.id);
              acknowledgeAlert(alert.id);
            }}
            onRemove={() => {
              toast.dismiss(t.id);
              acknowledgeAlert(alert.id);
              setTimeout(() => removeAlert(alert.id), 300);
            }}
          />
        ),
        {
          id: toastId,
          duration: alert.severity === 'critical' ? Infinity : 10000,
          position,
        }
      );

      if (enableSound && alert.severity === 'critical') {
        try { playAlertSound(); } catch {}
      }
    }
  }, [alerts, acknowledgeAlert, removeAlert, enableSound, position]);

  return (
    <Toaster
      position={position}
      reverseOrder={false}
      gutter={8}
      toastOptions={{
        className: 'toast-notification',
        style: { background: 'transparent', boxShadow: 'none', padding: 0 },
      }}
    />
  );
}

interface AlertToastProps {
  alert: Alert;
  visible: boolean;
  onDismiss: () => void;
  onRemove: () => void;
}

function AlertToast({ alert, visible, onDismiss, onRemove }: AlertToastProps) {
  const severityConfig = {
    critical: { icon: AlertTriangle, bgColor: 'bg-red-50', borderColor: 'border-red-500', iconColor: 'text-red-600', titleColor: 'text-red-900' },
    warning: { icon: AlertTriangle, bgColor: 'bg-yellow-50', borderColor: 'border-yellow-500', iconColor: 'text-yellow-600', titleColor: 'text-yellow-900' },
    info: { icon: Info, bgColor: 'bg-blue-50', borderColor: 'border-blue-500', iconColor: 'text-blue-600', titleColor: 'text-blue-900' },
  } as const;
  const config = severityConfig[alert.severity];
  const Icon = config.icon;

  return (
    <div className={`${visible ? 'animate-enter' : 'animate-leave'} max-w-md w-full ${config.bgColor} border-l-4 ${config.borderColor} rounded-lg shadow-lg pointer-events-auto flex`}>
      <div className="flex-1 p-4">
        <div className="flex items-start">
          <div className={`flex-shrink-0 ${config.iconColor}`}>
            <Icon className="h-6 w-6" />
          </div>
          <div className="ml-3 flex-1">
            <p className={`text-sm font-medium ${config.titleColor}`}>{alert.title}</p>
            <p className="mt-1 text-sm text-gray-700">{alert.message}</p>
            <div className="mt-2 text-xs text-gray-500">{new Date(alert.timestamp).toLocaleTimeString()}</div>
            {alert.severity === 'critical' && (
              <div className="mt-3 flex gap-2">
                <button onClick={onRemove} className="text-sm font-medium text-red-700 hover:text-red-800">Acknowledge</button>
              </div>
            )}
          </div>
          <div className="ml-4 flex-shrink-0 flex">
            <button onClick={onDismiss} className="inline-flex text-gray-400 hover:text-gray-500 focus:outline-none">
              <X className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function NotificationBell() {
  const alerts = useFleetStore((s) => s.alerts);
  const acknowledgeAlert = useFleetStore((s) => s.acknowledgeAlert);
  const unacknowledged = alerts.filter((a) => !a.acknowledged).slice(0, 5);
  const [showDropdown, setShowDropdown] = React.useState(false);

  return (
    <div className="relative">
      <button onClick={() => setShowDropdown((s) => !s)} className="relative p-2 text-gray-600 hover:text-gray-900 focus:outline-none">
        <Bell className="w-6 h-6" />
        {unacknowledged.length > 0 && (
          <span className="absolute top-0 right-0 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-white transform translate-x-1/2 -translate-y-1/2 bg-red-600 rounded-full">
            {unacknowledged.length}
          </span>
        )}
      </button>

      {showDropdown && (
        <AlertDropdown alerts={alerts} onClose={() => setShowDropdown(false)} />
      )}
    </div>
  );
}

function AlertDropdown({ alerts, onClose }: { alerts: Alert[]; onClose: () => void }) {
  const acknowledgeAlert = useFleetStore((s) => s.acknowledgeAlert);
  const unacknowledged = alerts.filter((a) => !a.acknowledged).slice(0, 5);

  return (
    <>
      <div className="fixed inset-0 z-10" onClick={onClose} />
      <div className="absolute right-0 mt-2 w-80 bg-white rounded-lg shadow-xl z-20 border">
        <div className="p-4 border-b">
          <div className="flex items-center justify-between">
            <h3 className="font-semibold">Notifications</h3>
            <span className="text-sm text-gray-500">{unacknowledged.length} unread</span>
          </div>
        </div>
        <div className="max-h-96 overflow-y-auto">
          {unacknowledged.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <CheckCircle className="w-12 h-12 mx-auto mb-2 text-green-500" />
              <p>All caught up!</p>
            </div>
          ) : (
            unacknowledged.map((alert) => (
              <div key={alert.id} className="p-4 border-b hover:bg-gray-50 cursor-pointer" onClick={() => acknowledgeAlert(alert.id)}>
                <div className="flex items-start gap-3">
                  <div className={`mt-1 ${alert.severity === 'critical' ? 'text-red-600' : alert.severity === 'warning' ? 'text-yellow-600' : 'text-blue-600'}`}>
                    <AlertTriangle className="w-5 h-5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900">{alert.title}</p>
                    <p className="text-sm text-gray-600 mt-1">{alert.message}</p>
                    <p className="text-xs text-gray-400 mt-1">{new Date(alert.timestamp).toLocaleString()}</p>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
        {unacknowledged.length > 0 && (
          <div className="p-3 border-t text-center">
            <button onClick={() => { unacknowledged.forEach((a) => acknowledgeAlert(a.id)); onClose(); }} className="text-sm text-blue-600 hover:text-blue-700 font-medium">
              Mark all as read
            </button>
          </div>
        )}
      </div>
    </>
  );
}

function playAlertSound() {
  const AudioCtx: any = (typeof window !== 'undefined' && ((window as any).AudioContext || (window as any).webkitAudioContext));
  if (!AudioCtx) return;
  const audioContext = new AudioCtx();
  const osc1 = audioContext.createOscillator();
  const gain1 = audioContext.createGain();
  osc1.connect(gain1); gain1.connect(audioContext.destination);
  osc1.frequency.value = 800; osc1.type = 'sine'; gain1.gain.value = 0.3;
  osc1.start(audioContext.currentTime); osc1.stop(audioContext.currentTime + 0.1);
  setTimeout(() => {
    const osc2 = audioContext.createOscillator();
    const gain2 = audioContext.createGain();
    osc2.connect(gain2); gain2.connect(audioContext.destination);
    osc2.frequency.value = 1000; osc2.type = 'sine'; gain2.gain.value = 0.3;
    osc2.start(audioContext.currentTime); osc2.stop(audioContext.currentTime + 0.1);
  }, 150);
}

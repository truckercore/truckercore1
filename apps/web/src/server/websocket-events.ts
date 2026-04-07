import { getWebSocketServer } from './websocket-server';
import type { HOSEntry } from '@/types/hos.types';
import type { Load } from '@/types/load.types';

export class WebSocketEvents {
  static emitHOSStatusChange(driverId: string, entry: HOSEntry) {
    const io = getWebSocketServer();
    io.to(`user:${driverId}`).emit('hos:status_changed', entry);
    io.to('dispatchers').emit('driver:hos_changed', { driverId, entry });
  }

  static emitHOSViolation(driverId: string, violation: any) {
    const io = getWebSocketServer();
    io.to(`user:${driverId}`).emit('hos:violation', violation);
    io.to('dispatchers').emit('driver:violation_detected', { driverId, violation });
  }

  static emitLoadUpdate(load: Load) {
    const io = getWebSocketServer();
    if (load.driverId) io.to(`user:${load.driverId}`).emit('load:updated', load);
    io.to('dispatchers').emit('load:changed', load);
  }

  static emitLocationUpdate(driverId: string, location: any) {
    const io = getWebSocketServer();
    io.to('dispatchers').emit('driver:location_updated', { driverId, location });
  }

  static emitLoadOffer(driverId: string, load: Load) {
    const io = getWebSocketServer();
    io.to(`user:${driverId}`).emit('load:offer', load);
  }

  static broadcastSystemMessage(message: string, severity: 'info' | 'warning' | 'error' = 'info') {
    const io = getWebSocketServer();
    io.emit('system:message', { message, severity, timestamp: new Date() });
  }

  static sendNotification(
    userId: string,
    notification: {
      title: string;
      message: string;
      type: 'info' | 'success' | 'warning' | 'error';
      action?: { label: string; url: string };
    }
  ) {
    const io = getWebSocketServer();
    io.to(`user:${userId}`).emit('notification', { ...notification, timestamp: new Date() });
  }
}
